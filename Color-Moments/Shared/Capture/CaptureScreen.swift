import AVKit
import SwiftUI
import UIKit

/// 앱과 잠금화면 확장이 함께 쓰는 촬영 화면.
///
/// **`AVCaptureEventInteraction` 이 반드시 붙어야 한다.** 애플 문서:
/// "The app extension terminates shortly after launch if it doesn't have an active camera view
/// that uses [it] to handle events from the hardware buttons."
/// `UIImagePickerController` 는 이걸 내장하고 있어서 그냥 됐지만, 커스텀 UI는 직접 붙여야 한다.
///
/// 의도적으로 비어 있다. 줌 배율·모드 전환·필터가 없다 —
/// 「알아차리기」 엔진은 누르는 순간에 아무 선택도 시키지 않는다.
public struct CaptureScreen: View {

    private let engine: CaptureEngine
    private let onClose: (() -> Void)?
    /// 잠금화면 확장에서만 필요한 안내. 앱 안에서는 닫는 법이 자명하다.
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
                .gesture(
                    MagnifyGesture()
                        .onChanged {
                            engine.pinchZoom(scale: $0.magnification, began: pinching == false)
                            pinching = true
                        }
                        .onEnded { _ in pinching = false }
                )

            // 「담김」 피드백. 색은 보여주지 않는다 (Approach C — 자정에 열린다).
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

                // 찍혔다는 확인. 색은 보여주지 않는다 — 그건 자정에 열린다.
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

                // 끝내는 법. 안 알려주면 "계속 찍어야 하나?"가 된다.
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

/// 프리뷰 레이어 + 하드웨어 셔터 수신.
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
        // 카메라 컨트롤·볼륨 버튼의 하드웨어 셔터. 확장 생존 조건이기도 하다.
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


/// 찍은 사진이 오른쪽 아래에 겹겹이 쌓이는 더미.
///
/// 숫자 대신 실물이 쌓인다. 「수집하는 앱」이라면 수집이 눈에 보여야 한다.
/// 새 장은 셔터 쪽에서 날아와 얹히고, 아래 것들은 좌우로 조금씩 어긋나 카드 더미처럼 보인다.
struct ShotStackView: View {
    let items: [CaptureEngine.StackItem]
    let total: Int

    private let side: CGFloat = 46

    var body: some View {
        ZStack {
            // 뒤에서부터 그려야 최근 것이 맨 위로 온다.
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
                    // 깊이감: 뒤로 갈수록 작아지고, 좌우로 번갈아 어긋난다.
                    .scaleEffect(1 - CGFloat(index) * 0.06)
                    .rotationEffect(.degrees(offsetAngle(index)))
                    .offset(x: CGFloat(index) * (index % 2 == 0 ? -3.5 : 3.5),
                            y: CGFloat(index) * -3)
                    .opacity(index >= 4 ? 0 : 1)
                    .zIndex(Double(items.count - index))
                    .transition(
                        .asymmetric(
                            // 셔터 쪽(왼쪽 아래)에서 날아와 얹히는 느낌
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
                    // 사진마다 zIndex 를 줬으므로 배지도 명시해야 맨 위로 온다.
                    // 안 그러면 0 으로 깔려서 더미 뒤에 숨는다 (실측으로 잡힌 버그).
                    .zIndex(1000)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: side, height: side)
        .padding(.top, 6).padding(.trailing, 6)   // 배지가 잘리지 않을 만큼
        .animation(.spring(response: 0.42, dampingFraction: 0.66), value: items)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: total)
    }

    /// 번갈아 기울여 손으로 쌓은 더미처럼 보이게. 인덱스로만 정해져 매번 같다.
    private func offsetAngle(_ index: Int) -> Double {
        let angles: [Double] = [0, -5, 4.5, -3, 6]
        return angles[min(index, angles.count - 1)]
    }
}

/// 배율 프리셋 알약.
///
/// 다이얼(눈금 호)은 2026-09-22 에 걷어냈다 — 카메라는 이 제품의 본질이 아닌데
/// 기본 카메라를 흉내내는 데 시간이 쏠렸다. 필요해지면 그때 다시 짓는다.
/// 핀치줌은 그대로 동작하고, 현재 배율은 활성 알약에 표시된다.
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
