import Foundation

/// 서버 로깅·분석용 익명 디바이스 ID.
///
/// 앱 첫 실행 시 UUID를 생성해 UserDefaults에 저장하고 이후 재사용한다.
/// `identifierForVendor`를 해시하지 않고 별도 UUID를 쓰는 이유:
/// - 재설치 시 자연스럽게 리셋 → 신규 유저 집계와 일치
/// - 프라이버시: Apple advertising identifier와 무관
/// - 구현이 단순하고 테스트 용이
///
/// 더 강한 영속성(재설치 간 유지)이 필요해지면 Keychain으로 이전.
enum AnonymousID {
    private static let key = "codestudy.anonymousUserId"

    /// 현재 기기의 익명 ID. 없으면 새로 생성해 저장.
    static var current: String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}
