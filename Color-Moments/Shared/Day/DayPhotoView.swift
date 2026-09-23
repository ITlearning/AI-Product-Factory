import SwiftUI
import UIKit

struct DayPhotoView: View {
    let moment: Moment

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Tone.pure.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 0)
                Group {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFit()
                    } else {
                        Color(hex: moment.colorHex).aspectRatio(3 / 4, contentMode: .fit)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Shape2.photoWindow, style: .continuous))
                .padding(.horizontal, 18)

                HStack(spacing: 8) {
                    Circle().fill(Color(hex: moment.colorHex)).frame(width: 13, height: 13)
                    Text(DayGradient.timeText(moment.capturedAt))
                        .font(.system(size: 15, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Tone.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if v.translation.height > 80 { dismiss() }
        })
        .statusBarHidden()
        .task(id: moment.fileName) {
            let name = moment.fileName
            image = await Task.detached(priority: .userInitiated) { ShotImage.full(name) }.value
        }
    }
}
