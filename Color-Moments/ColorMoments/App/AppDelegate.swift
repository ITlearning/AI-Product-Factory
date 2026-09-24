import Observation
import UIKit
import UserNotifications

/// 알림을 눌러 앱이 열릴 때 HomeView 에 어느 날을 펼지 알린다.
@Observable
final class NotificationRoute {
    var openDay: String?
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let route = NotificationRoute()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // 포그라운드에서 오는 알림은 배너를 띄우지 않는다 — 이미 보고 있다.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let dayKey = response.notification.request.content.userInfo["dayKey"] as? String {
            route.openDay = dayKey
        }
        completionHandler()
    }
}
