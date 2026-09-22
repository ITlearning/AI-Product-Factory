import AVFoundation
import Observation
import SwiftUI
import UIKit

/// 앱과 잠금화면 확장이 함께 쓰는 촬영 엔진.
///
/// 저장 위치를 주입받는 이유: **잠긴 확장은 앱 저장소에 못 쓴다.**
/// 애플 문서: "The capture extension can't read from or write to the App Group's shared container...
/// the system erases the capture extension's container directory when it suspends."
/// 확장은 `LockedCameraCaptureSession.sessionContentURL` 로, 앱은 Documents/Shots 로 쓴다.
@Observable
public final class CaptureEngine: NSObject {

    public struct Shot {
        public let image: UIImage
        public let color: ColorExtractor.RGB
        public let url: URL?
    }

    public var previewLayer: AVCaptureVideoPreviewLayer?
    public var permissionDenied = false
    public var isRunning = false
    /// 방금 찍은 것. 앱에서는 탭 보정 대상이 되고, 확장에서는 저장만 된다.
    public var lastShot: Shot?
    /// 셔터가 눌린 순간 잠깐 켜지는 플래시.
    public var shutterFlash = false
    /// 이번에 화면을 켠 동안 찍은 장수. **오늘 총량이 아니다** —
    /// 총량을 보여주면 "몇 장 채웠나"가 되고 그게 스트릭이다. 이건 방금 찍혔다는 확인일 뿐이다.
    public var shotsThisSession = 0
    /// 오른쪽 아래에 겹겹이 쌓이는 더미. 최근 것이 맨 위다.
    /// 수집이 눈에 보여야 수집이므로, 숫자가 아니라 실제 사진이 쌓인다.
    public var stack: [StackItem] = []

    public struct StackItem: Identifiable, Equatable {
        public let id = UUID()
        /// 더미에 쌓이는 작은 정사각형.
        public let thumbnail: UIImage
        /// 뷰어에서 쓰는 원본. 더미 깊이(5장)만 들고 있으므로 메모리는 제한적이다.
        public let full: UIImage?
        public static func == (a: StackItem, b: StackItem) -> Bool { a.id == b.id }
    }

    private static let stackDepth = 5
    /// 촬영 직후 잠깐 뜨는 확인 문구. 색은 포함하지 않는다(Approach C — 자정에 열린다).
    public var confirmation: String?

    /// 표시용 배율. 애플 기본 카메라와 같은 숫자가 나오도록
    /// `displayVideoZoomFactorMultiplier`(iOS 18+)를 곱한 값이다.
    public var displayZoom: Double = 1
    /// 기기가 지원하는 렌즈 프리셋. 트리플 카메라면 0.5·1·2·5 같은 값이 들어온다.
    public var zoomPresets: [Double] = []

    private var device: AVCaptureDevice? {
        didSet { observeZoom() }
    }
    private var zoomObservation: NSKeyValueObservation?

