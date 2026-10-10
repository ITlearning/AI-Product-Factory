import Foundation

public struct PaletteColor: Equatable, Sendable {
    public let hex: String
    public let share: Int

    public init(hex: String, share: Int) { self.hex = hex; self.share = share }

    public var encoded: String { "\(hex):\(share)" }

    public init?(encoded: String) {
        let parts = encoded.split(separator: ":")
        guard parts.count == 2, parts[0].count == 7, parts[0].hasPrefix("#"), let s = Int(parts[1]) else { return nil }
        self.init(hex: String(parts[0]), share: s)
    }
}
