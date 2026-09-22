import SwiftUI

@main
struct ColorMomentsApp: App {
    @State private var store = DayStore()
    @State private var inbox = CaptureInbox()
    @State private var gifts = GiftLog()

    var body: some Scene {
        WindowGroup {
            HomeView(store: store, inbox: inbox, gifts: gifts)
                .task {
                    inbox.dayStore = store
                    inbox.loadExisting()
                    inbox.start()
                }
        }
    }
}
