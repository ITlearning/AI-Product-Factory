import SwiftUI
import UIKit

public struct DayMomentsView: View {
    private let dayKey: String
    private let store: DayStore
    private let closures: DayClosures
    // 「지금 조약돌로 받기」로 실제로 닫혔을 때만 호출부(HomeShell)가 아침 도착 소식 예약을 다시 맞춘다.
    private let onClosed: () -> Void
    // 받은 하루인지 — App 타깃의 gifts.isGifted 를 그대로 받는다(Shared 는 GiftLog 를 몰라도 된다).
    private let isGifted: (String) -> Bool
    // 카드 공유 시트 — ImageRenderer/ShareLink 는 앱 타깃 전용이라 내용은 호출부(App)가 만들어 넘긴다.
    // 두 번째 인자는 보던 사진 — 카드가 그 사진으로 먼저 열린다.
    private let makeShareSheet: ((String, Moment.ID?) -> AnyView)?
    @Environment(\.dismiss) private var dismiss
    @State private var viewing: Moment?
    @State private var confirmingFinish = false
    @State private var sharing = false
    @State private var lastViewed: Moment.ID?
    // 사진 보기에서 한 장을 빼고 옆 사진으로 넘어갔다 — 보기는 열린 채 이 사진을 보인다.
    @State private var showing: Moment.ID?
    // 혼자 남은 사진을 뺐다 — 보기가 그 사진 칸으로 줄어 돌아간 뒤에 뺀다.
    @State private var takingOut: Moment.ID?
    @Namespace private var zoom

    private static let photo = CGSize(width: 190, height: 127)
    private static let labelWidth: CGFloat = 36
    private static let bandX: CGFloat = 44
    private static let photoX: CGFloat = 66
    private static let shiftStep: CGFloat = 28
    private static let maxShift = 3
    private static let tick: CGFloat = 13

    public init(dayKey: String, store: DayStore, closures: DayClosures,
                isGifted: @escaping (String) -> Bool = { _ in false },
                onClosed: @escaping () -> Void = {},
                makeShareSheet: ((String, Moment.ID?) -> AnyView)? = nil) {
        self.dayKey = dayKey
        self.store = store
        self.closures = closures
        self.isGifted = isGifted
        self.onClosed = onClosed
        self.makeShareSheet = makeShareSheet
    }

    private var moments: [Moment] { store.moments(on: dayKey) }
    private var pebbleMoments: [Moment] { store.pebbleMoments(on: dayKey) }

