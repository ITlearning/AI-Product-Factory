import LockedCameraCapture
import SwiftUI

struct ViewFinder: View {
    let session: LockedCameraCaptureSession
    @State private var engine: CaptureEngine

    init(session: LockedCameraCaptureSession) {
        self.session = session
        let url = session.sessionContentURL
        _engine = State(initialValue: CaptureEngine(destination: { url }))
    }

    var body: some View {
        CaptureScreen(engine: engine, showsDismissHint: true)
    }
}
