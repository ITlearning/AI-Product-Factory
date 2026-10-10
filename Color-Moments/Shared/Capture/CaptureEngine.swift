import AVFoundation
import Observation
import os
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

    public var zoomLadder: ZoomLadder?

    // capture 큐에서 대입되고 메인(제스처)에서 읽힌다 — 관찰 대상에서 빼고 잠금으로 지킨다.
    @ObservationIgnored private let deviceLock = NSLock()
    @ObservationIgnored private var storedDevice: AVCaptureDevice?
    @ObservationIgnored private var zoomObservation: NSKeyValueObservation?

    private var device: AVCaptureDevice? {
        get { deviceLock.lock(); defer { deviceLock.unlock() }; return storedDevice }
        set {
            deviceLock.lock(); storedDevice = newValue; deviceLock.unlock()
            observeZoom()
        }
    }

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
        observeSession()
    }

    deinit { sessionObservers.forEach { NotificationCenter.default.removeObserver($0) } }

    // Diagnostics for the intermittent black viewfinder (2026-09-29): Console > subsystem com.itlearning.colormoments.
    static let log = Logger(subsystem: "com.itlearning.colormoments", category: "camera")
    @ObservationIgnored private var sessionObservers: [NSObjectProtocol] = []

    private func observeSession() {
        let nc = NotificationCenter.default
        let log = Self.log
        sessionObservers = [
            nc.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { n in
                let reason = (n.userInfo?[AVCaptureSessionInterruptionReasonKey] as? NSNumber)?.intValue ?? -1
                log.error("session interrupted reason=\(reason, privacy: .public)")
            },
            nc.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { _ in
                log.notice("session interruption ended")
            },
            nc.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { n in
                let error = n.userInfo?[AVCaptureSessionErrorKey] as? NSError
                log.error("session runtime error code=\(error?.code ?? 0, privacy: .public) \(error?.localizedDescription ?? "", privacy: .public)")
            },
            nc.addObserver(forName: AVCaptureSession.didStartRunningNotification, object: session, queue: nil) { _ in
                log.notice("session did start running")
            },
            nc.addObserver(forName: AVCaptureSession.didStopRunningNotification, object: session, queue: nil) { _ in
                log.notice("session did stop running")
            },
        ]
    }

    private var wantsRunning = false
    private let wantsLock = NSLock()

    private func setWants(_ v: Bool) { wantsLock.lock(); wantsRunning = v; wantsLock.unlock() }
    private var wants: Bool { wantsLock.lock(); defer { wantsLock.unlock() }; return wantsRunning }

    public func start() {
        setWants(true)
        Self.log.notice("start requested")
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            guard granted else {
                Self.log.error("camera access denied")
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
        guard let d = device, let ladder = zoomLadder else { return }
        if began { zoomAnchor = ladder.display(forRaw: Double(d.videoZoomFactor)) }
        setRawZoom(ladder.raw(forDisplay: zoomAnchor * scale))
    }

    public func setDisplayZoom(_ display: Double) {
        guard let d = device, let ladder = zoomLadder else { return }
        let from = ladder.display(forRaw: Double(d.videoZoomFactor))
        do {
            try d.lockForConfiguration()
            d.ramp(toVideoZoomFactor: Self.available(ladder.raw(forDisplay: display), on: d),
                   withRate: ZoomLadder.rampRate(from: from, to: ladder.clamped(display)))
            d.unlockForConfiguration()
        } catch { return }
    }

    private var zoomAnchor: Double = 1

    private func setRawZoom(_ raw: Double) {
        guard let d = device else { return }
        do {
            try d.lockForConfiguration()
            d.videoZoomFactor = Self.available(raw, on: d)
            d.unlockForConfiguration()
        } catch { return }

    }

    private static func available(_ raw: Double, on d: AVCaptureDevice) -> CGFloat {
        CGFloat(min(max(raw, Double(d.minAvailableVideoZoomFactor)), Double(d.maxAvailableVideoZoomFactor)))
    }

    private var confirmationToken = 0

    public func confirm(_ text: String = "담겼어요") {
        confirmationToken += 1
        let token = confirmationToken
        confirmation = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if self.confirmationToken == token { self.confirmation = nil }
        }
    }

    public func stop() {
        setWants(false)
        Self.log.notice("stop requested")
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
            }
            if session.canAddOutput(output) { session.addOutput(output) }
            session.commitConfiguration()
            if let d = device {
                let switchOvers = d.virtualDeviceSwitchOverVideoZoomFactors.map(\.doubleValue)
                let ladder = ZoomLadder(multiplier: Double(d.displayVideoZoomFactorMultiplier), switchOvers: switchOvers,
                                        minRaw: Double(d.minAvailableVideoZoomFactor),
                                        maxRaw: Double(d.maxAvailableVideoZoomFactor))
                Self.log.notice("zoom multiplier=\(d.displayVideoZoomFactorMultiplier, privacy: .public) switchOvers=\(switchOvers, privacy: .public) maxRaw=\(d.maxAvailableVideoZoomFactor, privacy: .public) native=\(d.activeFormat.secondaryNativeResolutionZoomFactors, privacy: .public) presets=\(ladder.presets, privacy: .public) range=\(ladder.range.upperBound, privacy: .public)")
                DispatchQueue.main.async { self.zoomLadder = ladder }
            }
            Self.log.notice("configured device=\(picked?.deviceType.rawValue ?? "none", privacy: .public) inputs=\(self.session.inputs.count, privacy: .public)")

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            DispatchQueue.main.async { self.previewLayer = layer }
        }

        guard wants else { return }

        if let d = device {
            setRawZoom(1.0 / Double(d.displayVideoZoomFactorMultiplier))
        }

        session.startRunning()
        Self.log.notice("startRunning returned isRunning=\(self.session.isRunning, privacy: .public) interrupted=\(self.session.isInterrupted, privacy: .public)")
        DispatchQueue.main.async { self.isRunning = true }
    }

    public func capture() {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { Self.log.error("shutter dropped: session not running"); return }
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
        let palette = onRecorded == nil ? nil : ColorExtractor.palette(for: ci).map(\.encoded)

        let dir = destination()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let capturedAt = Date()
        let name = "shot-\(Int(capturedAt.timeIntervalSince1970)).jpg"
        let url = dir.appendingPathComponent(name)
        try? data.write(to: url)

        if let onRecorded {
            let moment = Moment(capturedAt: capturedAt, colorHex: color.hex,
                                fileName: name, source: .app, palette: palette)
            DispatchQueue.main.async { onRecorded(moment) }
        }

        DispatchQueue.main.async {
            self.lastShot = Shot(image: image, color: color, url: url)
            self.shotsThisSession += 1
            if let thumb = Self.thumbnail(from: image) {
                self.stack.insert(StackItem(thumbnail: thumb, full: image), at: 0)
                if self.stack.count > Self.stackDepth { self.stack.removeLast() }
            }
            self.confirm()
        }
    }
}
