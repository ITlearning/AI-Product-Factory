import SwiftUI

struct FirstRunOverlay: View {
    let onDismiss: () -> Void

    @State private var sweep = false

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 26) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [.clear, Tone.secondary],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: sweep ? 150 : 0, height: 3)
                        .offset(y: 0)
                    Circle()
                        .fill(Tone.primary)
                        .frame(width: 22, height: 22)
                        .offset(x: sweep ? 150 - 11 : -11)
                }
                .opacity(sweep ? 0 : 1)
                .frame(height: 22)

                Text("왼쪽 가장자리에서 쓸면 담겨요")
                    .font(Face.today)
                    .foregroundStyle(Tone.primary)
                    .padding(.leading, 28)
            }
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { _ in onDismiss() })
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).delay(0.3).repeatForever(autoreverses: false)) {
                sweep = true
            }
        }
        .transition(.opacity)
    }
}
