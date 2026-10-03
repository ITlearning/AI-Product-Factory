import Foundation

public struct ZoomLadder: Equatable {

    public let presets: [Double]
    public let range: ClosedRange<Double>
    let multiplier: Double

    private static let crop = 2.0
    private static let cropCoveredBy = 1.5...2.5
    private static let reachBeyondLongest = 2.0
    private static let rampSeconds = 0.3
    private static let minRampRate = 2.0

    public init(multiplier: Double, switchOvers: [Double], minRaw: Double, maxRaw: Double) {
        let m = multiplier > 0 ? multiplier : 1
        let lo = minRaw * m
        let deviceMax = maxRaw * m
        var lenses = Set(([1.0] + switchOvers).map { Self.tenth($0 * m) })
        lenses.insert(1)
        lenses = lenses.filter { $0 >= lo - 0.05 && $0 <= deviceMax + 0.05 }
        // A real tele near 2x (2x on 11 Pro, 2.5x on 12 Pro Max) already is the crop button.
        if Self.crop <= deviceMax, !lenses.contains(where: Self.cropCoveredBy.contains) {
            lenses.insert(Self.crop)
        }
        let hi = max(lo, min(deviceMax, (lenses.max() ?? 1) * Self.reachBeyondLongest))
        self.multiplier = m
        presets = lenses.sorted()
        range = lo...hi
    }

    public func raw(forDisplay display: Double) -> Double { clamped(display) / multiplier }

    public func display(forRaw raw: Double) -> Double { raw * multiplier }

    public func clamped(_ display: Double) -> Double { min(max(display, range.lowerBound), range.upperBound) }

    public func nearest(to display: Double) -> Double? {
        guard display > 0 else { return presets.first }
        return presets.min { abs(log($0 / display)) < abs(log($1 / display)) }
    }

    public static func rampRate(from: Double, to: Double) -> Float {
        guard from > 0, to > 0 else { return Float(minRampRate) }
        return Float(max(minRampRate, abs(log2(to / from)) / rampSeconds))
    }

    public static func label(_ display: Double) -> String {
        let shown = tenth(display)
        return (shown >= 10 || shown == shown.rounded() ? String(format: "%.0f", shown) : String(format: "%.1f", shown)) + "×"
    }

    public static func presetLabel(_ display: Double) -> String {
        let shown = tenth(display)
        if shown == shown.rounded() { return String(format: "%.0f", shown) }
        let text = String(format: "%.1f", shown)
        return shown < 1 ? String(text.dropFirst()) : text
    }

    private static func tenth(_ v: Double) -> Double { (v * 10).rounded() / 10 }
}
