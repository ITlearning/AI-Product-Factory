import Photos
import SwiftUI

@main
struct ColorMomentsApp: App {
    @State private var store: DayStore
    @State private var closures: DayClosures
    @State private var inbox = CaptureInbox()
    @State private var gifts = GiftLog()
    @State private var reconcilerObserver: AssetReconcilerObserver?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 첫 화면이 그려지기 전에 꽂아야 첫 프레임부터 에셋 사진이 보인다 — .task 는 첫 렌더 뒤에 돈다.
        ShotImage.assetSource = PhotoAssetSource()
        // store 가 같은 closures 인스턴스를 봐야 「마무리하기」가 그 자리에서 반영된다.
        let closures = DayClosures()
        _closures = State(initialValue: closures)
        _store = State(initialValue: DayStore(closures: closures))
    }

    var body: some Scene {
        WindowGroup {
            HomeShell(store: store, inbox: inbox, gifts: gifts, closures: closures)
                .task {
                    inbox.dayStore = store
                    inbox.loadExisting()
                    inbox.start()

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
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if status == .authorized || status == .limited {
                Task { await AssetAdopter.adoptAll(store: store) }
            }
            AssetReconciler.reconcile(store: store)
        }
    }
}
