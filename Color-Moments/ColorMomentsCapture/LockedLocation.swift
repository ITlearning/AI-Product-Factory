import CoreLocation

/// 잠금화면에서 찍을 때 위치를 한 번 받아 둔다 — 되는지부터 시험(2026-10-01). 안 되면 LockedPlaceNote 에 까닭만 남는다.
@MainActor
final class LockedLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var fix: CLLocation?
    private var failure: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.startUpdatingLocation()
        default: break
        }
    }

    func stop() { manager.stopUpdatingLocation() }

    func note(at capturedAt: Date) -> LockedPlaceNote {
        var note = LockedPlaceNote(authorization: manager.authorizationStatus.rawValue, error: failure)
        if let fix, abs(fix.timestamp.timeIntervalSince(capturedAt)) < 600 {
            note.latitude = fix.coordinate.latitude
            note.longitude = fix.coordinate.longitude
            note.accuracy = fix.horizontalAccuracy
            note.fixedAt = fix.timestamp
        }
        return note
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.start() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.fix = last }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let text = String(describing: error)
        Task { @MainActor in self.failure = text }
    }
}
