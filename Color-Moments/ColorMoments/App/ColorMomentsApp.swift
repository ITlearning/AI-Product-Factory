import Photos
import SwiftUI

@main
struct ColorMomentsApp: App {
    @State private var store: DayStore
    @State private var closures: DayClosures
    @State private var inbox = CaptureInbox()
    @State private var gifts = GiftLog()
    @State private var reconcilerObserver: AssetReconcilerObserver?
    @State private var sync: CloudSync?
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
                    // 모든 저장소 쓰기보다 먼저 켠다 — 구독 전 변경은 저장소가 쌓아 두지만 그건 이중 안전장치일 뿐이다.
                    // 유닛 테스트는 앱을 호스트로 띄운다 — 권한 없는 CKContainer 는 크래시하므로 테스트 중엔 켜지 않는다.
                    if sync == nil, ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                        let s = CloudSync(store: store, closures: closures, gifts: gifts)
                        s.start()
                        sync = s
                    }
                    inbox.dayStore = store
                    inbox.loadExisting()
                    inbox.start()

                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    if status == .authorized || status == .limited {
                        await AssetAdopter.adoptAll(store: store)
                    }

                    await AssetReconciler.reconcile(store: store)
                    if reconcilerObserver == nil {
                        reconcilerObserver = AssetReconcilerObserver(store: store)
                    }

                    await CloudIDMapper.refresh(store: store)
                    await HomeWidget.syncWithArrivalNotice(store: store, closures: closures, gifts: gifts)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 사진이 담기는 경로는 여러 곳이라(잠금화면·라이브러리 입양 등) active/background 전환마다
            // 다시 맞춰 둔다 — active 는 입양·정리가 끝난 뒤에 계산해야 방금 들어온 사진이 반영된다.
            switch newPhase {
            case .active:
                Task {
                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    if status == .authorized || status == .limited {
                        await AssetAdopter.adoptAll(store: store)
                    }
                    await AssetReconciler.reconcile(store: store)
                    await CloudIDMapper.refresh(store: store)
                    await HomeWidget.syncWithArrivalNotice(store: store, closures: closures, gifts: gifts)
                }
            case .background:
                Task { await HomeWidget.syncWithArrivalNotice(store: store, closures: closures, gifts: gifts) }
            default:
                break
            }
        }
    }
}
