import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

enum Grain {
    static let tileSide = 96

    static let image: UIImage? = {
        let ctx = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any])
        let extent = CGRect(x: 0, y: 0, width: tileSide, height: tileSide)

        guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage else { return nil }
        let mono = noise.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0,
            kCIInputContrastKey: 0.55,
        ])

        let grain = mono.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.42])
            .cropped(to: extent)

        guard let cg = ctx.createCGImage(grain, from: extent) else { return nil }
        return UIImage(cgImage: cg)
    }()
}

/// 조약돌 모양 — round 셰이더 조약돌(기본), classic 예전 둥근 사각형. App Group 에 둬서 위젯도 같은 값을 본다.
public enum PebbleStyle: String, CaseIterable, Sendable {
    case round, classic

    public static let key = "pebbleStyle"
    public static let store = UserDefaults(suiteName: WidgetSnapshot.appGroup) ?? .standard
    public static var current: PebbleStyle {
        store.string(forKey: key).flatMap(PebbleStyle.init(rawValue:)) ?? .round
    }
}

/// 바깥 프레임(폭 = 높이×0.70, 높이 = 높이×1.16)은 두 모양이 같다 — 모양을 바꿔도 부르는 쪽 배치가 안 바뀐다.
public struct PebbleView: View {
    private let moments: [Moment]
    private let height: CGFloat
    private let sheen: Double
    private let glow: SoftPebbleView.Glow
    private let classicTilt: Double
    @AppStorage(PebbleStyle.key, store: PebbleStyle.store) private var style: PebbleStyle = .round
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// classicTilt — 예전 모양에서만 돌린다. 둥근 돌은 날마다 기울기가 따로 있고, 뷰를 돌리면 빛과 바닥까지 돈다.
    public init(moments: [Moment], height: CGFloat, sheen: Double = 0, onPhoto: Bool = false,
                glow: SoftPebbleView.Glow = .hero, classicTilt: Double = 0) {
        self.moments = moments
        self.height = height
        self.sheen = sheen
        self.glow = onPhoto ? .photo : glow
        self.classicTilt = classicTilt
    }

    public var body: some View {
        Group {
            switch style {
            case .round:
                SoftPebbleView(moments: moments, height: height * Shape2.softDiameter, glow: glow, sheen: sheen)
            case .classic:
                LegacyPebbleView(moments: moments, height: height, sheen: sheen, onPhoto: glow == .photo)
                    .rotationEffect(.degrees(classicTilt))
            }
        }
        // 흐려지며 작아진 돌이 사라지고 새 돌이 흐림에서 또렷해지며 커진다. 동작 줄이기면 겹쳐 바뀌기만.
        .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
        // 다른 화면에서 바꿔도 여기서 부드럽게 넘어가게 — 값 변경이 withAnimation 트랜잭션 밖에서 도착한다.
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.5, dampingFraction: 0.82), value: style)
        .frame(width: height * Shape2.pebbleRatio, height: height * 1.16)
    }
}

/// 그라데이션 겹으로 그린 예전 조약돌 — 위젯은 셰이더가 도는지 실기기 확인 전까지 이걸 쓴다.
public struct LegacyPebbleView: View {
    private let moments: [Moment]

    private let height: CGFloat

    private let sheen: Double

    private let onPhoto: Bool

    private let silhouette: PebbleSilhouette

    public init(moments: [Moment], height: CGFloat, sheen: Double = 0, onPhoto: Bool = false) {
        self.moments = moments
        self.height = height
        self.sheen = sheen
        self.onPhoto = onPhoto
        let key = moments.first.map(\.dayKey) ?? Moment.dayKey(for: Date())
        self.silhouette = PebbleSilhouette(dayKey: key)
    }

    private var width: CGFloat { height * Shape2.pebbleRatio }
    private var shape: PebbleShape {
        PebbleShape(top: silhouette.topRounding, bottom: silhouette.bottomRounding)
    }

    public var body: some View {
        ZStack {
            wetMark
            body6.zIndex(1)
        }
        .frame(width: width, height: height * 1.16)
    }

