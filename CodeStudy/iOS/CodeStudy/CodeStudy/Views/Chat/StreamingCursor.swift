import SwiftUI

struct StreamingCursor: View {
    @State private var isVisible = true

    var body: some View {
        Text("\u{2588}")
            .font(.system(.callout, design: .monospaced))
            .foregroundStyle(Color.primary)
            .opacity(isVisible ? 1 : 0)
            .animation(
                .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                value: isVisible
            )
            .onAppear {
                isVisible.toggle()
            }
    }
}

#Preview {
    StreamingCursor()
        .padding()
}
