import SwiftUI

public struct BadgeCeremony: View {
    private let moments: [Moment]
    @Binding private var isPresented: Bool

    @State private var risen = false

    @State private var lit = false

    @State private var sheen: Double = 0

    @State private var settled = false
    @State private var drift = false

    private enum Beat {
        static let rise = 0.15
        static let riseFade = 0.80
        static let land = 0.95
        static let sheenSpan = 0.95
        static let text = 1.30
    }

    public init(moments: [Moment], isPresented: Binding<Bool>) {
        self.moments = moments
        self._isPresented = isPresented
    }

    public var body: some View {
        ZStack {
            Tone.pure.ignoresSafeArea()

            GeometryReader { geo in
                let side = max(geo.size.width, geo.size.height) * 1.15
                DayGradientView(moments: moments, axis: .vertical)
                    .frame(width: side, height: side)
                    .blur(radius: 110)

                    .scaleEffect(drift ? 1.10 : 0.92)
                    .rotationEffect(.degrees(drift ? 7 : -7))
                    .offset(x: drift ? 22 : -22, y: drift ? -26 : 26)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .ignoresSafeArea()
            .opacity(lit ? 0.42 : 0)
            .allowsHitTesting(false)

            VStack(spacing: 22) {
                Text(Self.openingLine(for: moments, now: Date()))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Tone.secondary)
                    .opacity(lit ? 1 : 0)
                    .offset(y: risen ? 0 : 8)

                ZStack {

                    DayBadgeView(moments: moments, size: 150, showsCaption: false, sheen: sheen)
                        .scaleEffect(risen ? 1 : 0.5)
                        .offset(y: risen ? 0 : 40)
                        .opacity(lit ? 1 : 0)
                }
                .frame(height: 230)

                VStack(spacing: 8) {
                    if let named = PebbleNaming.name(for: moments) {
                        VStack(spacing: 5) {
                            Text(named.name)
                                .font(Face.nameCeremony)
                                .foregroundStyle(Tone.primary)

                            Text(named.line)
                                .font(Face.lineCeremony)
                                .foregroundStyle(Tone.secondary)
                        }
                    }
                    Text(dateText)
                        .font(Face.caption)
                        .foregroundStyle(Tone.tertiary)
                    if let span = DayGradient.span(for: moments) {
                        Text("\(DayGradient.timeText(span.from)) – \(DayGradient.timeText(span.to)) · \(moments.count)개")
                            .font(Face.caption)
                            .monospacedDigit()
                            .foregroundStyle(Tone.tertiary)
                    }
                }
                .opacity(settled ? 1 : 0)
                .offset(y: settled ? 0 : 10)
            }

            VStack {
                Spacer()
                Button { isPresented = false } label: {
                    Text("닫기")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Tone.secondary)
                        .padding(.horizontal, 22).padding(.vertical, 10)
                }
                .opacity(settled ? 1 : 0)
                .padding(.bottom, 28)
            }
        }
        .statusBarHidden()
        .onAppear(perform: run)
    }

    private func run() {
        Haptics.prepare()

        withAnimation(.spring(response: 0.80, dampingFraction: 0.90).delay(Beat.rise)) { risen = true }
        withAnimation(.easeOut(duration: Beat.riseFade).delay(Beat.rise)) { lit = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + Beat.land) { Haptics.snapped() }

        withAnimation(.easeInOut(duration: Beat.sheenSpan).delay(Beat.land)) { sheen = 1 }

        withAnimation(.easeOut(duration: 0.55).delay(Beat.text)) { settled = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + Beat.land + Beat.sheenSpan) {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    static func openingLine(for moments: [Moment], now: Date) -> String {
        guard let key = moments.first?.dayKey else { return "하루가 담겼어요" }
        let today = Moment.dayKey(for: now)
        if key == today { return "오늘이 담겼어요" }

        let yesterday = Moment.dayKey(for: now.addingTimeInterval(-86_400))
        if key == yesterday { return "어제가 담겼어요" }
        return "그날이 담겼어요"
    }

    private var dateText: String {
        guard let first = moments.min(by: { $0.capturedAt < $1.capturedAt }) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: first.capturedAt)
    }
}
