import CoreImage
import SwiftUI
import UIKit

struct ShotColorPicker: View {
    let moment: Moment
    let onPick: (String) -> Void
    let onRevert: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var pickedPoint: CGPoint?
    @State private var pickedHex: String?
    @State private var candidates: [String] = []

    private var shownHex: String { pickedHex ?? moment.colorHex }

    private static let box = CGSize(width: 366, height: 488)

    var body: some View {
        GeometryReader { geo in
            let maxW = min(Self.box.width, geo.size.width - 36)
            let maxH = min(maxW * Self.box.height / Self.box.width, geo.size.height - 330)
            ZStack(alignment: .top) {
                Tone.pure.ignoresSafeArea()
                glow.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    Spacer().frame(height: 22)
                    photo(fitting: CGSize(width: maxW, height: max(0, maxH)))
                    Spacer().frame(height: 26)
                    palette
                    Spacer(minLength: 0)
                }
                .padding(.top, 12)
            }
        }
        .presentationDragIndicator(.hidden)
        .task { load() }
    }

    private var glow: some View {
        VStack {
            Spacer()
            RadialGradient(colors: [Color(hex: shownHex), .clear],
                           center: .bottom, startRadius: 0, endRadius: 380)
                .frame(height: 420)
                .blur(radius: 90)
                .opacity(0.34)
        }
        .animation(.easeInOut(duration: 0.4), value: shownHex)
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack {
            pill("닫기") { dismiss() }
            Spacer()
            Text("색 고르기").font(.system(size: 15, weight: .semibold)).foregroundStyle(Tone.primary)
            Spacer()
            pill("자동으로") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    pickedPoint = nil; pickedHex = nil
                }
                onRevert()
            }
            .opacity(isChosen ? 1 : 0)
            .disabled(!isChosen)
        }
        .padding(.horizontal, 18)
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Tone.primary)
                .padding(.horizontal, 14)
                .frame(minHeight: Shape2.minTouch)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var isChosen: Bool { pickedHex != nil || moment.colorWasChosen }

    private func fitted(_ image: CGSize, in box: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0 else { return box }
        let k = min(box.width / image.width, box.height / image.height)
        return CGSize(width: image.width * k, height: image.height * k)
    }

    @ViewBuilder
    private func photo(fitting box: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: Shape2.photoWindow, style: .continuous)
        if let image {
            // 창을 사진 비율에 맞춰야 TapCorrection 의 좌표계와 화면이 일치한다.
            let size = fitted(image.size, in: box)
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: size.width, height: size.height)
                    .clipShape(shape)
                    .contentShape(shape)
                    .onTapGesture { tap in
                        guard let p = TapCorrection.normalized(
                            tap: tap, in: size, imageSize: image.size) else { return }
                        pick(at: p, image: image)
                    }

                if let pickedPoint,
                   let v = TapCorrection.viewPoint(normalized: pickedPoint,
                                                   in: size, imageSize: image.size) {
                    marker.position(v)
                }
            }
            .frame(width: size.width, height: size.height)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo").font(.system(size: 28))
                Text("사진을 찾을 수 없어요").font(Face.guide)
            }
            .foregroundStyle(Tone.tertiary)
            .frame(width: box.width, height: box.height)
            .background(.white.opacity(0.05), in: shape)
        }
    }

    private var marker: some View {
        Circle()
            .fill(Color(hex: shownHex))
            .frame(width: 34, height: 34)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .background(Circle().fill(.white.opacity(0.12)).frame(width: 48, height: 48))
            .shadow(color: .black.opacity(0.45), radius: 4)
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: Shape2.swatchCurrent, style: .continuous)
                    .fill(Color(hex: shownHex))
                    .frame(width: 46, height: 46)
                    .overlay(RoundedRectangle(cornerRadius: Shape2.swatchCurrent, style: .continuous)
                        .strokeBorder(Tone.hairline))
                VStack(alignment: .leading, spacing: 3) {
                    Text(shownHex).font(Face.hex).foregroundStyle(Tone.primary)
                    Text(isChosen ? "직접 고른 색" : "자동으로 뽑은 색")
                        .font(Face.caption).foregroundStyle(Tone.tertiary)
                }
                Spacer()
            }

            if !candidates.isEmpty {
                Spacer().frame(height: 20)
                Text("사진에서 많이 나온 색").font(Face.caption).foregroundStyle(Tone.tertiary)
                Spacer().frame(height: 8)
                HStack(spacing: 11) {
                    ForEach(candidates, id: \.self) { hex in
                        let on = hex == shownHex
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                pickedPoint = nil
                                pickedHex = hex
                            }
                            Haptics.snapped()
                            onPick(hex)
                        } label: {
                            RoundedRectangle(cornerRadius: Shape2.swatchCandidate, style: .continuous)
                                .fill(Color(hex: hex))
                                .frame(width: 38, height: 38)
                                .overlay(RoundedRectangle(cornerRadius: Shape2.swatchCandidate, style: .continuous)
                                    .strokeBorder(on ? .white : Tone.hairline, lineWidth: on ? 2 : 1))
                                .frame(width: Shape2.minTouch, height: Shape2.minTouch)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, -3)
            }

            Spacer().frame(height: 18)
            Text("사진 아무 데나 눌러보세요.").font(Face.guide).foregroundStyle(Tone.tertiary)
        }
        .padding(.horizontal, 24)
    }

    private func load() {

        guard let img = ShotImage.full(moment.fileName) else { return }
        image = img
        candidates = ShotImage.candidates(in: img, count: 5)
    }

    private func pick(at p: CGPoint, image: UIImage) {

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
