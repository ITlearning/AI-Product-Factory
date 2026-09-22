import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// 조약돌 표면의 «결». `DESIGN.md` §2.4 4번 겹.
///
/// 원안은 SVG `feTurbulence`(fractalNoise, baseFrequency 0.85–1.2)인데 **SwiftUI·CoreGraphics 에
/// 대응이 없다**(`DESIGN.md` §0 이 짚은 CSS→SwiftUI 갭 둘에 이건 빠져 있었다).
/// 무작위 노이즈를 아주 약하게 흐려 고주파 그레인으로 근사한다.
///
/// **한 번만 굽고 타일로 쓴다.** 조약돌마다 만들면 스크롤에서 죽는다 —
/// 홈은 하루 블록이 세로로 계속 쌓이는 화면이다.
enum Grain {
    static let tileSide = 96

    static let image: UIImage? = {
        let ctx = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any])
        let extent = CGRect(x: 0, y: 0, width: tileSide, height: tileSide)

        guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage else { return nil }
        let mono = noise.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0,      // 색 있는 노이즈는 표면을 얼룩지게 만든다
            kCIInputContrastKey: 0.55,     // 그레인이 세면 «돌»이 아니라 «종이»가 된다
        ])
        // baseFrequency 0.85~1.2 에 해당하는 잔 결. 더 흐리면 뭉개지고 안 흐리면 지저분하다.
        let grain = mono.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.42])
            .cropped(to: extent)

        guard let cg = ctx.createCGImage(grain, from: extent) else { return nil }
        return UIImage(cgImage: cg)
    }()
}

/// 조약돌 하나. `DESIGN.md` §2.4 의 여섯 겹.
///
/// 기존 「그라데이션 + 대각 광택 한 겹」은 **버렸다** — 평면으로 보이는 원인이었다.
/// 4·5번 겹이 그 역할을 대신한다.
public struct PebbleView: View {
    private let moments: [Moment]
    /// 조약돌 높이. 폭은 `Shape2.pebbleRatio`(0.70)로 따라온다.
    private let height: CGFloat
    /// 표면을 훑는 빛(0~1). 0·1 에서는 안 그린 것과 같다.
    private let sheen: Double
    /// 사진 위에 얹히는가. 그때만 분리 테두리를 두른다.
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
            wetMark                 // 6. 바닥 젖은 자국 — 클립 «밖»이라 따로 깐다
            body6.zIndex(1)
        }
        .frame(width: width, height: height * 1.16)   // 젖은 자국이 번질 자리
    }

    private var body6: some View {
        // **겹을 ZStack 에 몰아넣지 말 것.** 자기보다 큰 자식(슁은 높이 2.2배, 아래 그늘은 폭 1.48배)이
        // 섞여 있으면 스택이 그만큼 부풀고, 거기 맞춰 늘어난 도형이 클립과 어긋난다 —
        // 테두리 빛이 **값을 95% 로 과장해도 한 픽셀도 안 그려졌다**(렌더 실측).
        // 크기가 프레임에 묶여야 하는 겹은 `.overlay` 로 얹는다.
        ZStack {
            dayGradient             // 1. 바탕
            innerLightTop           // 2. 속 깊이(위)
            innerShadeBottom        // 3. 속 깊이(아래)
        }
        .frame(width: width, height: height)
        .overlay { grainLayer }     // 4. 결
        .overlay { sheenLayer }     // 슁 (있을 때만 보인다)
        .overlay { rimLight }       // 5. 테두리 빛
        .clipShape(shape)
        // §0: `.blendMode(.overlay)` 는 `drawingGroup()` 안에서만 안정적이다.
        .drawingGroup()
        .rotationEffect(.degrees(silhouette.tilt))
        .overlay {
            // 사진 위에 얹힐 때만. 없으면 조약돌이 사진에 파묻히고, 과하면 오려붙인 것처럼 된다.
            if onPhoto {
                shape.stroke(Tone.base.opacity(0.6), lineWidth: 5)
                    .rotationEffect(.degrees(silhouette.tilt))
                    .frame(width: width, height: height)
                    .blendMode(.destinationOver)
            }
        }
        .shadow(color: .black.opacity(0.38), radius: 10, y: 5)
    }

    // MARK: 1. 바탕 — 176°

    private var dayGradient: some View {
        let stops = DayGradient.stops(for: moments)
        // 176° = 거의 수직, 4° 만 기울었다. 완전 수직이면 인쇄물처럼 보인다.
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

    // MARK: 2·3. 속 깊이 — 돌 «안»에 빛이 고이고 아래가 가라앉는다

    /// **`.position` 을 쓰지 말 것.** ZStack 안에서 좌표계가 예측대로 안 잡혀 두 겹이
    /// 한가운데로 뭉쳤고, 돌 중앙이 시커멓게 죽어 나머지 겹이 전부 먹혔다(렌더 실측).
    /// 중심 이동은 프레임 중앙 기준 `.offset` 으로 한다 — 계산이 눈에 보인다.
    private func centered(_ cx: Double, _ cy: Double) -> CGSize {
        CGSize(width: (cx - 0.5) * width, height: (cy - 0.5) * height)
    }

    private var innerLightTop: some View {
        EllipticalGradient(
            stops: [.init(color: .white.opacity(0.30), location: 0),
                    .init(color: .white.opacity(0.24), location: 0.34),
                    .init(color: .clear, location: 1)],
            center: .center)
        .frame(width: width * 1.12, height: height * 0.80)   // 반지름 56% · 40% → 지름
        .offset(centered(0.33, 0.22))
    }

    private var innerShadeBottom: some View {
        EllipticalGradient(
            stops: [.init(color: .black.opacity(0.44), location: 0),
                    .init(color: .black.opacity(0.36), location: 0.40),
                    .init(color: .clear, location: 1)],
            center: .center)
        .frame(width: width * 1.48, height: height * 1.04)   // 반지름 74% · 52%
        .offset(centered(0.52, 1.06))
    }

    // MARK: 4. 결

    @ViewBuilder
    private var grainLayer: some View {
        if let g = Grain.image {
            Image(uiImage: g)
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                // 50% 는 돌이 아니라 종이처럼 보였다(렌더 실측). 결은 «있는 줄 모르게» 있어야 한다.
                .opacity(0.34)
                .allowsHitTesting(false)
        }
    }

    // MARK: 5. 테두리 빛
    //
    // 원안은 `inset box-shadow` 두 개인데 SwiftUI 에 없다(§0).
    // 안쪽 테두리를 굵게 그려 흐린 뒤 도형으로 잘라 «안으로 스며든 빛»을 만든다.

    private var rimLight: some View {
        let band = max(7, height * 0.10)
        return ZStack {
            // **`strokeBorder` 가 아니라 `stroke` 다.** strokeBorder 는 선을 안쪽으로 밀어넣어
            // 흐리면 그대로 사라진다(렌더 실측 — 테두리가 통째로 안 보였다).
            // stroke 는 선이 경로 위에 걸터앉아 바깥 절반이 클립으로 잘려나가고
            // 안쪽 절반만 남는다 — 이게 inset box-shadow 를 대신하는 방법이다(§0).
            shape.stroke(
                LinearGradient(colors: [.black.opacity(0.42), .clear, .clear, .white.opacity(0.22)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: band)
                .blur(radius: band * 0.45)
            shape.strokeBorder(.white.opacity(0.17), lineWidth: 1)
        }
    }

    // MARK: 6. 젖은 자국 — 바닥에 번지는 그날의 어두운색

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

    // MARK: 슁 — SPEC §4.3 그대로. 진행도 양 끝에서 스스로 잦아든다.

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