    /// **기기가 유일한 진실원이다.**
    /// 이전 판은 `displayZoom` 을 목표값으로 낙관적으로 먼저 써버렸다. 그래서 `ramp` 가
    /// 진행 중일 때 화면은 목표를 말하고 핀치는 실제값에서 앵커를 잡아 둘이 어긋났다
    /// (실측: 핀치로 1.5배를 만들었는데 다이얼은 3배에서 시작) — 상태를 하나로 합친다.
    private func observeZoom() {
        zoomObservation = device?.observe(\.videoZoomFactor, options: [.initial, .new]) { [weak self] dev, _ in
            guard let self else { return }
            let shown = Double(dev.videoZoomFactor * dev.displayVideoZoomFactorMultiplier)
            DispatchQueue.main.async { self.displayZoom = shown }
        }
    }
    private let destination: () -> URL
    /// 촬영이 끝나면 불린다. **앱만 넘긴다** — 잠긴 확장은 앱 저장소에 못 쓴다.
    private let onRecorded: ((Moment) -> Void)?
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "colormoments.capture")

    /// - Parameters:
    ///   - destination: 사진을 쓸 디렉토리. 호출 시점에 평가된다.
    ///   - onRecorded: 앱에서만 넘긴다. 확장에서는 nil — 기록은 앱이 들여올 때 만든다.
    public init(destination: @escaping () -> URL, onRecorded: ((Moment) -> Void)? = nil) {
        self.destination = destination
        self.onRecorded = onRecorded
        super.init()
    }

    public func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async { self.permissionDenied = true }
                return
            }
            self.queue.async { self.configureAndRun() }
        }
    }

    /// 더미에 쌓을 작은 정사각형. 원본을 들고 있으면 메모리가 샌다.
    private static func thumbnail(from image: UIImage, side: CGFloat = 120) -> UIImage? {
        let short = min(image.size.width, image.size.height)
        let crop = CGRect(x: (image.size.width - short) / 2,
                          y: (image.size.height - short) / 2,
                          width: short, height: short)
        guard let cg = image.cgImage?.cropping(to: crop) else { return nil }
        let square = UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            square.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
    }

    // MARK: 줌

    /// 핀치 제스처용. `scale` 은 제스처의 누적 배율.
    public func pinchZoom(scale: Double, began: Bool) {
        guard let d = device else { return }
        if began {
            if d.isRampingVideoZoom {
                try? d.lockForConfiguration(); d.cancelVideoZoomRamp(); d.unlockForConfiguration()
            }
            zoomAnchor = Double(d.videoZoomFactor)
        }
        setRawZoom(zoomAnchor * scale)
    }

    /// 다이얼이 드래그를 시작할 때 잡는 기준값. 화면 상태가 아니라 기기에서 읽는다.
    public var currentDisplayZoom: Double {
        guard let d = device else { return 1 }
        return Double(d.videoZoomFactor * d.displayVideoZoomFactorMultiplier)
    }

    /// 프리셋 탭. 표시 배율(0.5·1·2 …)을 받는다.
    /// 즉시 대입하면 렌즈가 툭 끊기며 바뀐다. `ramp` 로 넘기면 기본 카메라처럼 매끄럽게 전환된다.
    public func setDisplayZoom(_ display: Double, animated: Bool = true) {
        guard let d = device, d.displayVideoZoomFactorMultiplier > 0 else { return }
        let raw = display / Double(d.displayVideoZoomFactorMultiplier)
        guard animated else { setRawZoom(raw); return }
        let lo = Double(d.minAvailableVideoZoomFactor)
        let hi = min(Double(d.maxAvailableVideoZoomFactor), 12)
        let clamped = min(max(raw, lo), hi)
        do {
            try d.lockForConfiguration()
            d.ramp(toVideoZoomFactor: CGFloat(clamped), withRate: 8)
            d.unlockForConfiguration()
        } catch { return }
        // displayZoom 은 KVO 로 기기에서 흘러온다. 여기서 쓰지 않는다.
    }

    /// 다이얼을 끌 때. 램프를 취소하고 손가락을 바로 따라간다.
    public func scrubDisplayZoom(_ display: Double) {
        guard let d = device, d.displayVideoZoomFactorMultiplier > 0 else { return }
        if d.isRampingVideoZoom {
            try? d.lockForConfiguration(); d.cancelVideoZoomRamp(); d.unlockForConfiguration()
        }
        setRawZoom(display / Double(d.displayVideoZoomFactorMultiplier))
    }

    /// 다이얼이 쓸 표시 배율 범위.
    ///
    /// 상한을 기기 최대(30배 이상)로 두면 로그 축에서 0.5~5 구간이 왼쪽 끝에 몰려
    /// 프리셋 간격이 뭉개진다. **가장 큰 프리셋의 2배**까지만 다이얼에 올린다.
    public var displayZoomRange: ClosedRange<Double> {
        guard let d = device else { return 1...1 }
        let m = Double(d.displayVideoZoomFactorMultiplier)
        let lo = Double(d.minAvailableVideoZoomFactor) * m
        let hardMax = Double(d.maxAvailableVideoZoomFactor) * m
        let hi = min(hardMax, max((zoomPresets.max() ?? 5) * 2, lo * 4))
        return lo...hi
    }

    private var zoomAnchor: Double = 1

    private func setRawZoom(_ raw: Double) {
        guard let d = device else { return }
        let lo = Double(d.minAvailableVideoZoomFactor)
        let hi = min(Double(d.maxAvailableVideoZoomFactor), 12)
        let clamped = min(max(raw, lo), hi)
        do {
            try d.lockForConfiguration()
            d.videoZoomFactor = CGFloat(clamped)
            d.unlockForConfiguration()
        } catch { return }
        // displayZoom 은 KVO 로 기기에서 흘러온다. 여기서 쓰지 않는다.
    }

    private var confirmationToken = 0

    private func showConfirmation() {
        confirmationToken += 1
        let token = confirmationToken
        confirmation = "지금 이 순간이 담겼어요"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if self.confirmationToken == token { self.confirmation = nil }
        }
    }

    public func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    private func configureAndRun() {
        if session.inputs.isEmpty {
            session.beginConfiguration()
            session.sessionPreset = .photo
            // 가상 디바이스를 우선한다. 트리플/듀얼이면 한 세션에서 렌즈가 알아서 넘어가고
            // 0.5x 초광각까지 쓸 수 있다. 없으면 광각 단일 렌즈로 떨어진다.
            let picked = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            if let d = picked,
               let input = try? AVCaptureDeviceInput(device: d),
               session.canAddInput(input) {
                session.addInput(input)
                self.device = d
                let mult = d.displayVideoZoomFactorMultiplier
                // 기기가 알려주는 렌즈 전환점을 그대로 프리셋으로 쓴다.
                var presets: [Double] = [Double(d.minAvailableVideoZoomFactor * mult), 1.0]
                presets += d.virtualDeviceSwitchOverVideoZoomFactors.map { $0.doubleValue * Double(mult) }
                let cleaned: [Double] = Array(Set(presets.map { Double(($0 * 10).rounded() / 10) }))
                    .filter { $0 >= Double(d.minAvailableVideoZoomFactor * mult) - 0.01 }
                    .sorted()
                DispatchQueue.main.async { self.zoomPresets = cleaned }
            }
            if session.canAddOutput(output) { session.addOutput(output) }
            session.commitConfiguration()

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            DispatchQueue.main.async { self.previewLayer = layer }
        }
        session.startRunning()
        DispatchQueue.main.async { self.isRunning = true }
    }

    public func capture() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
        DispatchQueue.main.async {
            self.shutterFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { self.shutterFlash = false }
        }
    }
}

extension CaptureEngine: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput,
                            didFinishProcessingPhoto photo: AVCapturePhoto,
                            error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data),
              let ci = CIImage(data: data) else { return }
        let color = ColorExtractor.symbolicColor(for: ci)

        let dir = destination()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let capturedAt = Date()
        let name = "shot-\(Int(capturedAt.timeIntervalSince1970)).jpg"
        let url = dir.appendingPathComponent(name)
        try? data.write(to: url)

        if let onRecorded {
            let moment = Moment(capturedAt: capturedAt, colorHex: color.hex,
                                fileName: name, source: .app)
            DispatchQueue.main.async { onRecorded(moment) }
        }

        DispatchQueue.main.async {
            self.lastShot = Shot(image: image, color: color, url: url)
            self.shotsThisSession += 1
            if let thumb = Self.thumbnail(from: image) {
                self.stack.insert(StackItem(thumbnail: thumb, full: image), at: 0)
                if self.stack.count > Self.stackDepth { self.stack.removeLast() }
            }
            self.showConfirmation()
        }
    }
}