    // 안 닫힌 오늘은 색이 아직 없다 — 조약돌·이름·색 번짐을 그리지 않는다.
    private var isOpenToday: Bool { dayKey == Moment.dayKey(for: Date()) && !store.isFinished(dayKey) }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Tone.base.ignoresSafeArea()
            if !isOpenToday {
                DayGradientView(moments: pebbleMoments, axis: .vertical)
                    .blur(radius: 60)
                    .opacity(0.26)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        topBar
                        if !moments.isEmpty {
                            Spacer().frame(height: 24)
                            header
                            Spacer().frame(height: 30)
                            timeline(width: max(0, geo.size.width - 56))
                        }
                        if store.canClose(dayKey) {
                            Spacer().frame(height: 40)
                            finishButton
                        }
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                }
                .scrollIndicators(.hidden)
            }
        }
        .presentationDragIndicator(.hidden)
        .onChange(of: viewing?.id) { _, id in if let id { lastViewed = id } }
        .fullScreenCover(item: $viewing, onDismiss: photoClosed) { m in
            let id = showing ?? m.id
            DayPhotoView(momentID: id, store: store, onTakeOut: { takeOut(id) })
                .id(id)
                .navigationTransition(.zoom(sourceID: id, in: zoom))
        }
        // 마지막 사진이 빠지면(여기서 뺐든 사진 앱·다른 기기에서 지웠든) 빈 하루를 붙들지 않는다.
        .onChange(of: moments.isEmpty) { _, empty in if empty { dismiss() } }
    }

    private func takeOut(_ id: Moment.ID) {
        guard let next = Self.shownAfterTakingOut(id, from: moments) else {
            takingOut = id
            viewing = nil
            return
        }
        remove(id)
        withAnimation(.easeOut(duration: 0.3)) { showing = next }
        lastViewed = next
    }

    private func photoClosed() {
        showing = nil
        guard let id = takingOut else { return }
        takingOut = nil
        if lastViewed == id { lastViewed = nil }
        withAnimation(.easeOut(duration: 0.35)) { remove(id) }
    }

    private func remove(_ id: Moment.ID) {
        if let m = store.moment(id) { RemovedPhotos.note(m) }
        store.takeOut(id)
    }

    /// 뺀 다음 보일 사진 — 뒤 사진, 맨 끝이면 앞 사진. 혼자였으면 nil(보기를 닫는다).
    static func shownAfterTakingOut(_ id: Moment.ID, from moments: [Moment]) -> Moment.ID? {
        guard let i = moments.firstIndex(where: { $0.id == id }) else { return nil }
        if moments.indices.contains(i + 1) { return moments[i + 1].id }
        return i > 0 ? moments[i - 1].id : nil
    }

    private var topBar: some View {
        HStack {
            closeButton
            Spacer()
            shareButton
        }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Text("닫기")
                .font(Face.actionSecondary)
                .foregroundStyle(Tone.primary)
                .padding(.horizontal, 16)
                .frame(minHeight: Shape2.minTouch)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // 받은 하루에만 — 아직 안 받은(색 없는) 하루는 건넬 카드가 없다.
    @ViewBuilder
    private var shareButton: some View {
        if let makeShareSheet, Keepsake.canMakeCard(dayKey: dayKey, isGifted: isGifted) {
            Button { sharing = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Tone.secondary)
                    .frame(width: Shape2.minTouch, height: Shape2.minTouch)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $sharing) { makeShareSheet(dayKey, lastViewed) }
        }
    }

    @ViewBuilder
    private var header: some View {
        if isOpenToday {
            Text(caption).font(Face.caption).foregroundStyle(Tone.tertiary).monospacedDigit()
        } else {
            HStack(alignment: .center, spacing: 20) {
                PebbleView(moments: pebbleMoments, height: 130)
                VStack(alignment: .leading, spacing: 8) {
                    if let named = PebbleNaming.name(for: pebbleMoments) {
                        Text(named.name).font(Face.nameDay).foregroundStyle(Tone.primary)
                        Text(named.line).font(Face.line).foregroundStyle(Tone.secondary)
                    }
                    Text(caption).font(Face.caption).foregroundStyle(Tone.tertiary).monospacedDigit()
                }
            }
        }
    }

    private var finishButton: some View {
        Button {
            confirmingFinish = true
        } label: {
            Text("지금 조약돌로 받기")
                .font(Face.guide)
                .foregroundStyle(Tone.secondary)
                .frame(maxWidth: .infinity, minHeight: Shape2.minTouch)
        }
        .buttonStyle(.plain)
        .confirmationDialog("오늘을 지금 조약돌로 받을까요?", isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button("받기") {
                // 확인창이 떠 있는 사이 04시가 넘어 이미 저절로 닫혔을 수 있다 — 그땐 그냥 시트를 닫는다.
                guard store.canClose(dayKey) else { dismiss(); return }
                closures.close(dayKey)
                onClosed()
                dismiss()
            }
            Button("기다릴게요", role: .cancel) {}
        } message: {
            Text("이후에 찍은 사진도 오늘에 담기지만 색은 그대로예요.")
        }
    }

    private func timeline(width: CGFloat) -> some View {
        let room = width - Self.photoX - Self.photo.width
        let step = max(0, min(Self.shiftStep, room / CGFloat(Self.maxShift)))
        let axisHeight = DayTimeline.axisHeight(count: moments.count, photoHeight: Self.photo.height)
        let placements = DayTimeline.place(moments, height: axisHeight,
                                           photoHeight: Self.photo.height, maxShift: Self.maxShift)
        let bandCenter = Self.bandX + 1.5

        return ZStack(alignment: .topLeading) {
            if axisHeight > 0 && !isOpenToday {
                DayGradientView(moments: moments, axis: .vertical)
                    .frame(width: 3, height: axisHeight)
                    .clipShape(Capsule())
                    .offset(x: Self.bandX)
            }

            ForEach(Array(placements.enumerated()), id: \.element.moment.id) { i, p in
                if p.showsTime {
                    Text(DayGradient.timeText(p.moment.capturedAt))
                        .font(Face.time).monospacedDigit()
                        .foregroundStyle(Tone.tertiary)
                        .frame(width: Self.labelWidth, alignment: .trailing)
                        .frame(height: Self.tick)
                        .offset(x: -6, y: p.y - Self.tick / 2)
                }

                // 진행 중인 오늘은 눈금만 — 점을 사진 색으로 칠하면 닫히기 전에 그날 색이 다 보인다.
                Circle()
                    .fill(isOpenToday ? Tone.veil : Color(hex: p.moment.colorHex))
                    .overlay(Circle().strokeBorder(Tone.base.opacity(0.6), lineWidth: 2))
                    .frame(width: Self.tick, height: Self.tick)
                    .offset(x: bandCenter - Self.tick / 2, y: p.y - Self.tick / 2)
                    .zIndex(Double(placements.count + i))

                Button { viewing = p.moment } label: {
                    photoCard(p.moment).matchedTransitionSource(id: p.moment.id, in: zoom)
                }
                    .buttonStyle(.plain)
                    .offset(x: Self.photoX + CGFloat(p.shift) * step, y: p.y - Self.tick / 2)
                    .zIndex(Double(i))
            }
        }
        .frame(width: width, height: axisHeight + Self.photo.height, alignment: .topLeading)
    }

    private func photoCard(_ m: Moment) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ShotThumbnail(moment: m, maxPixel: 600, hidesColor: isOpenToday)
                .frame(width: Self.photo.width, height: Self.photo.height)
                .clipped()
            if !isOpenToday {
                Circle()
                    .fill(Color(hex: m.colorHex))
                    .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                    .frame(width: 13, height: 13)
                    .padding(8)
            }
        }
        .frame(width: Self.photo.width, height: Self.photo.height)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
    }

    private var caption: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        guard let span = DayGradient.span(for: moments) else { return dayKey }
        let from = DayGradient.timeText(span.from), to = DayGradient.timeText(span.to)
        let time = from == to ? from : "\(from)–\(to)"
        return "\(f.string(from: span.from)) · \(time) · \(moments.count)개"
    }
}
