import CoreImage
import SwiftUI
import UIKit

/// 사진 위 한 점을 찍어 그 순간의 색을 고치는 화면.
///
/// **왜 필요한가** (설계 문서 「알고리즘으로 못 푸는 것」): 벚꽃 꽃잎은 sRGB 에서 채도 0.05~0.12 로
/// 사실상 무채색이고, 그 색상 대역을 나뭇가지와 공유한다. 사람이 「분홍」으로 보는 것은 파란 하늘과의
/// 대비와 «이건 벚꽃»이라는 의미 인식이 만든 것이라 픽셀에 없다. 자동 추출의 상한을 넘는 유일한
/// 수단이 사용자의 한 탭이다.
///
/// **숙제가 되지 않게 하는 제약** (문서에 못 박힌 것):
/// - 기본값은 자동이고 **탭은 안 해도 된다.** 11장 중 9장은 자동이 맞았다.
/// - **미보정 표시·재촉·「확인해주세요」를 넣지 않는다.** 이 화면은 찾아온 사람에게만 열린다.
///
/// **언제 열리나**: 색이 **이미 열린 하루**에서만. 촬영 직후에 붙이면 「누를 땐 색을 안 보여주고
/// 자정에 열린다」는 축이 깨진다.
struct ShotColorPicker: View {
    let moment: Moment
    let onPick: (String) -> Void
    let onRevert: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var pickedPoint: CGPoint?      // 사진 안 0~1 좌표
    @State private var pickedHex: String?
    @State private var candidates: [String] = []

    private var shownHex: String { pickedHex ?? moment.colorHex }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                photo
                palette
            }
            .background(Color.black)
            .navigationTitle("색 고르기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // 자동값으로 되돌리기. 고른 적이 없으면 되돌릴 것도 없다.
                    if moment.colorWasChosen || pickedHex != nil {
                        Button("자동으로") {
                            pickedPoint = nil; pickedHex = nil
                            onRevert()
                        }
                    }
                }
            }
            .task { load() }
        }
    }

    // MARK: 사진 — 아무 데나 누르면 그 점의 색

    private var photo: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        // 좌표 변환은 전부 TapCorrection 이 한다 — 레터박스를 직접 계산하면 조용히 틀린다.
                        .contentShape(Rectangle())
                        .onTapGesture { tap in
                            guard let p = TapCorrection.normalized(
                                tap: tap, in: geo.size, imageSize: image.size) else { return }
                            pick(at: p, image: image)
                        }

                    if let pickedPoint,
                       let v = TapCorrection.viewPoint(normalized: pickedPoint,
                                                       in: geo.size, imageSize: image.size) {
                        marker.position(v)
                    }
                } else {
                    // 사진이 없을 수도 있다(지워졌거나 확장이 못 넘겼거나). 빈 화면 대신 말을 해준다.
                    VStack(spacing: 8) {
                        Image(systemName: "photo").font(.system(size: 28))
                        Text("사진을 찾을 수 없어요").font(.system(size: 13))
                    }
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
    }

    /// 누른 자리. 고른 색을 그 안에 채워 «이 색을 집었다»가 한눈에 보이게 한다.
    private var marker: some View {
        Circle()
            .fill(Color(hex: shownHex))
            .frame(width: 34, height: 34)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
            .shadow(color: .black.opacity(0.45), radius: 4)
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
    }

    // MARK: 아래 — 지금 색과 자동 후보

    private var palette: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: shownHex))
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.25)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(shownHex).font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(pickedHex != nil || moment.colorWasChosen ? "직접 고른 색" : "자동으로 뽑은 색")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
            }

            if !candidates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    // 후보는 «거들 뿐»이다. 여기에 없는 색도 사진을 눌러 집을 수 있다는 게 요점이라
                    // 후보를 위가 아니라 아래에 둔다.
                    Text("사진에서 많이 나온 색")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                    HStack(spacing: 8) {
                        ForEach(candidates, id: \.self) { hex in
                            Button {
                                pickedPoint = nil
                                pickedHex = hex
                                Haptics.snapped()
                                onPick(hex)
                            } label: {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color(hex: hex))
                                    .frame(width: 38, height: 38)
                                    .overlay(RoundedRectangle(cornerRadius: 7)
                                        .strokeBorder(hex == shownHex ? .white : .white.opacity(0.2),
                                                      lineWidth: hex == shownHex ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Text("사진 아무 데나 눌러보세요.")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.35))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24)
        .background(Color.black)
    }

    // MARK: 동작

    private func load() {
        // 원본 그대로 올린다 — 여기는 크게 보고 정확히 집는 자리라 축소본을 쓰면 안 된다.
        guard let img = ShotImage.full(moment.fileName) else { return }
        image = img
        candidates = ShotImage.candidates(in: img, count: 5)
    }

    private func pick(at p: CGPoint, image: UIImage) {
        // **`ShotImage` 를 통해야 한다.** `CIImage(image:)` 를 직접 쓰면 EXIF 방향이 빠져
        // 세로 사진에서 90도 어긋난 자리의 색이 잡힌다.
        guard let rgb = ShotImage.color(in: image, atNormalized: p) else { return }
        let hex = rgb.hex
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            pickedPoint = p
            pickedHex = hex
        }
        Haptics.snapped()
        onPick(hex)
    }
}
