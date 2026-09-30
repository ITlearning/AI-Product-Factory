#if DEBUG
import SwiftUI
import WidgetKit

/// 디버그 전용 — 셰이더 조약돌(SoftPebbleView)을 지금 조약돌(PebbleView)과 실기기에서 비교한다.
struct PebbleLabView: View {
    let store: DayStore
    let gifts: GiftLog
    let closures: DayClosures

    @State private var showsOld = false
    @State private var count = 24
    @State private var page = 0
    @AppStorage(SoftPebbleView.widgetDebugKey, store: UserDefaults(suiteName: WidgetSnapshot.appGroup))
    private var widgetSoft = false
    @AppStorage(PebbleStyle.key, store: PebbleStyle.store) private var style: PebbleStyle = .round
    @AppStorage(FrameMeterBadge.homeKey) private var homeMeter = false

    private var days: [[Moment]] {
        let real = store.finishedDayKeys.sorted(by: >).map { store.pebbleMoments(on: $0) }.filter { !$0.isEmpty }
        return real.isEmpty ? Self.samples : real
    }

    var body: some View {
        let days = days
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                NavigationLink {
                    PebbleCollectionView(store: store, gifts: gifts, closures: closures)
                } label: {
                    Text("조약돌 모아 보기 (시안)").font(Face.guide).foregroundStyle(Tone.primary)
                        .frame(maxWidth: .infinity, minHeight: Shape2.minTouch)
                        .background(.white.opacity(0.08), in: Capsule())
                }

                Picker("앱 조약돌 모양", selection: $style) {
                    Text("둥근 돌").tag(PebbleStyle.round)
                    Text("반듯한 돌").tag(PebbleStyle.classic)
                }
                .pickerStyle(.segmented)

                heading("크게 — \(page + 1)/\(days.count)")
                TabView(selection: $page) {
                    ForEach(days.indices, id: \.self) { i in
                        VStack(spacing: 18) {
                            SoftPebbleView(moments: days[i], height: 180, glow: .hero)
                                .frame(height: 300)
                            LegacyPebbleView(moments: days[i], height: 110)
                                .opacity(0.9)
                            Text(days[i].first?.dayKey ?? "").font(.caption2.monospaced())
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 500)

                HStack {
                    heading(showsOld ? "격자 — 지금 조약돌" : "격자 — 새 조약돌")
                    Spacer()
                    Toggle("지금 것", isOn: $showsOld).labelsHidden()
                }
                Stepper("개수 \(count)", value: $count, in: 6...150, step: 12)
                    .foregroundStyle(.white.opacity(0.7))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 18) {
                    ForEach(0..<count, id: \.self) { i in
                        let d = days[i % days.count]
                        Group {
                            if showsOld {
                                LegacyPebbleView(moments: d, height: 70)
                            } else {
                                SoftPebbleView(moments: d, height: 62, glow: .grid)
                            }
                        }
                        .frame(height: 96)
                    }
                }

                Toggle("홈에 프레임 측정 표시", isOn: $homeMeter)
                    .foregroundStyle(.white.opacity(0.7))
                Toggle("위젯에 새 조약돌 시험", isOn: $widgetSoft)
                    .foregroundStyle(.white.opacity(0.7))
                    .onChange(of: widgetSoft) { _, _ in WidgetCenter.shared.reloadAllTimelines() }

                heading("아이콘 색 그대로")
                SoftPebbleView(stops: Self.iconStops, height: 180, glow: .hero,
                               shape: SoftPebbleShape(tilt: 32 * .pi / 180, egg: 0.22, wa: 0.3, wb: 0.6, wc: 0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
            }
            .padding(20)
        }
        .background(Tone.base.ignoresSafeArea())
        .safeAreaInset(edge: .top) { FrameMeterBadge() }
        .navigationTitle("조약돌 비교")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func heading(_ s: String) -> some View {
        Text(s).font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
    }

    static let iconStops: [Float] = SoftPebbleView.floats([
        (0.00, "#8e9ab0"), (0.22, "#8fa9c2"), (0.40, "#a9c6d8"), (0.48, "#bcd0dc"),
        (0.55, "#f2e6d2"), (0.60, "#f0d6bb"), (0.66, "#efc0a2"), (0.80, "#eea08c"), (1.00, "#b86a6c"),
    ].map { DayGradient.Stop(location: $0.0, hex: $0.1) })

    static let samples: [[Moment]] = [
        ["#6A7EA0", "#9FBDDB", "#F4E6CF", "#F6C7A2", "#EC9383", "#B86676"],
        ["#2B3550", "#33509B", "#6A4A7A", "#A6404A", "#B12E12"],
        ["#7FB0DC", "#8CB8DE", "#6795BC", "#3C6A9B"],
        ["#5B7F5B", "#8FA36B", "#A79C87"],
        ["#6B6261", "#887F7E", "#9D917C"],
    ].enumerated().map { d, hexes in
        let base = Date().addingTimeInterval(Double(-86_400 * (d + 1)))
        return hexes.enumerated().map {
            Moment(capturedAt: base.addingTimeInterval(Double($0.offset) * 1800),
                   colorHex: $0.element, fileName: "lab\(d)-\($0.offset).jpg", source: .app)
        }
    }
}

/// 프레임 측정 한 줄 — 탭하면 끊김·최악 값을 초기화.
struct FrameMeterBadge: View {
    static let homeKey = "debugHomeFrameMeter"

    @StateObject private var meter = FrameMeter()

    var body: some View {
        Text("\(meter.fps) fps · 끊김 \(meter.hitches) · 최악 \(meter.worstMs, specifier: "%.1f")ms")
            .font(.caption.monospacedDigit())
            .foregroundStyle(meter.hitches == 0 ? .green : .orange)
            .padding(.vertical, 4).frame(maxWidth: .infinity)
            .background(.black.opacity(0.6))
            .onTapGesture { meter.reset() }
            .onAppear { meter.start() }
            .onDisappear { meter.stop() }
    }
}

/// 메인 스레드 프레임 간격 — 기대 간격의 1.5배를 넘기면 끊김으로 센다. 탭하면 초기화.
/// 렌더 서버(GPU) 쪽 끊김은 여기 안 잡힐 수 있다 — 정확한 판정은 Instruments(Hitches·Metal System Trace).
final class FrameMeter: NSObject, ObservableObject {
    @Published private(set) var fps = 0
    @Published private(set) var hitches = 0
    @Published private(set) var worstMs = 0.0

    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var windowStart: CFTimeInterval = 0
    private var frames = 0

    func start() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stop() {
        link?.invalidate()
        link = nil
        last = 0
    }

    func reset() {
        hitches = 0
        worstMs = 0
    }

    @objc private func tick(_ l: CADisplayLink) {
        defer { last = l.timestamp }
        guard last > 0 else { windowStart = l.timestamp; return }
        let gap = l.timestamp - last
        let expected = max(l.targetTimestamp - l.timestamp, 1.0 / 120)
        if gap > expected * 1.5 { hitches += 1 }
        // @Published 는 같은 값을 넣어도 발행한다 — 매 프레임 대입하면 배지가 매 프레임 다시 그려진다.
        if gap * 1000 > worstMs { worstMs = gap * 1000 }
        frames += 1
        if l.timestamp - windowStart >= 1 {
            if fps != frames { fps = frames }
            frames = 0
            windowStart = l.timestamp
        }
    }
}
#endif
