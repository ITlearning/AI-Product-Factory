import SwiftUI

/// 한 달 한 줌을 카드로 만들어 건넨다. HandfulView 의 makeShareSheet 클로저로 넘어온다.
struct HandfulShareSheet: View {
    let month: String
    var today = Moment.dayKey(for: Date())
    let pebbleGroups: [[Moment]]

    @State private var rendered: RenderedCard?

    private var label: String { Memories.handfulTitle(month: month, today: today) }

    var body: some View {
        KeepsakeCardStage(rendered: rendered, previewTitle: "몽돌 한 줌",
                          message: Keepsake.shareText(pebbleName: label, appStoreURL: Keepsake.appStoreURL))
            .task(id: month) {
                rendered = RenderedCard(image: CardExporter.renderHandful(month: month, today: today,
                                                                         pebbleGroups: pebbleGroups))
            }
    }
}
