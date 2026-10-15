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

final class ShellPagesTests: XCTestCase {
    private let two = ShellPages(words: false)
    private let three = ShellPages(words: true)

    func testWordsTabIsOffUntilItsScreenShips() {
        XCTAssertFalse(ShellPages.wordsTab)
        XCTAssertEqual(ShellPages.live, two)
    }

    func testPagePositions() {
        XCTAssertEqual(ShellPage.camera.progress, 1)
        XCTAssertEqual(ShellPage.home.progress, 0)
        XCTAssertEqual(ShellPage.collection.progress, -1)
        XCTAssertEqual(ShellPage.words.progress, -2)
        XCTAssertEqual(two.tabs, [.home, .collection])
        XCTAssertEqual(three.tabs, [.home, .collection, .words])
        XCTAssertEqual(two.last, .collection)
        XCTAssertEqual(three.last, .words)
    }

    func testNearestPageStopsAtTheEnds() {
        let rows: [(CGFloat, ShellPage, ShellPage)] = [
            // progress, 두 칸, 세 칸
            (1.3, .camera, .camera),
            (1, .camera, .camera),
            (0.51, .camera, .camera),
            (0.49, .home, .home),
            (0, .home, .home),
            (-0.49, .home, .home),
            (-0.51, .collection, .collection),
            (-1, .collection, .collection),
            (-1.49, .collection, .collection),
            (-1.51, .collection, .words),
            (-2, .collection, .words),
            (-2.4, .collection, .words),
        ]
        for (p, inTwo, inThree) in rows {
            XCTAssertEqual(two.nearest(p), inTwo, "두 칸 \(p)")
            XCTAssertEqual(three.nearest(p), inThree, "세 칸 \(p)")
        }
    }

    func testSelectedTabNeverIsCamera() {
        let rows: [(CGFloat, ShellPage, ShellPage)] = [
            (0.8, .home, .home),
            (0, .home, .home),
            (-0.4, .home, .home),
            (-0.6, .collection, .collection),
            (-1.6, .collection, .words),
            (-2, .collection, .words),
        ]
        for (p, inTwo, inThree) in rows {
            XCTAssertEqual(two.tab(at: p), inTwo, "두 칸 \(p)")
            XCTAssertEqual(three.tab(at: p), inThree, "세 칸 \(p)")
        }
    }

    func testTabBarHidesOnTheCameraSide() {
        let rows: [(CGFloat, Bool)] = [(1, false), (0.5, false), (0.02, false), (0.01, true), (0, true),
                                       (-1, true), (-1.5, true), (-2, true)]
        for (p, shows) in rows { XCTAssertEqual(ShellPages.showsTabBar(p), shows, "\(p)") }
    }

    func testArrivalsWaitUnlessExactlyHome() {
        let rows: [(CGFloat, Bool)] = [(1, true), (0.001, true), (0, false), (-0.001, true), (-1, true), (-2, true)]
        for (p, holds) in rows { XCTAssertEqual(ShellPages.holdsArrivals(p), holds, "\(p)") }
    }

    func testCollectionTakesTapsOnlyWhenSettledThere() {
        XCTAssertTrue(ShellPages.acceptsTaps(.collection, progress: -1, swiping: false))
        XCTAssertFalse(ShellPages.acceptsTaps(.collection, progress: -1, swiping: true))
        XCTAssertFalse(ShellPages.acceptsTaps(.collection, progress: -0.9, swiping: false))
        XCTAssertFalse(ShellPages.acceptsTaps(.collection, progress: -2, swiping: false))
        XCTAssertTrue(ShellPages.acceptsTaps(.words, progress: -2, swiping: false))
    }

    func testEdgeSwipeModePerPage() {
        let rows: [(ShellPage, CollectionSwipe.Mode, CollectionSwipe.Mode)] = [
            (.camera, .off, .off),
            (.home, .openFromEdge, .openFromEdge),
            (.collection, .close, CollectionSwipe.Mode(forward: true, back: true)),
            (.words, .off, .close),
        ]
        for (page, inTwo, inThree) in rows {
            XCTAssertEqual(two.edgeSwipe(at: page), inTwo, "두 칸 \(page)")
            XCTAssertEqual(three.edgeSwipe(at: page), inThree, "세 칸 \(page)")
        }
    }

    func testSwipeModeFollowsTheShell() {
        XCTAssertEqual(three.swipeMode(progress: 0, dragStart: nil, cameraDragging: false, onboardingDone: false), .off)
        XCTAssertEqual(three.swipeMode(progress: 0, dragStart: nil, cameraDragging: true, onboardingDone: true), .off)
        XCTAssertEqual(three.swipeMode(progress: 0, dragStart: nil, cameraDragging: false, onboardingDone: true), .openFromEdge)
        XCTAssertEqual(three.swipeMode(progress: 1, dragStart: nil, cameraDragging: false, onboardingDone: true), .off)
        XCTAssertEqual(three.swipeMode(progress: -0.5, dragStart: nil, cameraDragging: false, onboardingDone: true), .off,
                       "애니메이션 도중엔 새 쓸기를 받지 않는다")
        XCTAssertEqual(two.swipeMode(progress: -0.3, dragStart: 0, cameraDragging: false, onboardingDone: true), .openFromEdge,
                       "끄는 동안엔 시작한 칸 기준")
        XCTAssertEqual(two.swipeMode(progress: -0.7, dragStart: -1, cameraDragging: false, onboardingDone: true), .close)
        XCTAssertEqual(three.swipeMode(progress: -1.7, dragStart: -2, cameraDragging: false, onboardingDone: true), .close)
    }

