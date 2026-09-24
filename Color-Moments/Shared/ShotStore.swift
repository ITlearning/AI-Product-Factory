import Foundation

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
