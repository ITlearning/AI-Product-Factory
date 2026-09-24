import SwiftUI

struct ShotViewer: View {
    let items: [CaptureEngine.StackItem]
    @Binding var isPresented: Bool
    @State private var index: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    Image(uiImage: item.full ?? item.thumbnail)
                        .resizable()
                        .scaledToFit()
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .automatic : .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    Spacer()
                    if items.count > 1 {
                        Text("\(index + 1) / \(items.count)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.black.opacity(0.45), in: Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Spacer()
                Text("색은 자정에 열려요")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.bottom, 24)
            }
        }
        .statusBarHidden()
    }
}
