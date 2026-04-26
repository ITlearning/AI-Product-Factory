import Foundation
import SwiftData

@Model
final class ConceptProgress {
    @Attribute(.unique) var conceptID: String
    var conceptTitle: String
    var category: String
    var studiedCount: Int
    var masteredCount: Int
    var lastStudiedAt: Date?
    var isMastered: Bool

    /// 학습 트랙 (Cycle 3 추가). swift / backend / (future: android, ...)
    /// 기존 데이터는 lightweight migration으로 .swift.
    ///
    /// Note: 현재 conceptID prefix 분리(swift-* vs kotlin-* / spring-* / ...)로
    /// 트랙 간 충돌 X. Android 트랙 추가 시 Kotlin Core 공유로 충돌 가능성 발생 →
    /// 그 시점에 (@Attribute(.unique) 제거 + composite uniqueness 도입) 검토.
    var track: String = TrackType.swift.rawValue

    init(
        conceptID: String,
        conceptTitle: String,
        category: String,
        track: TrackType = .swift
    ) {
        self.conceptID = conceptID
        self.conceptTitle = conceptTitle
        self.category = category
        self.studiedCount = 0
        self.masteredCount = 0
        self.isMastered = false
        self.track = track.rawValue
    }

    var trackType: TrackType {
        get { TrackType(rawValue: track) ?? .swift }
        set { track = newValue.rawValue }
    }
}
