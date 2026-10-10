import Photos
import SwiftUI
import UIKit

@main
struct ColorMomentsApp: App {
    @State private var store: DayStore
    @State private var closures: DayClosures
    @State private var inbox = CaptureInbox()
    @State private var gifts: GiftLog
    @State private var reconcilerObserver: AssetReconcilerObserver?
    @State private var sync: CloudSync?
    @State private var catchUp: CatchUp
    @State private var cameraRequest: CameraRequest
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // 첫 화면이 그려지기 전에 꽂아야 첫 프레임부터 에셋 사진이 보인다 — .task 는 첫 렌더 뒤에 돈다.
        ShotImage.assetSource = PhotoAssetSource()
        PhotoEnrichment.weather = WeatherLookup.weather(for:)
        PhotoEnrichment.attribution = WeatherLookup.attribution
        WordModel.install()
        BackgroundHold.install()
        Telemetry.apply()
        PhotoEnrichment.wordRejected = { Telemetry.send(.wordRejected($0)) }
        PhotoEnrichment.wordShown = { Telemetry.send(.wordShown($0)) }
        // 인텐트는 첫 화면보다 먼저 올 수 있다 — 홈이 뜨면 이 표시를 보고 카메라를 연다.
        let cameraRequest = CameraRequest()
        _cameraRequest = State(initialValue: cameraRequest)
        ColorCaptureIntent.opensApp = { cameraRequest.pending = true; Task { @MainActor in EntryPath.shared.mark(.control) } }
        // store 가 같은 closures 인스턴스를 봐야 「마무리하기」가 그 자리에서 반영된다.
        let closures = DayClosures()
        _closures = State(initialValue: closures)
        let store = DayStore(closures: closures, loadsInBackground: true)
        _store = State(initialValue: store)
        let gifts = GiftLog()
        _gifts = State(initialValue: gifts)
        _catchUp = State(initialValue: CatchUp(steps: [
            .init(budget: .seconds(20)) {
                let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                if status == .authorized || status == .limited { await AssetAdopter.adoptAll(store: store) }
            },
            // 입양이 상한을 넘겨 배경에서 계속 돌아도 그대로 이어 돈다 — adoptAll 은 assetID 없는 기록만,
            // reconcile 은 assetID 있는 기록만 건드려 서로 다른 기록을 다루고, remove 는 조회 전 스냅샷 기준이라 안전하다.
            .init(budget: .seconds(5)) { await AssetReconciler.reconcile(store: store) },
            .init(budget: .seconds(5)) { await CloudIDMapper.refresh(store: store) },
            .init(budget: .seconds(5)) { await FavoriteAdopter.run(store: store) },
        ], widgetSync: {
            await HomeWidget.syncWithArrivalNotice(store: store, closures: closures, gifts: gifts)
        }))
    }

    var body: some Scene {
        WindowGroup {
            HomeShell(store: store, inbox: inbox, gifts: gifts, closures: closures, cameraRequest: cameraRequest,
                      prepare: { [catchUp] in await catchUp.run() })
                .onOpenURL { url in
                    if url.scheme == "mongdol", url.host == "widget" { EntryPath.shared.mark(.widget) }
                }
                .task {
                    Task(priority: .userInitiated) { await SoftPebbleView.precompile() }
                    await store.waitUntilLoaded()
                    // 모든 저장소 쓰기보다 먼저 켠다 — 구독 전 변경은 저장소가 쌓아 두지만 그건 이중 안전장치일 뿐이다.
                    // 유닛 테스트는 앱을 호스트로 띄운다 — 권한 없는 CKContainer 는 크래시하므로 테스트 중엔 켜지 않는다.
                    if sync == nil, ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                        let s = CloudSync(store: store, closures: closures, gifts: gifts)
                        s.start()
                        sync = s
                    }
                    inbox.dayStore = store
                    inbox.start()

                    // catchUp 과 무관하게 로드 직후 바로 켠다 — 뒤로 미루면 그 사이 사진 앱 변경을 놓친다.
                    if reconcilerObserver == nil {
                        reconcilerObserver = AssetReconcilerObserver(store: store)
                    }
                    reconcilerObserver?.activateIfAllowed()
                    // 로드 직후 입양·정리·cloudID·위젯까지 한꺼번에 몰리면 첫 화면이 끊긴다 — 첫 차례는 조금 쉬었다 한 줄로(active 전환과 합친다).
                    await catchUp.run()
                }
                // 푸시로 잠금 해제 전에 깨어나면 days.json 을 못 읽는다 — 풀리는 순간 다시 읽어야 저장이 풀린다.
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
                    Task { await store.retryLoadIfNeeded() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .photoAccessRequested)) { _ in
                    reconcilerObserver?.activateIfAllowed()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 사진이 담기는 경로는 여러 곳이라(잠금화면·라이브러리 입양 등) active/background 전환마다
            // 다시 맞춰 둔다 — active 는 입양·정리가 끝난 뒤에 계산해야 방금 들어온 사진이 반영된다.
            switch newPhase {
            case .active:
                // 설정 앱에서 사진 권한을 켜고 돌아온 경우.
                reconcilerObserver?.activateIfAllowed()
                EntryPath.shared.sendAfterGrace()
                Task {
                    await store.retryLoadIfNeeded()
                    await store.waitUntilLoaded()
                    // 잠금화면 수신 스트림은 소식을 안 보낼 때가 있다 — 앞으로 올 때마다 세션 목록을 직접 다시 본다.
                    await inbox.sweep()
                    await catchUp.run()
                }
            case .background:
                // 저장은 백그라운드 큐에 밀려 있을 수 있다 — 멈추기 전에 끝낸다.
                EntryPath.shared.clearIfIdle()
                store.flush()
                sync?.flush()
                Task {
                    await store.waitUntilLoaded()
                    await HomeWidget.syncWithArrivalNotice(store: store, closures: closures, gifts: gifts)
                }
            default:
                break
            }
        }
    }
}

/// 카메라 컨트롤·제어센터가 앱을 열었다는 표시 — 홈이 카메라를 열고 내린다.
@Observable
final class CameraRequest {
    var pending = false

    /// 한 번만 연다 — 온보딩 단계와 상관없이(카메라가 안내 위에 뜬다).
    func take() -> Bool {
        guard pending else { return false }
        pending = false
        return true
    }
}

/// 카메라 요청이 오면 떠 있는 시트·커버(겹친 것까지)를 한 번에 내린다 — 바인딩과 onDismiss 는 SwiftUI 가 따라 맞춘다.
enum PresentedScreens {
    @MainActor
    static func dismissAll(in window: UIWindow? = nil) {
        let window = window ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?.keyWindow
            ?? UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        guard let root = window?.rootViewController, root.presentedViewController != nil else { return }
        root.dismiss(animated: true)
    }
}
