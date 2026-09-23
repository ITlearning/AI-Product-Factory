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

    private var photo: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)

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

    private var marker: some View {
        Circle()
            .fill(Color(hex: shownHex))
            .frame(width: 34, height: 34)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
            .shadow(color: .black.opacity(0.45), radius: 4)
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
    }

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
