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

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PreviewLayerView(engine: engine)
                .ignoresSafeArea()

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
                Color.white.ignoresSafeArea().transition(.opacity)
            }

            VStack {
                if let onClose {
                    HStack {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(.black.opacity(0.35), in: Circle())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
                Spacer()

                if engine.zoomPresets.count > 1 {
                    ZoomPills(presets: engine.zoomPresets, zoom: engine.displayZoom) {
                        engine.setDisplayZoom($0); Haptics.snapped()
                    }
                    .padding(.bottom, 12)
                }

                Text(engine.confirmation ?? " ")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(.black.opacity(engine.confirmation == nil ? 0 : 0.45), in: Capsule())
                    .opacity(engine.confirmation == nil ? 0 : 1)
                    .padding(.bottom, 14)

                ZStack {
                    Button { Haptics.captured(); engine.capture() } label: {
                        Circle()
                            .strokeBorder(.white.opacity(0.9), lineWidth: 3)
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
                        .padding(.trailing, 22)
                    }
                }
                .padding(.bottom, 14)

                if showsDismissHint {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.up").font(.system(size: 9, weight: .semibold))
                        Text("위로 쓸어올리면 닫혀요")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.black.opacity(0.4), in: Capsule())
                    .padding(.bottom, 16)
                }
            }

            if engine.permissionDenied {
                VStack(spacing: 8) {
                    Text("카메라 권한이 필요해요").font(.headline)
                    Text("설정에서 카메라를 켜주세요").font(.caption).opacity(0.7)
                }
                .foregroundStyle(.white)
                .padding(20)
                .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
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

    private let amber = Color(red: 1, green: 0.84, blue: 0.25)

    var body: some View {
        HStack(spacing: 10) {
            ForEach(presets, id: \.self) { preset in
                let active = isActive(preset)
                Button { onSelect(preset) } label: {
                    Text(active ? zoomText(zoom) : presetText(preset))
                        .font(.system(size: active ? 13 : 12,
                                      weight: active ? .semibold : .medium,
                                      design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(active ? amber : .white)
                        .frame(minWidth: active ? 44 : 30, minHeight: 30)
                        .background(Circle().fill(.black.opacity(active ? 0.55 : 0.32))
                                        .scaleEffect(active ? 1.12 : 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.black.opacity(0.28), in: Capsule())
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
