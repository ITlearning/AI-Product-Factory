import UIKit
import XCTest
@testable import ColorMoments

@MainActor
final class CollectionSwipeTests: XCTestCase {

    /// SwiftUI 는 루트 호스팅 뷰와 컨트롤러 사이에 UIKitKeyPressResponder 를 끼운다 — 그걸 흉내 낸다.
    private final class RootView: UIView {
        let middle = Middle()
        override var next: UIResponder? { middle }
    }

    private final class Middle: UIResponder {
        weak var controller: UIViewController?
        override var next: UIResponder? { controller }
    }

    func testPanGoesOnTheRootViewNotTheWindow() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        let root = RootView()
        root.middle.controller = controller
        controller.view = root
        window.rootViewController = controller

        let swipe = CollectionSwipe(mode: .close, edgeZone: 28, onBegan: {}, onChanged: { _ in }, onEnded: { _, _ in })
        let installer = CollectionSwipe.Installer(coordinator: swipe.makeCoordinator())
        root.addSubview(installer)
        window.isHidden = false
        defer { window.isHidden = true }

        XCTAssertTrue(root.gestureRecognizers?.contains { $0 is CollectionSwipe.EdgePan } == true, "루트 뷰에 붙어야 한다")
        XCTAssertFalse(window.gestureRecognizers?.contains { $0 is CollectionSwipe.EdgePan } == true,
                       "창에 붙으면 시트·사진 보기 위 터치까지 받아 뒤 홈이 넘어가고 아래로 쓸어 닫기가 씹힌다")
    }
}
