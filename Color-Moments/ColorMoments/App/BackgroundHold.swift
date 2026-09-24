import UIKit

/// 앱이 background 로 가도 하던 쓰기·위젯 갱신을 끝낼 시간을 빌린다. 놓는 closure 는 한 번만 효과가 있다.
enum BackgroundHold {

    @MainActor
    static func begin(_ name: String) -> CoalescingWriter.Release {
        let state = Box()
        let end: CoalescingWriter.Release = {
            DispatchQueue.main.async {
                guard state.id != .invalid else { return }
                UIApplication.shared.endBackgroundTask(state.id)
                state.id = .invalid
            }
        }
        state.id = UIApplication.shared.beginBackgroundTask(withName: name) {
            MainActor.assumeIsolated {
                guard state.id != .invalid else { return }
                UIApplication.shared.endBackgroundTask(state.id)
                state.id = .invalid
            }
        }
        return end
    }

    /// CoalescingWriter 에 꽂는 것 — 메인 밖에서 부르면 확장용 기본값으로.
    static func install() {
        CoalescingWriter.activityHolder = { name in
            guard Thread.isMainThread else { return CoalescingWriter.expiringActivity(name) }
            return MainActor.assumeIsolated { begin(name) }
        }
    }

    private final class Box: @unchecked Sendable {
        var id: UIBackgroundTaskIdentifier = .invalid
    }
}
