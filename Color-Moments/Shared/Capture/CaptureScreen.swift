import AVKit
import SwiftUI
import UIKit

public struct CaptureScreen: View {

    private let engine: CaptureEngine
    private let onClose: (() -> Void)?

    private let showsDismissHint: Bool
    @State private var pinching = false
    @State private var viewingShots = false

    public init(engine: CaptureEngine, onClose: (() -> Void)? = nil, showsDismissHint: Bool = false) {
        self.engine = engine
        self.onClose = onClose
        self.showsDismissHint = showsDismissHint
    }

    private static let windowRatio: CGFloat = 560 / 370
    private static let windowTop: CGFloat = 76
    private static let sideInset: CGFloat = 10
    private static let controlsHeight: CGFloat = 44 + 18 + 74 + 20

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width - Self.sideInset * 2
            let hintRoom: CGFloat = showsDismissHint ? 44 : 0
            let room = geo.size.height - (Self.windowTop - geo.safeAreaInsets.top)
                - Self.controlsHeight - hintRoom - 12
            let h = max(0, min(w * Self.windowRatio, room))

            ZStack(alignment: .top) {
                Tone.pure.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: max(0, Self.windowTop - geo.safeAreaInsets.top))
                    window.frame(width: w, height: h)
                    Spacer().frame(height: 18)
                    controls
                    Spacer(minLength: 0)
                    if showsDismissHint { dismissHint }
                }
                .frame(maxWidth: .infinity)

                if onClose != nil { returnHint }
            }
        }
        .animation(.easeOut(duration: 0.12), value: engine.shutterFlash)
        .animation(.easeOut(duration: 0.2), value: engine.confirmation)
        .animation(.easeOut(duration: 0.2), value: engine.shotsThisSession)
        .onAppear { engine.start() }
        .onDisappear { engine.stop() }
        .fullScreenCover(isPresented: $viewingShots) {
            ShotViewer(items: engine.stack, isPresented: $viewingShots)
        }
    }

    private var window: some View {
        let shape = RoundedRectangle(cornerRadius: Shape2.cameraWindow, style: .continuous)
        return ZStack(alignment: .top) {
            Color.white.opacity(0.05)
            PreviewLayerView(engine: engine)
                .opacity(engine.isRunning ? 1 : 0)
                .animation(.easeIn(duration: 0.35), value: engine.isRunning)
                .gesture(
                    MagnifyGesture()
                        .onChanged {
                            engine.pinchZoom(scale: $0.magnification, began: pinching == false)
                            pinching = true
                        }
                        .onEnded { _ in pinching = false }
                )

            if engine.shutterFlash {
                Color.white.transition(.opacity)
            }

            Text(engine.confirmation ?? " ")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Tone.primary)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(.black.opacity(0.45), in: Capsule())
                .opacity(engine.confirmation == nil ? 0 : 1)
                .padding(.top, 28)
                .allowsHitTesting(false)

            if let onClose {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tone.primary)
                            .frame(width: 34, height: 34)
                            .background(.black.opacity(0.35), in: Circle())
                            .frame(width: Shape2.minTouch, height: Shape2.minTouch)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(8)
            }

            if engine.permissionDenied {
                VStack(spacing: 8) {
                    Text("카메라 권한이 필요해요").font(.headline)
                    Text("설정에서 카메라를 켜주세요").font(Face.guide).foregroundStyle(Tone.secondary)
                }
                .foregroundStyle(Tone.primary)
                .frame(maxHeight: .infinity)
            }
        }
        .clipShape(shape)
    }

    private var controls: some View {
        VStack(spacing: 18) {
            ZoomPills(presets: engine.zoomPresets, zoom: engine.displayZoom) {
                engine.setDisplayZoom($0); Haptics.snapped()
            }
            .frame(height: 44)
            .opacity(engine.zoomPresets.count > 1 ? 1 : 0)
            .disabled(engine.zoomPresets.count <= 1)

            ZStack {
                Button { Haptics.captured(); engine.capture() } label: {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 74, height: 74)
                        .overlay(Circle().fill(.white).frame(width: 60, height: 60))
                }
                .buttonStyle(.plain)
                HStack {
                    Spacer()
                    Button { if !engine.stack.isEmpty { viewingShots = true } } label: {
                        ShotStackView(items: engine.stack, total: engine.shotsThisSession)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 32)
                }
            }
        }
    }

    private var dismissHint: some View {
        HStack(spacing: 5) {
            Image(systemName: "chevron.up").font(.system(size: 9, weight: .semibold))
            Text("위로 쓸어올리면 닫혀요")
        }
        .font(Face.guide)
        .foregroundStyle(Tone.secondary)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.white.opacity(0.10), in: Capsule())
        .padding(.bottom, 12)
    }

    private var returnHint: some View {
        HStack(spacing: 7) {
            Spacer()
            Text("쓸면 돌아가기")
                .font(.system(size: 11))
                .foregroundStyle(Tone.tertiary)
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: 12, height: 74)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Tone.tertiary)
                .frame(width: 3, height: 34)
        }
        .padding(.trailing, 1)
        .frame(maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

struct PreviewLayerView: UIViewControllerRepresentable {
    let engine: CaptureEngine

    func makeUIViewController(context: Context) -> PreviewController { PreviewController(engine: engine) }
    func updateUIViewController(_ c: PreviewController, context: Context) { c.attachIfNeeded() }
}

final class PreviewController: UIViewController {
    private let engine: CaptureEngine
    private var attached = false

    init(engine: CaptureEngine) {
        self.engine = engine
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let interaction = AVCaptureEventInteraction { [weak self] event in
            guard event.phase == .ended else { return }
            self?.engine.capture()
        }
        view.addInteraction(interaction)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        engine.previewLayer?.frame = view.bounds
    }

    func attachIfNeeded() {
        guard !attached, let layer = engine.previewLayer else { return }
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        attached = true
    }
}

struct ShotStackView: View {
    let items: [CaptureEngine.StackItem]
    let total: Int

    private let side: CGFloat = 46

    var body: some View {
        ZStack {

            ForEach(Array(items.enumerated().reversed()), id: \.element.id) { index, item in
                Image(uiImage: item.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(.white.opacity(0.75), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)

                    .scaleEffect(1 - CGFloat(index) * 0.06)
                    .rotationEffect(.degrees(offsetAngle(index)))
                    .offset(x: CGFloat(index) * (index % 2 == 0 ? -3.5 : 3.5),
                            y: CGFloat(index) * -3)
                    .opacity(index >= 4 ? 0 : 1)
                    .zIndex(Double(items.count - index))
                    .transition(
                        .asymmetric(

                            insertion: .scale(scale: 2.1)
                                .combined(with: .offset(x: -70, y: 26))
                                .combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }

            if total > 1 {
                Text("\(total)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(.white, in: Capsule())
                    .offset(x: side / 2 - 2, y: -side / 2 + 2)

                    .zIndex(1000)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: side, height: side)
        .padding(.top, 6).padding(.trailing, 6)
        .animation(.spring(response: 0.42, dampingFraction: 0.66), value: items)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: total)
    }

    private func offsetAngle(_ index: Int) -> Double {
        let angles: [Double] = [0, -5, 4.5, -3, 6]
        return angles[min(index, angles.count - 1)]
    }
}

struct ZoomPills: View {
    let presets: [Double]
    let zoom: Double
    let onSelect: (Double) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(presets, id: \.self) { preset in
                let active = isActive(preset)
                Button { onSelect(preset) } label: {
                    Text(active ? zoomText(zoom) : presetText(preset))
                        .font(.system(size: 13, weight: active ? .semibold : .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(active ? Tone.amber : Tone.secondary)
                        .frame(width: 50, height: 44)
                        .background(Tone.amber.opacity(active ? 0.16 : 0), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: zoom)
    }

    private func isActive(_ preset: Double) -> Bool {
        guard let nearest = presets.min(by: { abs($0 - zoom) < abs($1 - zoom) }) else { return false }
        return nearest == preset
    }

    private func zoomText(_ z: Double) -> String {
        let shown = (z * 10).rounded() / 10
        return shown < 10 ? String(format: "%.1f×", shown) : String(format: "%.0f×", shown)
    }

    private func presetText(_ z: Double) -> String {
        z < 1 ? String(format: "%.1f", z).replacingOccurrences(of: "0.", with: ".") : String(format: "%.0f", z)
    }
}
