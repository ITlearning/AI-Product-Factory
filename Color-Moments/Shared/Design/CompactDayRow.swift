import SwiftUI

/// 30일 지난 하루를 한 줄로 — 조약돌 + 이름/날짜·개수. 사진 더미는 그리지 않는다.
public struct CompactDayRow: View {
    private let pebbleMoments: [Moment]
    private let moments: [Moment]

    public static let height: CGFloat = 52

    public init(pebbleMoments: [Moment], moments: [Moment]) {
        self.pebbleMoments = pebbleMoments
        self.moments = moments
    }

    public var body: some View {
        HStack(spacing: 14) {
            PebbleView(moments: pebbleMoments, height: Self.height)
            VStack(alignment: .leading, spacing: 3) {
                if let named = PebbleNaming.name(for: pebbleMoments) {
                    Text(named.name).font(Face.nameCompact).foregroundStyle(Tone.primary)
                }
                Text(subtitle).font(Face.caption).foregroundStyle(Tone.tertiary).monospacedDigit()
            }
            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        let date = moments.first.map { f.string(from: $0.capturedAt) } ?? ""
        return "\(date) · \(moments.count)개"
    }
}
