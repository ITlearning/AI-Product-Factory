import Foundation

/// 조약돌을 밖으로 건네는 쪽 — 카드 진입 판정과 공유 문구만 순수 함수로 둔다(뷰·렌더링은 별도).
public enum Keepsake {

    /// 지금은 앱스토어에 없다 — 채워지면 공유 문구에 링크가 붙는다.
    public static let appStoreURL: URL? = nil

    /// 받지 않은 하루(색이 아직 없는 하루)는 카드를 만들 수 없다.
    public static func canMakeCard(dayKey: String, isGifted: (String) -> Bool) -> Bool {
        isGifted(dayKey)
    }

    /// URL 이 없으면 카드 이미지만 공유한다 — 문구 자체를 붙이지 않는다.
    public static func shareText(pebbleName: String, appStoreURL: URL?) -> String? {
        guard let appStoreURL else { return nil }
        return "\(pebbleName)을 건네요. 나도 몽돌 받아 보기 → \(appStoreURL.absoluteString)"
    }
}
