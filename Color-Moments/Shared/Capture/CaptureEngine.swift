import AVFoundation
import Observation
import SwiftUI
import UIKit

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

    public var lastShot: Shot?

    public var shutterFlash = false

    public var shotsThisSession = 0

    public var stack: [StackItem] = []

    public struct StackItem: Identifiable, Equatable {
        public let id = UUID()

        public let thumbnail: UIImage

        public let full: UIImage?
        public static func == (a: StackItem, b: StackItem) -> Bool { a.id == b.id }
    }

    private static let stackDepth = 5

    public var confirmation: String?

    public var displayZoom: Double = 1

    public var zoomPresets: [Double] = []

    private var device: AVCaptureDevice? {
        didSet { observeZoom() }
    }
    private var zoomObservation: NSKeyValueObservation?

    private func observeZoom() {
        zoomObservation = device?.observe(\.videoZoomFactor, options: [.initial, .new]) { [weak self] dev, _ in
            guard let self else { return }
            let shown = Double(dev.videoZoomFactor * dev.displayVideoZoomFactorMultiplier)
            DispatchQueue.main.async { self.displayZoom = shown }
        }
    }
    private let destination: () -> URL

    private let onRecorded: ((Moment) -> Void)?
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "colormoments.capture")

    public init(destination: @escaping () -> URL, onRecorded: ((Moment) -> Void)? = nil) {
        self.destination = destination
        self.onRecorded = onRecorded
        super.init()
    }

    private var wantsRunning = false
    private let wantsLock = NSLock()

    private func setWants(_ v: Bool) { wantsLock.lock(); wantsRunning = v; wantsLock.unlock() }
    private var wants: Bool { wantsLock.lock(); defer { wantsLock.unlock() }; return wantsRunning }

    public func start() {
        setWants(true)
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async { self.permissionDenied = true }
                return
            }
            self.queue.async {

                guard self.wants else { return }
                self.configureAndRun()
            }
        }
    }

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

    public var currentDisplayZoom: Double {
        guard let d = device else { return 1 }
        return Double(d.videoZoomFactor * d.displayVideoZoomFactorMultiplier)
    }

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

    }

    public func scrubDisplayZoom(_ display: Double) {
        guard let d = device, d.displayVideoZoomFactorMultiplier > 0 else { return }
        if d.isRampingVideoZoom {
            try? d.lockForConfiguration(); d.cancelVideoZoomRamp(); d.unlockForConfiguration()
        }
        setRawZoom(display / Double(d.displayVideoZoomFactorMultiplier))
    }

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

    }

    private var confirmationToken = 0

    private func showConfirmation() {
        confirmationToken += 1
        let token = confirmationToken
        confirmation = "담겼어요"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if self.confirmationToken == token { self.confirmation = nil }
        }
    }

    public func stop() {
        setWants(false)
        queue.async { [weak self] in
            guard let self else { return }

            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    private func configureAndRun() {
        if session.inputs.isEmpty {
            session.beginConfiguration()
            session.sessionPreset = .photo

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

        guard wants else { return }

        if let d = device {
            setRawZoom(1.0 / Double(d.displayVideoZoomFactorMultiplier))
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
