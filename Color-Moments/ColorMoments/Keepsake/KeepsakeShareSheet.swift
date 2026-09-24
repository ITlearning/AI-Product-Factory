import SwiftUI

/// 받은 하루의 카드를 보여주고 건넨다. 렌더가 비면(드문 실기기 이슈) 공유 자체를 막는다.
struct KeepsakeShareSheet: View {
    let dayKey: String
    let store: DayStore

    private var pebbleMoments: [Moment] { store.pebbleMoments(on: dayKey) }
    private var image: UIImage? { CardExporter.render(dayKey: dayKey, pebbleMoments: pebbleMoments) }
    private var pebbleName: String { PebbleNaming.name(for: pebbleMoments)?.name ?? "몽돌" }

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
                              message: Keepsake.shareText(pebbleName: pebbleName,
                                                          appStoreURL: Keepsake.appStoreURL).map(Text.init),
                              preview: SharePreview("몽돌 카드", image: Image(uiImage: image))) {
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
