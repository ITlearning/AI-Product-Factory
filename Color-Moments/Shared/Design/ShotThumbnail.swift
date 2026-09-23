import SwiftUI
import UIKit

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
        ShotImage.peek(moment.fileName, maxPixel: maxPixel)
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
        .task(id: moment.fileName) {
            let name = moment.fileName, px = maxPixel
            guard ShotImage.peek(name, maxPixel: px) == nil else { return }
            let img = await Task.detached(priority: .userInitiated) {
                ShotImage.warm(name, maxPixel: px)
            }.value
            guard !Task.isCancelled, name == moment.fileName else { return }
            loaded = img
            loadedName = name
        }
    }
}
