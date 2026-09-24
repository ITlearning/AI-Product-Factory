import SwiftUI
import UIKit

struct DayPhotoView: View {
    let momentID: Moment.ID
    let store: DayStore

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    private var moment: Moment? { store.moments.first { $0.id == momentID } }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Tone.pure.ignoresSafeArea()
            if let moment {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 60)
                        photo(moment)
                        Spacer().frame(height: 16)
                        words(moment).padding(.horizontal, 26)
                        Spacer().frame(height: 40)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .task(id: moment.fileName) { await load(moment) }
                .task(id: moment.id) { await assignWordIfNeeded(moment) }
            }
            closeButton.padding(.leading, 18).padding(.top, 8)
        }
        .statusBarHidden()
        .accessibilityAction(.escape) { dismiss() }
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

    private func photo(_ m: Moment) -> some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color(hex: m.colorHex).aspectRatio(3 / 4, contentMode: .fit)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Shape2.photoWindow, style: .continuous))
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private func words(_ m: Moment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let w = m.word {
                Text(w.word).font(Face.word).foregroundStyle(Tone.primary)
                Spacer().frame(height: 4)
                Text(w.meaning).font(Face.wordMeaning).foregroundStyle(Tone.tertiary)
                Spacer().frame(height: 12)
            }
            HStack(spacing: 6) {
                Circle().fill(Color(hex: m.colorHex)).frame(width: 9, height: 9)
                Text(DayGradient.timeText(m.capturedAt))
                    .font(Face.wordMeta).monospacedDigit()
                    .foregroundStyle(Tone.tertiary)
            }
        }
        .animation(.easeOut(duration: 0.25), value: m.word)
    }

    private func load(_ m: Moment) async {
        image = await Task.detached(priority: .userInitiated) { ShotImage.full(m) }.value
    }

    private func assignWordIfNeeded(_ m: Moment) async {
        guard m.word == nil else { return }
        var labels = m.labels
        if labels == nil {
            labels = await Task.detached(priority: .userInitiated) { PhotoLabeler.labels(for: m) }.value
            guard let labels else { return } // Vision failed — retry next open, don't stamp a bad guess
            store.setLabels(m.id, labels)
        }
        let seen = Set(labels ?? [])
        let words = await BundledWordSource().words()
        let ctx = PhotoContext(date: m.capturedAt, weather: Weather.inferred(from: seen))
        guard let pw = WordPicker.photoWord(for: ctx, labels: seen, in: words,
                                            excluding: store.recentWordIDs(excluding: m.id), seed: m.id.uuidString) else { return }
        store.assignWord(m.id, pw)
    }
}
