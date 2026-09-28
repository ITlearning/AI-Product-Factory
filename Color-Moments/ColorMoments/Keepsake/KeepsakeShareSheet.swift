import SwiftUI
import UIKit

/// 받은 하루의 카드 — 좌우로 넘겨 그날 사진 중 한 장을 고르고, 고른 사진으로 카드를 다시 구워 건넨다.
struct KeepsakeShareSheet: View {
    let dayKey: String
    let store: DayStore

    @State private var selection: Moment.ID?
    // 카드용 사진(긴 변 1600px)은 고른 장과 양옆만 들고 있는다. 값이 nil 이면 불러왔지만 없는 사진(색 면).
    @State private var photos: [Moment.ID: UIImage?] = [:]
    @State private var rendered: (id: Moment.ID, card: RenderedCard)?
    @State private var presented = false

    init(dayKey: String, store: DayStore, viewingID: Moment.ID? = nil) {
        self.dayKey = dayKey
        self.store = store
        _selection = State(initialValue: Keepsake.initialPhotoID(photos: store.moments(on: dayKey), viewing: viewingID))
    }

    private var dayPhotos: [Moment] { store.moments(on: dayKey) }
    private var pebbleMoments: [Moment] { store.pebbleMoments(on: dayKey) }
    private var pebbleName: String { PebbleNaming.name(for: pebbleMoments)?.name ?? "몽돌" }
    private var current: RenderedCard? {
        guard selection != nil else { return RenderedCard(card: nil) }
        return rendered?.id == selection ? rendered?.card : nil
    }

    var body: some View {
        ZStack {
            Tone.base.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer().frame(height: 12)
                pages
                KeepsakeShareButton(rendered: current, previewTitle: "몽돌 카드",
                                    message: Keepsake.shareText(pebbleName: pebbleName, appStoreURL: Keepsake.appStoreURL))
                Spacer().frame(height: 12)
            }
        }
        .task(id: selection) { await prepare() }
    }

    private var pages: some View {
        TabView(selection: $selection) {
            ForEach(dayPhotos) { m in
                page(m).tag(Optional(m.id))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: dayPhotos.count > 1 ? .automatic : .never))
    }

    private func page(_ m: Moment) -> some View {
        GeometryReader { geo in
            let size = PebbleCardLayout.canvas
            let scale = max(0, min(geo.size.width / size.width, (geo.size.height - 36) / size.height))
            Group {
                if let loaded = photos[m.id] {
                    PebbleCard(dayKey: dayKey, pebbleMoments: pebbleMoments, face: m, photo: loaded)
                } else {
                    ZStack { Tone.base; ProgressView().tint(Tone.secondary) }
                }
            }
            .frame(width: size.width, height: size.height)
            .scaleEffect(scale)
            .frame(width: size.width * scale, height: size.height * scale)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
            .frame(width: geo.size.width, height: max(0, geo.size.height - 36))
        }
        .padding(.horizontal, 40)
    }

    private func prepare() async {
        guard let id = selection, let m = dayPhotos.first(where: { $0.id == id }) else {
            rendered = nil
            return
        }
        if !presented {
            await RenderedCard.afterPresentation()
            presented = true
        }
        await load(around: id)
        guard !Task.isCancelled, selection == id, let loaded = photos[id] else { return }
        // 넘기는 도중(다른 장이 골라짐)엔 굽지 않는다 — ImageRenderer 는 메인에서 돈다.
        let raw = CardExporter.renderRaw(dayKey: dayKey, pebbleMoments: pebbleMoments, face: m, photo: loaded)
        let card = RenderedCard(card: await CardExporter.prepare(raw, region: CardExporter.blankRegion(photo: loaded)))
        guard !Task.isCancelled, selection == id else { return }
        rendered = (id, card)
    }

    private func load(around id: Moment.ID) async {
        let all = dayPhotos
        guard let i = all.firstIndex(where: { $0.id == id }) else { return }
        let keep = all[max(0, i - 1)...min(all.count - 1, i + 1)]
        let keepIDs = Set(keep.map(\.id))
        photos = photos.filter { keepIDs.contains($0.key) }
        // 고른 장 먼저 — 양옆은 넘길 때 바로 보이도록 뒤이어.
        for m in [all[i]] + keep.filter({ $0.id != id }) where photos[m.id] == nil {
            let image = await CardExporter.cardPhoto(m)
            guard !Task.isCancelled else { return }
            photos[m.id] = .some(image)
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

/// 한 줌 카드 시트 무대 — 렌더 중엔 비워 두고, 끝나면 카드와 「건네기」, 비었으면 안내 한 줄.
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
                        KeepsakeShareButton(rendered: rendered, previewTitle: previewTitle, message: message)
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

/// 「건네기」 자리 — 굽는 중엔 작은 로딩, 비었으면 안내 한 줄. 높이를 고정해 카드가 흔들리지 않게.
struct KeepsakeShareButton: View {
    let rendered: RenderedCard?
    let previewTitle: String
    let message: String?

    var body: some View {
        Group {
            if let rendered {
                if let card = rendered.card {
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
                } else {
                    Text("카드를 만들 수 없어요").font(Face.guide).foregroundStyle(Tone.secondary)
                }
            } else {
                ProgressView().tint(Tone.secondary)
            }
        }
        .frame(minHeight: Shape2.minTouch)
    }
}