    private var body6: some View {

        ZStack {
            dayGradient
            innerLightTop
            innerShadeBottom
        }
        .frame(width: width, height: height)
        .overlay { grainLayer }
        .overlay { sheenLayer }
        .overlay { rimLight }
        .clipShape(shape)

        .drawingGroup()
        .rotationEffect(.degrees(silhouette.tilt))
        .overlay {

            if onPhoto {
                shape.stroke(Tone.base.opacity(0.6), lineWidth: 5)
                    .rotationEffect(.degrees(silhouette.tilt))
                    .frame(width: width, height: height)
                    .blendMode(.destinationOver)
            }
        }

        .shadow(color: .black.opacity(onPhoto ? 0.22 : 0.38),
                radius: onPhoto ? 6 : 10, y: onPhoto ? 3 : 5)
    }

    private var dayGradient: some View {
        let stops = DayGradient.pebbleStops(for: moments)

        let tilt = 0.035
        return Group {
            if stops.isEmpty {
                Color(white: 0.2)
            } else if stops.count == 1 {
                Color(hex: stops[0].hex)
            } else {
                LinearGradient(
                    stops: stops.map { .init(color: Color(hex: $0.hex), location: $0.location) },
                    startPoint: UnitPoint(x: 0.5 + tilt, y: 0),
                    endPoint: UnitPoint(x: 0.5 - tilt, y: 1))
            }
        }
    }

    private func centered(_ cx: Double, _ cy: Double) -> CGSize {
        CGSize(width: (cx - 0.5) * width, height: (cy - 0.5) * height)
    }

    private var innerLightTop: some View {
        EllipticalGradient(
            stops: [.init(color: .white.opacity(0.30), location: 0),
                    .init(color: .white.opacity(0.24), location: 0.34),
                    .init(color: .clear, location: 1)],
            center: .center)
        .frame(width: width * 1.12, height: height * 0.80)
        .offset(centered(0.33, 0.22))
    }

    private var innerShadeBottom: some View {
        EllipticalGradient(
            stops: [.init(color: .black.opacity(0.44), location: 0),
                    .init(color: .black.opacity(0.36), location: 0.40),
                    .init(color: .clear, location: 1)],
            center: .center)
        .frame(width: width * 1.48, height: height * 1.04)
        .offset(centered(0.52, 1.06))
    }

    @ViewBuilder
    private var grainLayer: some View {
        if let g = Grain.image {
            Image(uiImage: g)
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)

                .opacity(0.34)
                .allowsHitTesting(false)
        }
    }

    private var rimLight: some View {
        let band = max(7, height * 0.10)
        return ZStack {

            shape.stroke(
                LinearGradient(colors: [.black.opacity(0.42), .clear, .clear, .white.opacity(0.22)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: band)
                .blur(radius: band * 0.45)
            shape.strokeBorder(.white.opacity(0.17), lineWidth: 1)
        }
    }

    private var wetMark: some View {
        let hex = DayGradient.stops(for: moments).last?.hex ?? "#000000"
        return EllipticalGradient(
            stops: [.init(color: Color(hex: hex).opacity(0.55), location: 0),
                    .init(color: .clear, location: 1)],
            center: .center)
        .frame(width: width * 0.92, height: height * 0.16)
        .blur(radius: max(16, min(28, height * 0.16)))
        .offset(y: height * 0.52)
        .allowsHitTesting(false)
    }

    private var sheenLayer: some View {
        let band = width * 1.15
        let travel = width * 1.05
        let fade = min(1, min(sheen, 1 - sheen) / 0.20)
        return LinearGradient(
            stops: [.init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.07), location: 0.36),
                    .init(color: .white.opacity(0.30), location: 0.50),
                    .init(color: .white.opacity(0.07), location: 0.64),
                    .init(color: .clear, location: 1)],
            startPoint: .leading, endPoint: .trailing)
            .frame(width: band, height: height * 2.2)
            .rotationEffect(.degrees(20))
            .offset(x: -travel + sheen * (travel * 2))
            .opacity(fade)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }
}
