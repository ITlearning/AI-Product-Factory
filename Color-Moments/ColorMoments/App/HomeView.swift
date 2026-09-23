import SwiftUI

struct HomeView: View {
    let store: DayStore

    let showsSwipeHint: Bool

    @State private var opened: OpenedDay?
    @State private var topDayKey: String?
    @State private var scrolling = false

    private struct OpenedDay: Identifiable { let id: String }

    private var days: [String] { store.finishedDayKeys }

    var body: some View {
        ZStack {
            Tone.base.ignoresSafeArea()
            backdrop
            content
            bottomFade
            if scrolling, let label = monthLabel { monthPill(label) }
            if showsSwipeHint { swipeHint }
        }
        .sheet(item: $opened) { day in
            DayMomentsView(dayKey: day.id, store: store)
        }
    }

    @ViewBuilder
    private var backdrop: some View {
        if let key = topDayKey ?? days.first {
            DayGradientView(moments: store.moments(on: key), axis: .vertical)
                .blur(radius: 60)
                .opacity(0.16)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.45), value: key)
                .allowsHitTesting(false)
        }
    }

    private var content: some View {
        GeometryReader { geo in
            let blockWidth = geo.size.width - 56
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("몽돌").font(Face.wordmark).foregroundStyle(Tone.primary)
                    Spacer().frame(height: 22)
                    todayLine
                    Spacer().frame(height: 38)

                    if days.isEmpty {
                        EmptyDayBlock(width: blockWidth)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 64) {
                            ForEach(days, id: \.self) { key in

                                DayBlock(moments: store.moments(on: key), width: blockWidth)
                                    .contentShape(Rectangle())
                                    .onTapGesture { opened = OpenedDay(id: key) }

                                .scrollTransition { c, phase in
                                    c.opacity(phase.isIdentity ? 1 : 0.5)
                                     .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                }
                                .onScrollVisibilityChange(threshold: 0.6) { visible in
                                    if visible { topDayKey = key }
                                }
                            }
                        }
                    }
                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, 28)
                .padding(.top, 72 - geo.safeAreaInsets.top)
            }
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in
                withAnimation(.easeOut(duration: 0.2)) { scrolling = phase.isScrolling }
            }
        }
    }

    private var todayLine: some View {
        let n = store.today.count
        return Group {
            if n == 0 {
                Text("오늘은 아직 비어 있어요").foregroundStyle(Tone.primary)
                    + Text("  ·  왼쪽에서 쓸어 담아요").foregroundStyle(Tone.tertiary)
            } else {
                Text("오늘 \(n)개 담겼어요").foregroundStyle(Tone.primary)
                    + Text("  ·  색은 자정에 열려요").foregroundStyle(Tone.tertiary)
            }
        }
        .font(Face.today)
    }

    private var monthLabel: String? {
        guard let key = topDayKey, key.count >= 7 else { return nil }
        let parts = key.split(separator: "-")
        guard parts.count >= 2 else { return nil }
        return "\(parts[0])년 \(Int(parts[1]) ?? 0)월"
    }

    private func monthPill(_ label: String) -> some View {
        VStack {
            HStack {
                Spacer()
                Text(label)
                    .font(Face.caption).monospacedDigit()
                    .foregroundStyle(Tone.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.white.opacity(0.10), in: Capsule())
                    .padding(.trailing, 14)
            }
            Spacer()
        }
        .padding(.top, 120)
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    private var swipeHint: some View {

        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Tone.tertiary)
                .frame(width: 3, height: 34)
            Text("쓸면 담기")
                .font(.system(size: 11))
                .foregroundStyle(Tone.tertiary)
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .frame(width: 12, height: 62)
            Spacer()
        }
        .padding(.leading, 5)
        .allowsHitTesting(false)
    }

    private var bottomFade: some View {
        VStack {
            Spacer()
            LinearGradient(colors: [.clear, Tone.base], startPoint: .top, endPoint: .bottom)
                .frame(height: 110)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct EmptyDayBlock: View {
    let width: CGFloat
    private var k: CGFloat { width / 334 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Shape2.cardFront * k, style: .continuous)
                    .strokeBorder(Tone.hairline, style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                    .frame(width: 314 * k, height: 320 * k)
                    .offset(x: 10 * k)
                PebbleShape(top: 0.44, bottom: 0.40)
                    .strokeBorder(Tone.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .frame(width: 84 * k * Shape2.pebbleRatio, height: 84 * k)
                    .offset(x: 272 * k, y: 300 * k)
            }
            .frame(width: width, height: 388 * k, alignment: .topLeading)
            Spacer().frame(height: 26 * k)
            Text("오늘 담은 것은 자정에 조약돌이 돼요")
                .font(Face.guide).foregroundStyle(Tone.tertiary)
        }
    }
}
