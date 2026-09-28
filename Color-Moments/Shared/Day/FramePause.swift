import Foundation

public enum FramePause {
    /// 한 프레임 쉰다 — Task.yield 는 런루프를 한 바퀴 돌리지 않아 그 사이 화면이 안 그려질 수 있다.
    public static func next() async {
        try? await Task.sleep(nanoseconds: 16_000_000)
    }
}
