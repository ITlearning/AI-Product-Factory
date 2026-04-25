import TipKit
import SwiftUI

/// 메인(Learn) 탭에 머물고 있는 사용자에게도 신규 기능을 발견시키기 위한
/// **탭바 위 popover tip**. History 탭 위에 작은 화살표가 아래로 가리키는
/// 형태로 표시.
///
/// 동작:
/// - 1.1.0 첫 실행 시 자동 노출
/// - 사용자가 History 탭을 한 번이라도 열면 영구 dismiss
/// - 명시적 close 탭 시에도 영구 dismiss
struct HistoryTabTip: Tip {

    /// 사용자가 History 탭을 열었는지 여부.
    /// false인 동안만 tip 노출. MainTabView가 selectedTab 변화에 따라 set.
    @Parameter
    static var hasOpenedHistory: Bool = false

    var title: Text {
        Text(String(
            localized: "tip.historyTab.title",
            defaultValue: "새로운 기능이 추가됐어요"
        ))
    }

    var message: Text? {
        Text(String(
            localized: "tip.historyTab.message",
            defaultValue: "학습 기록 탭을 누르면 마스터한 개념의 학습 여정을 다시 볼 수 있어요"
        ))
    }

    var image: Image? {
        Image(systemName: "sparkles")
    }

    /// `hasOpenedHistory == false` 일 때만 노출.
    var rules: [Rule] {
        [#Rule(Self.$hasOpenedHistory) { !$0 }]
    }
}
