import SwiftUI
import UIKit

struct HorizontalPan: UIViewRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat, CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handle(_:)))
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat, CGFloat) -> Void

        init(onChanged: @escaping (CGFloat) -> Void, onEnded: @escaping (CGFloat, CGFloat) -> Void) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        @objc func handle(_ pan: UIPanGestureRecognizer) {
            let tx = pan.translation(in: pan.view).x
            switch pan.state {
            case .changed:
                onChanged(tx)
            case .ended, .cancelled, .failed:
                onEnded(tx, pan.velocity(in: pan.view).x)
            default:
                break
            }
        }

        // 시작 시점의 속도만 보고 즉시 갈린다. 세로로 시작한 팬은 «시작조차» 안 하므로
        // 스크롤뷰가 이 인식기를 기다리지 않는다 — SwiftUI DragGesture 로는 표현할 수 없는 지점이다.
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let pan = g as? UIPanGestureRecognizer else { return false }
            let v = pan.velocity(in: pan.view)
            return v.x < 0 && abs(v.x) > abs(v.y) * 1.5
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            false
        }
    }
}
