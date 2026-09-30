import CoreLocation

/// 몽돌로 찍은 사진에 찍은 곳을 남긴다. 카메라를 열 때 미리 받아 두어 찍는 순간 붙인다.
/// 권한은 첫 사진을 찍은 뒤(사진 권한 다음 차례) 한 번 묻는다 — 온보딩에 한 장 더 늘리지 않는다(2026-10-01 Tabber).
@MainActor
final class PlaceFinder: NSObject, CLLocationManagerDelegate {
    static let shared = PlaceFinder()
    static let enabledKey = "recordsPlace"

    private let manager = CLLocationManager()
    private var recent: CLLocation?
    private var authWaiters: [CheckedContinuation<Void, Never>] = []
    private var fixWaiters: [CheckedContinuation<Void, Never>] = []

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isEnabled: Bool { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
    private var authorized: Bool {
        manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
    }

    /// 카메라를 열 때 — 권한이 있으면 한 번 받아 둔다.
    func warm() {
        guard isEnabled, authorized else { return }
        manager.requestLocation()
    }

    /// 찍은 시각 3분 안에 받은 위치.
    func recentPlace(near date: Date) -> Place? {
        guard isEnabled, let r = recent, abs(r.timestamp.timeIntervalSince(date)) < 180 else { return nil }
        return Self.place(r)
    }

    /// 아직 안 물었으면 묻는다. 허용 상태를 돌려준다.
    func requestIfNeeded() async -> Bool {
        guard isEnabled else { return false }
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { authWaiters.append($0); manager.requestWhenInUseAuthorization() }
        }
        return authorized
    }

    /// 지금 위치 한 번 — 4초 안에 못 받으면 nil.
    func current() async -> Place? {
        guard isEnabled, authorized else { return nil }
        if let r = recent, Date().timeIntervalSince(r.timestamp) < 60 { return Self.place(r) }
        manager.requestLocation()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in await withCheckedContinuation { self.fixWaiters.append($0) } }
            group.addTask { try? await Task.sleep(nanoseconds: 4_000_000_000) }
            await group.next()
            group.cancelAll()
        }
        resumeFix()
        guard let r = recent, Date().timeIntervalSince(r.timestamp) < 60 else { return nil }
        return Self.place(r)
    }

    private static func place(_ l: CLLocation) -> Place {
        Place(latitude: l.coordinate.latitude, longitude: l.coordinate.longitude, accuracy: l.horizontalAccuracy)
    }

    private func resumeFix() {
        let waiting = fixWaiters
        fixWaiters = []
        waiting.forEach { $0.resume() }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status != .notDetermined else { return }
            let waiting = authWaiters
            authWaiters = []
            waiting.forEach { $0.resume() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            recent = last
            resumeFix()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in resumeFix() }
    }
}
