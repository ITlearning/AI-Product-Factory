import SwiftUI

/// 한 달 한 줌을 카드로 만들어 건넨다. HandfulView 의 makeShareSheet 클로저로 넘어온다.
struct HandfulShareSheet: View {
    let month: String
    let pebbleGroups: [[Moment]]

    private var image: UIImage? { CardExporter.renderHandful(month: month, pebbleGroups: pebbleGroups) }
    private var label: String {
        let parts = month.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[1]) else { return month }
        return "\(m)월의 한 줌"
    }

    var body: some View {
        ZStack {
            Tone.base.ignoresSafeArea()
            if let image {
                VStack(spacing: 28) {
                    Spacer()
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                        .padding(.horizontal, 40)
                    ShareLink(item: Image(uiImage: image),
                              message: Keepsake.shareText(pebbleName: label,
                                                          appStoreURL: Keepsake.appStoreURL).map(Text.init),
                              preview: SharePreview("몽돌 한 줌", image: Image(uiImage: image))) {
                        Text("건네기")
                            .font(Face.guide)
                            .foregroundStyle(Tone.primary)
                            .padding(.horizontal, 24)
                            .frame(minHeight: Shape2.minTouch)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                    Spacer()
                }
            } else {
                Text("카드를 만들 수 없어요").font(Face.guide).foregroundStyle(Tone.secondary)
            }
        }
    }
}
