import Foundation

public struct PebbleName: Equatable, Sendable {
    public let name: String
    public let line: String
}

public enum PebbleNaming {

    public static func representative(of moments: [Moment]) -> ColorExtractor.RGB? {
        let colors = moments.compactMap { rgb(fromHex: $0.colorHex) }
        guard !colors.isEmpty else { return nil }
        return colors.max { a, b in saturation(a) < saturation(b) }
    }

    public static func name(for moments: [Moment]) -> PebbleName? {
        guard let c = representative(of: moments) else { return nil }
        return name(for: c)
    }

    public static func name(for c: ColorExtractor.RGB) -> PebbleName {
        let s = saturation(c), v = value(c), h = hue(c)

        if s < 0.12 {
            switch v {
            case ..<0.18: return .init(name: "그믐", line: "빛이 없는 날은 쉬는 날이에요.")
            case ..<0.38: return .init(name: "먹빛", line: "어두운 날도 하루로 남아요.")
            case ..<0.62: return .init(name: "잿빛", line: "무채색인 날도 필요해요.")
            case ..<0.85: return .init(name: "안개", line: "흐릿한 날은 흐릿한 대로 괜찮아요.")
            default: return .init(name: "해미", line: "안 보인다고 없는 건 아니에요.")
            }
        }

        let dark = v < 0.42
        switch h {
        case 345...360, 0..<18:
            return dark ? .init(name: "불씨", line: "작아도 꺼지지 않았어요.")
                        : .init(name: "노을", line: "저무는 빛도 빛이에요.")
        case 18..<45:
            return dark ? .init(name: "아람", line: "익는 데는 시간이 걸려요.")
                        : .init(name: "볕뉘", line: "잠깐 든 볕도 볕이에요.")
        case 45..<70:
            return .init(name: "햇귀", line: "하루는 이런 데서 시작해요.")
        case 70..<160:
            return dark ? .init(name: "이끼", line: "느린 것도 자라는 거예요.")
                        : .init(name: "풀빛", line: "초록은 오래 봐도 안 질려요.")
        case 160..<200:
            return .init(name: "물빛", line: "흘러가는 건 나쁜 게 아니에요.")
        case 200..<235:
            return dark ? .init(name: "너울", line: "큰 물결도 결국 잔잔해져요.")
                        : .init(name: "하늘빛", line: "올려다본 날이었네요.")
        case 235..<265:
            return dark ? .init(name: "미리내", line: "밤이 깊을수록 멀리 보여요.")
                        : .init(name: "새벽빛", line: "가장 어두운 다음에 와요.")
        case 265..<300:
            return .init(name: "어스름", line: "낮과 밤 사이에도 색이 있어요.")
        default:
            return .init(name: "꽃물", line: "물든 자리는 쉽게 지워지지 않아요.")
        }
    }

    static func rgb(fromHex hex: String) -> ColorExtractor.RGB? {
        let t = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        guard t.count == 6, Scanner(string: t).scanHexInt64(&v) else { return nil }
        return .init(r: Double((v >> 16) & 0xFF) / 255,
                     g: Double((v >> 8) & 0xFF) / 255,
                     b: Double(v & 0xFF) / 255)
    }

    static func value(_ c: ColorExtractor.RGB) -> Double { max(c.r, c.g, c.b) }

    static func saturation(_ c: ColorExtractor.RGB) -> Double {
        let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b)
        return mx <= 0 ? 0 : (mx - mn) / mx
    }

    static func hue(_ c: ColorExtractor.RGB) -> Double {
        let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b), d = mx - mn
        guard d > 0 else { return 0 }
        var h: Double
        if mx == c.r { h = 60 * (((c.g - c.b) / d).truncatingRemainder(dividingBy: 6)) }
        else if mx == c.g { h = 60 * ((c.b - c.r) / d + 2) }
        else { h = 60 * ((c.r - c.g) / d + 4) }
        return h < 0 ? h + 360 : h
    }
}
