import TipKit
import SwiftUI

/// 학습 기록 탭에서 개념을 탭해 학습 여정을 볼 수 있다는 사실을
/// 한 번만 안내. Cycle 2에서 추가된 핵심 신규 기능.
///
/// TipKit 사용 이유:
/// - iOS 17+ 네이티브, 외부 dep 0 (zero deps 원칙 준수)
/// - Apple 표준 시각/인터랙션 — 학습이 매끄러움
/// - Display frequency / dismiss 영구화 자동 처리
///
/// 표시 조건:
/// - 마스터한 개념이 1개 이상 (0개면 탭해도 empty state라 tip 의미 X)
/// - 한 번 dismiss하면 영구히 안 뜸 (TipKit datastore에서 추적)
struct ConceptHistoryTip: Tip {

    /// 마스터 1개 이상일 때만 tip 노출.
    /// View 측 `.task`에서 SwiftData 결과로 set.
    @Parameter
    static var hasMasteredConcepts: Bool = false

    var title: Text {
        Text(String(
            localized: "tip.history.title",
            defaultValue: "학습 여정 다시 보기"
        ))
    }

    var message: Text? {
        Text(String(
            localized: "tip.history.message",
            defaultValue: "개념을 탭하면 모든 학습 세션과 대화 내용을 다시 볼 수 있어요"
        ))
    }

    var image: Image? {
        Image(systemName: "book.closed.fill")
    }

    /// `hasMasteredConcepts == true` 일 때만 tip 표시.
    /// (Rule 평가는 reactive — Parameter 값 바뀌면 자동 재평가됨)
    var rules: [Rule] {
        [#Rule(Self.$hasMasteredConcepts) { $0 }]
    }
}
