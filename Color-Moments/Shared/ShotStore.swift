import Foundation

/// 촬영물 저장소. 잠금화면 확장이 넘긴 것과 앱에서 찍은 것이 같이 쌓인다.
///
/// 앱 타깃에만 있으면 `DayStore` 같은 공유 코드에서 못 본다 — Shared 에 둔다.
public enum ShotStore {
    public static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    @discardableResult
    public static func save(_ data: Data, name: String) -> URL? {
        let url = directory.appendingPathComponent(name)
        do { try data.write(to: url); return url } catch { return nil }
    }
}

import SwiftUI

public extension Color {
    /// `#RRGGBB` 문자열에서. 못 읽으면 중간 회색.
    init(hex: String) {
        var v: UInt64 = 0
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&v) else {
            self = Color(white: 0.5); return
        }
        self = Color(red: Double((v >> 16) & 0xFF) / 255,
                     green: Double((v >> 8) & 0xFF) / 255,
                     blue: Double(v & 0xFF) / 255)
    }
}
