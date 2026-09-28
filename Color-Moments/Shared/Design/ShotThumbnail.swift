import SwiftUI
import UIKit

private struct LoadKey: Equatable {
    let fileName: String
    let generation: Int
}

public struct ShotThumbnail: View {
    private let moment: Moment
    private let maxPixel: CGFloat

    @State private var loaded: UIImage?
    @State private var loadedName: String?
    @State private var showsSpinner = false

    public init(moment: Moment, maxPixel: CGFloat) {
        self.moment = moment
        self.maxPixel = maxPixel
    }

    private var image: UIImage? {
        ShotImage.peek(moment, maxPixel: maxPixel)
            ?? (loadedName == moment.fileName ? loaded : nil)
    }

    public var body: some View {
        ZStack {
            Color(hex: moment.colorHex)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
                    .transition(.opacity)
            } else if showsSpinner {
                ProgressView().tint(Tone.secondary)
                    .transition(.opacity)
            }
        }
        .clipped()
        // 세대 번호를 id 에 같이 물려둔다 — 옵저버·재배정이 세대를 올리면 뜬 칸이 다시 요청한다.
        .task(id: LoadKey(fileName: moment.fileName, generation: ShotImage.generation.value(for: moment.assetID))) {
            let m = moment, name = moment.fileName, px = maxPixel
            guard ShotImage.peek(m, maxPixel: px) == nil else { return }
            // 금방 오는 사진은 표시 없이, 늦어질 때만 작은 표시를 띄운다 — 스크롤 중 깜빡임 방지.
            let spinner = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) { showsSpinner = true }
            }
            let img = await ShotImage.warmWithRetry(m, maxPixel: px)
            spinner.cancel()
            guard !Task.isCancelled, name == moment.fileName else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                showsSpinner = false
                loaded = img
                loadedName = name
            }
        }
        // 캐시가 이미 들고 있다 — 화면 밖 칸까지 붙잡으면 캐시 상한이 무의미해진다. 다시 보이면 .task 가 다시 돈다.
        .onDisappear {
            loaded = nil
            loadedName = nil
            showsSpinner = false
        }
    }
}
