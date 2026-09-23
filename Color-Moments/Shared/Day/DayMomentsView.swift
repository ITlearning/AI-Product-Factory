import SwiftUI
import UIKit

public struct DayMomentsView: View {
    private let dayKey: String
    private let store: DayStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Moment?

    public init(dayKey: String, store: DayStore) {
        self.dayKey = dayKey
        self.store = store
    }

    private var moments: [Moment] { store.moments(on: dayKey) }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    DayBadgeView(moments: moments, size: 120, showsCaption: false)
                        .padding(.top, 12)

                    if let named = PebbleNaming.name(for: moments) {
                        Text(named.name)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                        ForEach(moments) { m in
                            Button { editing = m } label: { thumbnail(m) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)

                    Text("사진을 눌러 그 순간의 색을 고를 수 있어요.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle(dateText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
            .sheet(item: $editing) { m in
                ShotColorPicker(
                    moment: m,
                    onPick: { store.updateColor(m.id, to: $0) },
                    onRevert: { store.revertColor(m.id) }
                )
            }
        }
    }

    private func thumbnail(_ m: Moment) -> some View {

        return ZStack(alignment: .bottomTrailing) {
            ShotThumbnail(moment: m, maxPixel: 400)

            Circle()
                .fill(Color(hex: m.colorHex))
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .padding(6)
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var dateText: String {
        guard let first = moments.first else { return dayKey }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: first.capturedAt)
    }
}
