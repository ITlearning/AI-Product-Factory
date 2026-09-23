import Photos
import SwiftUI

@main
struct ColorMomentsApp: App {
    @State private var store = DayStore()
    @State private var inbox = CaptureInbox()
    @State private var gifts = GiftLog()
    @State private var reconcilerObserver: AssetReconcilerObserver?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeShell(store: store, inbox: inbox, gifts: gifts)
                .task {
                    inbox.dayStore = store
                    inbox.loadExisting()
                    inbox.start()

                    ShotImage.assetSource = PhotoAssetSource()
                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    if status == .authorized || status == .limited {
                        await AssetAdopter.adoptAll(store: store)
                    }

                    AssetReconciler.reconcile(store: store)
                    if reconcilerObserver == nil {
                        reconcilerObserver = AssetReconcilerObserver(store: store)
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            AssetReconciler.reconcile(store: store)
        }
    }
}
