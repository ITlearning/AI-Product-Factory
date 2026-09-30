import SwiftUI
import UIKit

/// 건넬 조약돌 카드 — 사진이 주인공. 고른 사진 한 장 + 그날 그라데이션 틀 + 사진 모서리에 걸친 조약돌, 이름·한 줄·날짜·작은 "몽돌".
/// 장소·단어는 넣지 않는다. 사진은 호출부가 불러와 넘긴다(Shared 는 Photos 를 모른다).
public struct PebbleCard: View {
    private let dayKey: String
    private let pebbleMoments: [Moment]
    private let face: Moment?
    private let photo: UIImage?
    private let drawsPebble: Bool

    /// photo 가 nil 이면(받은 기록 등) face 의 색 면으로 그린다. face 도 nil 이면 그날 첫 돌 색.
    public init(dayKey: String, pebbleMoments: [Moment], face: Moment? = nil, photo: UIImage? = nil) {
        self.init(dayKey: dayKey, pebbleMoments: pebbleMoments, face: face, photo: photo, drawsPebble: true)
    }

    init(dayKey: String, pebbleMoments: [Moment], face: Moment?, photo: UIImage?, drawsPebble: Bool) {
        self.dayKey = dayKey
        self.pebbleMoments = pebbleMoments
        self.face = face
        self.photo = photo
        self.drawsPebble = drawsPebble
    }

    public var body: some View {
        let frame = PebbleCardLayout.photoFrame(aspect: PebbleCardLayout.aspect(of: photo))
        let pebbleAt = PebbleCardLayout.pebbleOrigin(photo: frame)
        ZStack(alignment: .topLeading) {
            background
            photoView
                .frame(width: frame.width, height: frame.height)
                .clipShape(RoundedRectangle(cornerRadius: Shape2.photoWindow, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                .offset(x: frame.minX, y: frame.minY)
            if drawsPebble {
                PebbleView(moments: pebbleMoments, height: PebbleCardLayout.pebbleHeight, onPhoto: true)
                    .offset(x: pebbleAt.x, y: pebbleAt.y)
            }
            VStack(spacing: 0) {
                Spacer().frame(height: PebbleCardLayout.textTop)
                if let named = PebbleNaming.name(for: pebbleMoments) {
                    Text(named.name).font(Face.nameDay).foregroundStyle(Tone.primary)
                    Spacer().frame(height: 6)
                    Text(named.line).font(Face.line).foregroundStyle(Tone.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: PebbleCardLayout.photoArea.width)
                    Spacer().frame(height: 10)
                }
                Text(dateText).font(Face.line).foregroundStyle(Tone.secondary).monospacedDigit()
                Spacer(minLength: 0)
                Text("몽돌").font(Face.caption).foregroundStyle(Tone.tertiary)
                Spacer().frame(height: 28)
            }
            .frame(width: PebbleCardLayout.canvas.width, height: PebbleCardLayout.canvas.height)
        }
        .frame(width: PebbleCardLayout.canvas.width, height: PebbleCardLayout.canvas.height, alignment: .topLeading)
    }

    @ViewBuilder
    private var photoView: some View {
        if let photo {
            Image(uiImage: photo).resizable().scaledToFill()
        } else {
            Color(hex: (face ?? pebbleMoments.first)?.colorHex ?? "#2B3550")
        }
    }

    private var background: some View {
        ZStack {
            Tone.base
            DayGradientView(moments: pebbleMoments, axis: .vertical)
                .blur(radius: 90)
                .opacity(0.55)
        }
        .frame(width: PebbleCardLayout.canvas.width, height: PebbleCardLayout.canvas.height)
    }

    private var dateText: String {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return dayKey }
        return "\(parts[1])월 \(parts[2])일"
    }
}

/// 카드 판형(포인트, 3배로 구우면 1080×1920)과 사진·조약돌 자리 — 뷰와 빈 카드 판정이 같은 값을 본다.
public enum PebbleCardLayout {
    public static let canvas = CGSize(width: 360, height: 640)
    static let photoArea = CGRect(x: 28, y: 60, width: 304, height: 400)
    /// 사진이 없을 때 색 면 비율.
    static let faceAspect: CGFloat = 3 / 4
    // 홈 하루 블록(앞장 314 폭에 돌 84, 앞장 오른쪽 끝 56 안쪽·아래 끝 34 위에서 시작)과 같은 말투.
    public static let pebbleHeight: CGFloat = 84
    static let pebbleInset = CGPoint(x: 56, y: 34)
    static let textTop: CGFloat = photoArea.maxY + 20

    public static func aspect(of photo: UIImage?) -> CGFloat {
        guard let size = photo?.size, size.width > 0, size.height > 0 else { return faceAspect }
        return size.width / size.height
    }

    /// 원본 비율 그대로 사진 영역 안에 가장 크게 — 세로는 높이 가득, 가로는 폭 가득.
    public static func photoFrame(aspect: CGFloat) -> CGRect {
        let a = aspect > 0 ? aspect : faceAspect
        let w = min(photoArea.width, photoArea.height * a)
        let h = w / a
        return CGRect(x: photoArea.midX - w / 2, y: photoArea.midY - h / 2, width: w, height: h)
    }

    /// PebbleView 프레임(폭 = 높이×0.70, 높이 = 높이×1.16) 의 왼쪽 위.
    public static func pebbleOrigin(photo: CGRect) -> CGPoint {
        CGPoint(x: photo.maxX - pebbleInset.x, y: photo.maxY - pebbleInset.y)
    }

    /// 빈 카드 판정 자리(0...1) — 사진 아래로 삐져나온 돌 아랫부분만. 사진이 겹치면 돌이 빠져도 분산이 커 못 잡는다.
    public static func blankRegion(aspect: CGFloat) -> CGRect {
        let photo = photoFrame(aspect: aspect)
        let origin = pebbleOrigin(photo: photo)
        let w = pebbleHeight * Shape2.pebbleRatio
        let rect = CGRect(x: origin.x + w * 0.2, y: photo.maxY + 14, width: w * 0.6, height: 34)
        return CGRect(x: rect.minX / canvas.width, y: rect.minY / canvas.height,
                      width: rect.width / canvas.width, height: rect.height / canvas.height)
    }
}
