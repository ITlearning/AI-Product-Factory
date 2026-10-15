import SwiftUI

/// 장면 → 셰이더 하늘. 하늘이 생긴 장면은 이 파일 한 곳에서만 잇는다.
public extension SkyScene {
    /// 13장면 모두 하늘이 있다 — nil 은 이제 나오지 않지만 부르는 쪽의 SceneView 대체 길은 남겨 둔다.
    static func of(_ kind: SceneKind) -> SkyScene? { SkyScene(kind) }

    /// 하늘 판 번호 — 셰이더 그림이 바뀌면 올린다(위젯 정지 그림을 다시 굽는다).
    static let edition = 5

    /// 파일 이름·캐시 열쇠.
    var key: String { String(describing: self) }

    /// 밤 하늘엔 그날 달이 뜬다 — 정지 그림은 날마다 다시 굽는다.
    var showsMoon: Bool { isNight }
}

public extension SceneKind {
    /// 하늘 위 작은 글자(라벨·뜻·날짜) — 밝은 하늘은 primary(SkyFrame.smallTextAlpha), 밤·비는 secondary.
    var smallTextTone: Color { SkyScene(self).brightSky ? Tone.primary : Tone.secondary }
}
