import SwiftUI

/// 홈에 새로 생긴 줄(하루·진행 중 블록·한 줌 머리글)만 한 번 올라오며 나타나게 — 스크롤로 다시 보이는 줄은 그대로.
public struct Arrivals: Equatable {

    public enum Phase: Equatable {
        case settled
        /// 막 생겼는데 아직 순서를 못 받았거나 화면이 가려져 미뤄 둔 줄 — 숨겨 둔다(한 프레임 번쩍 방지).
        case pending
        case animate(delay: Double)
    }

    public static let stagger = 0.04
    public static let duration = 0.35
    public static let maxAnimated = 8
    public static let rise: CGFloat = 12
    /// 이 시간이 지나도 한 번도 안 그려진 줄(화면 밖)은 그냥 둔다 — 나중에 스크롤해 볼 때 올라오지 않게.
    public static let sweepAfter = 1.5

    private var seen: Set<String>?
    private var queued: [String] = []
    private var delays: [String: Double] = [:]

    public init() {}

    public func phase(_ id: String) -> Phase {
        guard let seen else { return .settled }
        if let d = delays[id] { return .animate(delay: d) }
        if !seen.contains(id) || queued.contains(id) { return .pending }
        return .settled
    }

    /// ids 는 화면 위→아래 순서. 첫 호출(로드 끝)은 기준만 잡는다. 이번에 순서를 받은 줄을 돌려준다.
    public mutating func update(ids: [String], loaded: Bool, held: Bool) -> [String] {
        guard loaded else { return [] }
        guard let old = seen else { seen = Set(ids); return [] }
        let now = Set(ids)
        let fresh = ids.filter { !old.contains($0) }
        seen = now
        queued = queued.filter(now.contains) + fresh
        delays = delays.filter { now.contains($0.key) }
        return held ? [] : release(order: ids)
    }

    /// 가렸던 화면(사진첩·카메라·시트)이 걷히면 미뤄 둔 줄을 위에서부터 차례로. maxAnimated 넘는 줄은 그냥 보인다.
    public mutating func release(order ids: [String]) -> [String] {
        guard !queued.isEmpty else { return [] }
        let waiting = Set(queued)
        queued = []
        let animated = Array(ids.filter(waiting.contains).prefix(Self.maxAnimated))
        for (i, id) in animated.enumerated() { delays[id] = Double(i) * Self.stagger }
        return animated
    }

    public mutating func finish(_ ids: [String]) {
        for id in ids { delays[id] = nil }
    }
}

public struct ArrivalEffect: ViewModifier {
    let phase: Arrivals.Phase
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    public init(phase: Arrivals.Phase, onFinished: @escaping () -> Void) {
        self.phase = phase
        self.onFinished = onFinished
    }

    public func body(content: Content) -> some View {
        let hidden: Bool = switch phase {
        case .settled: false
        case .pending: true
        case .animate: !shown
        }
        content
            .opacity(hidden ? 0 : 1)
            .offset(y: hidden && !reduceMotion ? Arrivals.rise : 0)
            .onAppear(perform: start)
            .onChange(of: phase) { _, _ in start() }
    }

    private func start() {
        guard case .animate(let delay) = phase, !shown else { return }
        withAnimation(.easeOut(duration: Arrivals.duration).delay(delay)) {
            shown = true
        } completion: {
            onFinished()
        }
    }
}

public extension View {
    func arrival(_ phase: Arrivals.Phase, onFinished: @escaping () -> Void) -> some View {
        modifier(ArrivalEffect(phase: phase, onFinished: onFinished))
    }
}
