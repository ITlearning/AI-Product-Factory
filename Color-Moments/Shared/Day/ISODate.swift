import Foundation

/// days.json 이 쓰는 고정 형식(yyyy-MM-ddTHH:mm:ss[.fff]Z)만 손으로 읽는다 — ISO8601DateFormatter 는 3,000건에 150ms 가 넘는다.
enum ISODate {

    /// 형식이 다르면 nil — 호출부가 포매터로 다시 읽는다.
    static func parse(_ text: String) -> Date? {
        var text = text
        return text.withUTF8 { parse(utf8: $0) }
    }

    private static func parse(utf8 b: UnsafeBufferPointer<UInt8>) -> Date? {
        guard b.count >= 20, b[4] == 45, b[7] == 45, b[10] == 84, b[13] == 58, b[16] == 58,
              b[b.count - 1] == 90 else { return nil }
        func num(_ from: Int, _ len: Int) -> Int? {
            var v = 0
            for i in from..<(from + len) {
                let d = Int(b[i]) - 48
                guard d >= 0, d <= 9 else { return nil }
                v = v * 10 + d
            }
            return v
        }
        guard let y = num(0, 4), let mo = num(5, 2), let d = num(8, 2),
              let h = num(11, 2), let mi = num(14, 2), let s = num(17, 2),
              (1...12).contains(mo), (1...31).contains(d), h < 24, mi < 60, s < 61 else { return nil }
        var frac = 0.0
        if b.count > 20 {
            guard b[19] == 46, b.count - 21 >= 1, b.count - 21 <= 9, let f = num(20, b.count - 21) else { return nil }
            frac = Double(f) / pow(10, Double(b.count - 21))
        } else if b[19] != 90 {
            return nil
        }
        let seconds = daysFromCivil(y, mo, d) * 86_400 + h * 3600 + mi * 60 + s
        return Date(timeIntervalSince1970: Double(seconds) + frac)
    }

    // Howard Hinnant 의 days_from_civil — 1970-01-01 부터 센 날 수.
    private static func daysFromCivil(_ y0: Int, _ m: Int, _ d: Int) -> Int {
        let y = m <= 2 ? y0 - 1 : y0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }
}
