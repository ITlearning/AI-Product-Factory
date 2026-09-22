import SwiftUI

/// 방금 담은 것들을 풀스크린으로 넘겨보는 뷰어.
///
/// 기본 카메라의 썸네일 탭과 같은 자리다. 다만 **이번에 켠 동안 담은 것만** 보여준다 —
/// 과거를 뒤지는 화면이 되면 「자정에 열린다」는 구조와 부딪히고, 잠긴 확장은 어차피
/// 앱 저장소를 못 읽는다. 여기는 "방금 그거 뭐였지"를 확인하는 자리이지 갤러리가 아니다.
///
/// 색은 여전히 안 보여준다. 그건 자정의 몫이다.
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
