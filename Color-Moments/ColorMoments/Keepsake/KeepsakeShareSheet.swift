import SwiftUI

/// 받은 하루의 카드를 보여주고 건넨다. 렌더가 비면(드문 실기기 이슈) 공유 자체를 막는다.
struct KeepsakeShareSheet: View {
    let dayKey: String
    let store: DayStore

    @State private var rendered: RenderedCard?

    private var pebbleMoments: [Moment] { store.pebbleMoments(on: dayKey) }
    private var pebbleName: String { PebbleNaming.name(for: pebbleMoments)?.name ?? "몽돌" }

    var body: some View {
        KeepsakeCardStage(rendered: rendered, previewTitle: "몽돌 카드",
                          message: Keepsake.shareText(pebbleName: pebbleName, appStoreURL: Keepsake.appStoreURL))
            .task(id: dayKey) {
                await RenderedCard.afterPresentation()
                let raw = CardExporter.renderRaw(dayKey: dayKey, pebbleMoments: pebbleMoments)
                rendered = RenderedCard(card: await CardExporter.prepare(raw, region: CardExporter.blankRegion(photo: nil)))
            }
    }
}

/// 렌더를 끝냈는지(nil) 와 렌더가 비었는지(card nil) 를 가른다.
struct RenderedCard {
    let card: CardExporter.Prepared?

    // .task 는 시트가 올라오기 시작할 때 돈다 — 바로 메인에서 렌더하면 올라오는 애니메이션이 멈춘다.
    static func afterPresentation() async {
        try? await Task.sleep(nanoseconds: 350_000_000)
    }
}

/// 카드 시트 공통 무대 — 렌더 중엔 비워 두고, 끝나면 카드와 「건네기」, 비었으면 안내 한 줄.
struct KeepsakeCardStage: View {
    let rendered: RenderedCard?
    let previewTitle: String
    let message: String?

    var body: some View {
        ZStack {
            Tone.base.ignoresSafeArea()
            if let rendered {
                if let card = rendered.card {
                    VStack(spacing: 28) {
                        Spacer()
                        Image(uiImage: card.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                            .padding(.horizontal, 40)
                        ShareLink(item: card.png,
                                  message: message.map(Text.init),
                                  preview: SharePreview(previewTitle, image: Image(uiImage: card.preview))) {
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
            } else {
                ProgressView().tint(Tone.secondary)
            }
        }
    }
}
