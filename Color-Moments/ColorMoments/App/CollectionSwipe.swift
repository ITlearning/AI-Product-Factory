import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// 홈 ↔ 모은 조약돌을 넘기는 가로 팬. SwiftUI 루트 호스팅 뷰에 붙여 사진 더미 넘기기·날짜 스크럽·스크롤·조약돌 탭보다
/// 먼저 판정한다 — 다른 인식기는 이 팬이 포기할 때까지 기다리고, 받지 않을 터치는 닿자마자 포기해 지연이 없다.
struct CollectionSwipe: UIViewRepresentable {
    enum Mode: Equatable {
        case off
        /// 홈 — 오른쪽 가장자리에서 시작해 왼쪽으로.
        case openFromEdge
        /// 모은 조약돌 — 어디서든 오른쪽으로.
        case close
    }

    var mode: Mode
    var edgeZone: CGFloat
    /// 받을 터치가 닿은 순간(움직이기 전) — 처음 여는 격자를 이때 만들기 시작하면 첫 스와이프가 멈칫하지 않는다.
    var onTouchDown: () -> Void = {}
    var onBegan: () -> Void
    var onChanged: (_ translation: CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeUIView(context: Context) -> Installer {
        Installer(coordinator: context.coordinator)
    }

    func updateUIView(_ view: Installer, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    static func dismantleUIView(_ view: Installer, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    /// 자리만 차지하는 뷰 — 창에 붙는 순간 루트 호스팅 뷰를 찾아 팬을 옮겨 단다. 스스로는 터치를 받지 않는다.
    final class Installer: UIView {
        private let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("not supported") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            coordinator.install(on: hostRoot())
        }

        private func hostRoot() -> UIView? {
            var view = superview
            while let current = view {
                if current.next is UIViewController { return current }
                view = current.superview
            }
            return window
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: CollectionSwipe
        private let pan = EdgePan()

        init(parent: CollectionSwipe) {
            self.parent = parent
            super.init()
            pan.addTarget(self, action: #selector(handle(_:)))
            pan.delegate = self
            pan.accepts = { [weak self] point in self?.accepts(point) ?? false }
            pan.touchedDown = { [weak self] in self?.parent.onTouchDown() }
        }

        func install(on host: UIView?) {
            guard let host, pan.view !== host else { return }
            pan.view?.removeGestureRecognizer(pan)
            host.addGestureRecognizer(pan)
        }

        func uninstall() {
            pan.view?.removeGestureRecognizer(pan)
        }

        private func accepts(_ point: CGPoint) -> Bool {
            switch parent.mode {
            case .off: false
            case .openFromEdge: point.x >= (pan.view?.bounds.width ?? 0) - parent.edgeZone
            case .close: true
            }
        }

        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            let v = pan.velocity(in: pan.view)
            guard abs(v.x) > abs(v.y) else { return false }
            switch parent.mode {
            case .off: return false
            case .openFromEdge: return v.x < 0
            case .close: return v.x > 0
            }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            true
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            false
        }

        @objc private func handle(_ pan: UIPanGestureRecognizer) {
            let tx = pan.translation(in: pan.view).x
            switch pan.state {
            case .began:
                parent.onBegan()
                parent.onChanged(tx)
            case .changed:
                parent.onChanged(tx)
            case .ended, .cancelled:
                parent.onEnded(tx, pan.velocity(in: pan.view).x)
            default:
                break
            }
        }
    }

    /// 받지 않을 터치는 touchesBegan 에서 바로 포기한다 — 움직임을 기다리면 그동안 스크롤·탭이 전부 멈춘다.
    final class EdgePan: UIPanGestureRecognizer {
        var accepts: (CGPoint) -> Bool = { _ in false }
        var touchedDown: () -> Void = {}

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesBegan(touches, with: event)
            guard state == .possible, let touch = touches.first, let view else { return }
            if accepts(touch.location(in: view)) { touchedDown() } else { state = .failed }
        }
    }
}
