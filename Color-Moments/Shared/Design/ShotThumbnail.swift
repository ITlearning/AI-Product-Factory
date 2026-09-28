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

    public init(moment: Moment, maxPixel: CGFloat) {
        self.moment = moment
        self.maxPixel = maxPixel
    }

    private var image: UIImage? {
        ShotImage.peek(moment, maxPixel: maxPixel)
            ?? (loadedName == moment.fileName ? loaded : nil)
    }

    public var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color(hex: moment.colorHex)
            }
        }
        // 세대 번호를 id 에 같이 물려둔다 — 옵저버·재배정이 세대를 올리면 뜬 칸이 다시 요청한다.
        .task(id: LoadKey(fileName: moment.fileName, generation: ShotImage.generation.value(for: moment.assetID))) {
            let m = moment, name = moment.fileName, px = maxPixel
            guard ShotImage.peek(m, maxPixel: px) == nil else { return }
            let img = await ShotImage.warmWithRetry(m, maxPixel: px)
            guard !Task.isCancelled, name == moment.fileName else { return }
            loaded = img
            loadedName = name
        }
        // 캐시가 이미 들고 있다 — 화면 밖 칸까지 붙잡으면 캐시 상한이 무의미해진다. 다시 보이면 .task 가 다시 돈다.
        .onDisappear {
            loaded = nil
            loadedName = nil
        }
    }
}
