import SwiftUI
import UIKit

/// 이미 열린 하루의 순간들. **색을 고치러 찾아오는 자리다.**
///
/// 앨범이 아니다 — 지난 날들을 넘겨보는 화면이 되면 「자정에 열린다」가 흐려진다.
/// 그래서 (1) 한 하루만 보여주고 (2) 옆 날로 넘어가는 길을 두지 않고
/// (3) 재촉하지 않는다. 안 고쳐도 되는 것이 기본값이다.
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
        // 격자에는 축소본. 원본(12MP)을 칸마다 디코드하면 사진 몇 장만으로 메모리가 터진다.
        return ZStack(alignment: .bottomTrailing) {
            if let img = ShotImage.thumbnail(m.fileName) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color(hex: m.colorHex)
            }
            // 이 순간이 지금 무슨 색인지. **«직접 고름» 표시는 하지 않는다** —
            // 미보정을 드러내면 그 순간 체크리스트가 된다(설계 제약).
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
