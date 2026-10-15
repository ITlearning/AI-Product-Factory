import SwiftUI

/// 장면 → 셰이더 하늘. 하늘이 생긴 장면은 이 파일 한 곳에서만 잇는다.
public extension SkyScene {
    /// nil 이면 아직 하늘이 없다 — 부르는 쪽은 SceneView 로 그린다.
    static func of(_ kind: SceneKind) -> SkyScene? {
        switch kind {
        case .sun: .clearDay
        case .stars: .clearNight
        case .moon: .nightCloudy
        case .rain, .drizzle: .rain
        case .dawn, .dusk, .snow, .fog, .wind, .petals, .leaves, .frost: nil
        }
    }

    /// 하늘 판 번호 — 셰이더 그림이 바뀌면 올린다(위젯 정지 그림을 다시 굽는다).
    static let edition = 4

    /// 파일 이름·캐시 열쇠.
    var key: String { String(describing: self) }

    /// 밤 하늘엔 그날 달이 뜬다 — 정지 그림은 날마다 다시 굽는다.
    var showsMoon: Bool { isNight }
}

public extension SceneKind {
    /// 하늘 위 작은 글자(라벨·뜻·날짜) — 맑은 낮 하늘만 primary(SkyFrame.smallTextAlpha), 나머지는 secondary.
    var smallTextTone: Color { SkyScene.of(self) == .clearDay ? Tone.primary : Tone.secondary }
}
