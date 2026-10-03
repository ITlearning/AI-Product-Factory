import Foundation

/// 해 높이와 달 나이 — 날짜와 자리만으로 기기 안에서 계산한다(외부 통신 없음). 오차는 해 높이 1° 안팎, 달 나이 하루 안팎.
public enum Celestial {

    /// 자리를 모르는 사진은 서울로 본다 — 해 뜨고 지는 시각이 나라 안에선 30분 안쪽으로만 달라진다.
    public static let seoul = (latitude: 37.5665, longitude: 126.978)

    private static func julianDay(_ date: Date) -> Double { date.timeIntervalSince1970 / 86_400 + 2_440_587.5 }

    /// 지평선 위 해의 높이(°). 음수면 해가 진 것.
    public static func sunAltitude(at date: Date, latitude: Double, longitude: Double) -> Double {
        let rad = Double.pi / 180
        let n = julianDay(date) - 2_451_545.0
        let meanLongitude = (280.460 + 0.985_647_4 * n).truncatingRemainder(dividingBy: 360)
        let anomaly = (357.528 + 0.985_600_3 * n).truncatingRemainder(dividingBy: 360) * rad
        let eclipticLongitude = (meanLongitude + 1.915 * sin(anomaly) + 0.020 * sin(2 * anomaly)) * rad
        let obliquity = (23.439 - 0.000_000_4 * n) * rad
        let rightAscension = atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude))
        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let siderealHours = (18.697_374_558 + 24.065_709_824_419_08 * n).truncatingRemainder(dividingBy: 24)
        let hourAngle = (siderealHours * 15 + longitude) * rad - rightAscension
        let lat = latitude * rad
        return asin(sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle)) / rad
    }

    public static let synodicMonth = 29.530_588_853

    /// 마지막 삭(그믐 새달)에서 며칠 지났나 — 0 이면 삭, 14.8 안팎이 보름.
    public static func moonAge(at date: Date) -> Double {
        let age = (julianDay(date) - 2_451_550.1).truncatingRemainder(dividingBy: synodicMonth)
        return age < 0 ? age + synodicMonth : age
    }
}
