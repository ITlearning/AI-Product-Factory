import Foundation

/// 조약돌을 밖으로 건네는 쪽 — 카드 진입 판정과 공유 문구만 순수 함수로 둔다(뷰·렌더링은 별도).
public enum Keepsake {

    /// 지금은 앱스토어에 없다 — 채워지면 공유 문구에 링크가 붙는다.
    public static let appStoreURL: URL? = nil

    /// 받지 않은 하루(색이 아직 없는 하루)는 카드를 만들 수 없다.
    public static func canMakeCard(dayKey: String, isGifted: (String) -> Bool) -> Bool {
        isGifted(dayKey)
    }

    /// 공유 시트가 처음 보여줄 사진 — 하루 상세에서 보던 사진이 그날 사진이면 그것, 아니면 그날 첫 사진.
    public static func initialPhotoID(photos: [Moment], viewing: Moment.ID?) -> Moment.ID? {
        if let viewing, photos.contains(where: { $0.id == viewing }) { return viewing }
        return photos.first?.id
    }

    /// URL 이 없으면 카드 이미지만 공유한다 — 문구 자체를 붙이지 않는다.
    /// 카드를 굽는 동안 — 굽는 건 메인에서 돌아 화면이 잠깐 멈춘다. 멈춰도 읽히게 움직이지 않는 글로.
    public static let packingText = "건네기 좋게 포장하고 있어요…"

    public static func shareText(pebbleName: String, appStoreURL: URL?) -> String? {
        guard let appStoreURL else { return nil }
        return "\(pebbleName)\(objectParticle(after: pebbleName)) 건네요. 나도 몽돌 받아 보기 → \(appStoreURL.absoluteString)"
    }

    /// 마지막 글자 받침이 있으면 「을」, 없으면 「를」 — 한글이 아니면 「을」.
    public static func objectParticle(after word: String) -> String {
        guard let v = word.unicodeScalars.last?.value, (0xAC00...0xD7A3).contains(v) else { return "을" }
        return (v - 0xAC00) % 28 == 0 ? "를" : "을"
    }
}