    func testDragIsRubberBandedPastTheNeighbours() {
        let rows: [(ShellPages, CGFloat, CGFloat, CGFloat)] = [
            // 칸, 시작, 끈 자리, 결과
            (two, 0, -0.5, -0.5),
            (two, 0, 0.5, 0.5 * 0.28),
            (two, 0, -1.5, -1 - 0.5 * 0.28),
            (two, -1, -0.5, -0.5),
            (two, -1, -1.5, -1 - 0.5 * 0.28),
            (two, -1, 0.5, 0.5 * 0.28),
            (three, -1, -1.5, -1.5),
            (three, -1, -2.5, -2 - 0.5 * 0.28),
            (three, -1, 0.5, 0.5 * 0.28),
            (three, 0, -1.5, -1 - 0.5 * 0.28),
            (three, -2, -1.5, -1.5),
            (three, -2, -0.5, -1 + 0.5 * 0.28),
        ]
        for (pages, start, x, out) in rows {
            XCTAssertEqual(pages.rubberBanded(x, from: ShellPage(progress: start)!), out, accuracy: 0.0001, "\(pages.words) \(start) \(x)")
        }
    }

    func testSwipeEndTargets() {
        let d = ShellPages.commitDistance, f = ShellPages.flickVelocity
        let rows: [(ShellPages, ShellPage, CGFloat, CGFloat, ShellPage)] = [
            // 칸, 시작, 놓은 자리, 속도, 붙는 칸
            (two, .home, -d - 0.01, 0, .collection),
            (two, .home, -d + 0.01, 0, .home),
            (two, .home, -0.1, -f - 1, .collection),
            (two, .home, -0.1, -f + 1, .home),
            (two, .home, -0.8, f + 1, .collection),
            (two, .home, 0.1, -f - 1, .collection),
            (two, .collection, -1 + d + 0.01, 0, .home),
            (two, .collection, -1 + d - 0.01, 0, .collection),
            (two, .collection, -0.9, f + 1, .home),
            (two, .collection, -0.2, -f - 1, .home),
            (two, .collection, -1.1, -f - 1, .collection),
            (three, .home, -d - 0.01, 0, .collection),
            (three, .home, -0.1, -f - 1, .collection),
            (three, .collection, -1 - d - 0.01, 0, .words),
            (three, .collection, -1 - d + 0.01, 0, .collection),
            (three, .collection, -1.1, -f - 1, .words),
            (three, .collection, -1 + d + 0.01, 0, .home),
            (three, .collection, -0.9, f + 1, .home),
            (three, .collection, -1.6, f + 1, .collection),
            (three, .collection, -0.4, -f - 1, .collection),
            (three, .collection, -1, f + 1, .home),
            (three, .collection, -1, -f - 1, .words),
            (three, .collection, -1.01, 0, .collection),
            (three, .words, -2 + d + 0.01, 0, .collection),
            (three, .words, -1.9, f + 1, .collection),
            (three, .words, -2 + d - 0.01, 0, .words),
            (three, .words, -2.1, -f - 1, .words),
        ]
        for (pages, start, p, vx, target) in rows {
            XCTAssertEqual(pages.target(from: start, progress: p, velocity: vx), target, "\(pages.words) \(start) \(p) \(vx)")
        }
    }

    func testCancelledCameraSwipeSettlesToNearest() {
        XCTAssertEqual(three.nearest(0.6), .camera)
        XCTAssertEqual(three.nearest(0.3), .home)
        XCTAssertEqual(three.nearest(-0.2), .home)
    }
}

final class EdgePanRulesTests: XCTestCase {
    private let both = CollectionSwipe.Mode(forward: true, back: true)

    func testWhichTouchesAreTaken() {
        let rows: [(CollectionSwipe.Mode, CGFloat, Bool)] = [
            (.off, 380, false),
            (.openFromEdge, 380, true),
            (.openFromEdge, 340, false),
            (.close, 10, true),
            (.close, 380, true),
            (both, 10, true),
            (both, 380, true),
        ]
        for (mode, x, takes) in rows {
            XCTAssertEqual(CollectionSwipe.accepts(mode, x: x, width: 390, edgeZone: 44), takes, "\(mode) \(x)")
        }
    }

    func testWhichDirectionBegins() {
        let rows: [(CollectionSwipe.Mode, CGFloat, CGFloat, Bool, Bool)] = [
            // 모드, vx, vy, 가장자리에서 시작, 시작함
            (.openFromEdge, -300, 10, true, true),
            (.openFromEdge, 300, 10, true, false),
            (.openFromEdge, -300, 400, true, false),
            (.close, 300, 10, false, true),
            (.close, -300, 10, true, false),
            (both, -300, 10, true, true),
            (both, -300, 10, false, false),
            (both, 300, 10, false, true),
            (.off, 300, 10, true, false),
        ]
        for (mode, vx, vy, edge, begins) in rows {
            XCTAssertEqual(CollectionSwipe.begins(mode, vx: vx, vy: vy, startedAtEdge: edge), begins, "\(mode) \(vx) \(edge)")
        }
    }
}
