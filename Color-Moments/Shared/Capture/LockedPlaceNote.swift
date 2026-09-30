import Foundation

/// 잠금화면 촬영 확장이 사진 옆에 두는 위치 쪽지. 확장은 기록 저장소를 못 여니 앱이 들여올 때 읽어 사진에 붙인다.
/// 좌표를 못 받았으면 까닭(권한 상태·오류)만 적는다 — 확장에서 위치가 되는지 보는 창이기도 하다(2026-10-01 시험).
public struct LockedPlaceNote: Codable, Equatable, Sendable {
    public var latitude: Double?
    public var longitude: Double?
    public var accuracy: Double?
    public var fixedAt: Date?
    /// CLAuthorizationStatus.rawValue — 0 미정 · 1 제한 · 2 거부 · 3 항상 · 4 사용 중.
    public var authorization: Int32
    public var error: String?

    public init(latitude: Double? = nil, longitude: Double? = nil, accuracy: Double? = nil, fixedAt: Date? = nil,
                authorization: Int32, error: String? = nil) {
        self.latitude = latitude; self.longitude = longitude; self.accuracy = accuracy
        self.fixedAt = fixedAt; self.authorization = authorization; self.error = error
    }

    /// shot-123.jpg → shot-123.place.json
    public static func url(for photo: URL) -> URL {
        photo.deletingPathExtension().appendingPathExtension("place.json")
    }

    public var place: Place? {
        guard let latitude, let longitude else { return nil }
        return Place(latitude: latitude, longitude: longitude, accuracy: accuracy ?? 0)
    }

    public var summary: String {
        if let accuracy, place != nil { return "좌표 받음 ±\(Int(accuracy))m" }
        let state = ["미정", "제한", "거부", "항상", "사용 중"].indices.contains(Int(authorization))
            ? ["미정", "제한", "거부", "항상", "사용 중"][Int(authorization)] : "\(authorization)"
        return "좌표 없음 — 권한 \(state)" + (error.map { " · \($0)" } ?? "")
    }
}
