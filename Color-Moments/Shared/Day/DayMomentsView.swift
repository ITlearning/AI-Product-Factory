import SwiftUI
import UIKit

public struct DayMomentsView: View {
    private let dayKey: String
    private let store: DayStore
    private let closures: DayClosures
    // 「마무리하기」로 실제로 닫혔을 때만 호출부(HomeShell)가 아침 도착 소식 예약을 다시 맞춘다.
    private let onClosed: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var viewing: Moment?
    @State private var confirmingFinish = false
    @Namespace private var zoom

    private static let photo = CGSize(width: 190, height: 127)
    private static let labelWidth: CGFloat = 36
    private static let bandX: CGFloat = 44
    private static let photoX: CGFloat = 66
    private static let shiftStep: CGFloat = 28
    private static let maxShift = 3
    private static let tick: CGFloat = 13

    public init(dayKey: String, store: DayStore, closures: DayClosures, onClosed: @escaping () -> Void = {}) {
        self.dayKey = dayKey
        self.store = store
        self.closures = closures
        self.onClosed = onClosed
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
                        closeButton
                        Spacer().frame(height: 24)
                        header
                        Spacer().frame(height: 30)
                        timeline(width: max(0, geo.size.width - 56))
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
        .fullScreenCover(item: $viewing) { m in
            DayPhotoView(momentID: m.id, store: store)
                .navigationTransition(.zoom(sourceID: m.id, in: zoom))
        }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Text("닫기")
                .font(.system(size: 13))
                .foregroundStyle(Tone.primary)
                .padding(.horizontal, 16)
                .frame(minHeight: Shape2.minTouch)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
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
            Text("오늘 마무리하기")
                .font(Face.guide)
                .foregroundStyle(Tone.secondary)
                .frame(maxWidth: .infinity, minHeight: Shape2.minTouch)
        }
        .buttonStyle(.plain)
        .confirmationDialog("지금 조약돌을 열까요?", isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button("마무리하기") {
                // 확인창이 떠 있는 사이 04시가 넘어 이미 저절로 닫혔을 수 있다 — 그땐 그냥 시트를 닫는다.
                guard store.canClose(dayKey) else { dismiss(); return }
                closures.close(dayKey)
                onClosed()
                dismiss()
            }
            Button("취소", role: .cancel) {}
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
                        .font(.system(size: 10, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Tone.tertiary)
                        .frame(width: Self.labelWidth, alignment: .trailing)
                        .frame(height: Self.tick)
                        .offset(x: -6, y: p.y - Self.tick / 2)
                }

                Circle()
                    .fill(Color(hex: p.moment.colorHex))
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
            ShotThumbnail(moment: m, maxPixel: 600)
                .frame(width: Self.photo.width, height: Self.photo.height)
                .clipped()
            Circle()
                .fill(Color(hex: m.colorHex))
                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                .frame(width: 13, height: 13)
                .padding(8)
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
