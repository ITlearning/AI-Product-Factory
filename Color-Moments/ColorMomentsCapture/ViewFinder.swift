import LockedCameraCapture
import SwiftUI

struct ViewFinder: View {
    let session: LockedCameraCaptureSession
    @State private var engine: CaptureEngine
    @State private var location = LockedLocation()

    init(session: LockedCameraCaptureSession) {
        self.session = session
        let url = session.sessionContentURL
        _engine = State(initialValue: CaptureEngine(destination: { url }))
    }

    var body: some View {
        CaptureScreen(engine: engine, showsDismissHint: true)
            .onAppear { location.start() }
            .onDisappear { location.stop() }
            .onChange(of: engine.lastShot?.url) { _, url in
                guard let url, let data = try? JSONEncoder().encode(location.note(at: Date())) else { return }
                try? data.write(to: LockedPlaceNote.url(for: url))
            }
    }
}
