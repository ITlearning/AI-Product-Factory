// tests/ios-reminder-parity.json 을 만든다 — App/ArrivalNotice.swift · PebbleName.swift 의 함수를 그대로 옮겨 2026~2027 하루마다 값을 뽑는다.
// cd Mongdol-ENFP-Web/tests && swift ../tools/ios_reminder_parity.swift && mv ios-parity.json ios-reminder-parity.json
import Foundation
func dayNumber(_ key: String) -> Int? {
    let p = key.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3, (1...12).contains(p[1]), (1...31).contains(p[2]) else { return nil }
    let y = p[0] - (p[1] <= 2 ? 1 : 0)
    let era = (y >= 0 ? y : y - 399) / 400
    let yoe = y - era * 400
    let doy = (153 * (p[1] + (p[1] > 2 ? -3 : 9)) + 2) / 5 + p[2] - 1
    return era * 146_097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719_468
}
func hash(_ s: String) -> UInt64 {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for b in s.utf8 { h ^= UInt64(b); h = h &* 0x0000_0100_0000_01b3 }
    return h
}
func fires(_ dayKey: String) -> Bool {
    guard let day = dayNumber(dayKey).map({ $0 + 3 }) else { return false }
    let week = Int((Double(day) / 7).rounded(.down))
    let slot = day - week * 7
    let first = Int(hash("\(week)") % 7)
    let second = (first + 2 + Int(hash("\(week)b") % 3)) % 7
    return slot == first || slot == second
}
func eveningMinutes(dayKey: String) -> Int {
    let sunset = [1060, 1090, 1115, 1140, 1165, 1195, 1195, 1170, 1130, 1090, 1050, 1040]
    let p = dayKey.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3 else { return 18 * 60 }
    let m = p[1] - 1, d = Double(p[2])
    let (a, b, t) = d >= 15 ? (m, (m + 1) % 12, (d - 15) / 30) : ((m + 11) % 12, m, (d + 15) / 30)
    return Int(Double(sunset[a]) + (Double(sunset[b] - sunset[a])) * t) - 20
}
var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
var out: [String: [Any]] = [:]
var start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
for _ in 0..<(366*2) {
    let c = cal.dateComponents([.year, .month, .day], from: start)
    let key = String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    out[key] = [fires(key), eveningMinutes(dayKey: key), dayNumber(key)!]
    start = cal.date(byAdding: .day, value: 1, to: start)!
}
let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
FileManager.default.createFile(atPath: "ios-parity.json", contents: data)
print(out.count)
