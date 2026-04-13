import SwiftUI

/// Lightweight confetti particle animation for celebration moments.
/// Zero dependencies — pure SwiftUI Canvas + TimelineView.
///
/// Supports multiple bursts: call `burst(at:)` to fire confetti from a
/// specific screen position. Each burst is independent and fades out after
/// `duration` seconds. The initial burst fires automatically on appear.
struct ConfettiView: View {
    let particleCount: Int
    let duration: Double

    init(particleCount: Int = 80, duration: Double = 2.5) {
        self.particleCount = particleCount
        self.duration = duration
    }

    /// Each burst has its own particles and start time so multiple can
    /// run simultaneously.
    struct Burst: Identifiable {
        let id = UUID()
        let particles: [Particle]
        let startTime: Date
        /// Normalized origin (0...1) where the confetti erupts from.
        let originX: Double
        let originY: Double
    }

    @State private var bursts: [Burst] = []

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                // Draw all active bursts
                for burst in bursts {
                    let elapsed = context.date.timeIntervalSince(burst.startTime)
                    guard elapsed < duration else { continue }
                    let progress = elapsed / duration

                    for particle in burst.particles {
                        draw(
                            particle: particle,
                            progress: progress,
                            origin: CGPoint(x: burst.originX * size.width,
                                            y: burst.originY * size.height),
                            in: ctx,
                            size: size
                        )
                    }
                }
            }
        }
        // Easter egg: tap anywhere to fire another burst 🎉
        .contentShape(Rectangle())
        .onTapGesture { location in
            // We don't get the Canvas's size here, so use UIScreen as proxy.
            let screenWidth = UIScreen.main.bounds.width
            let screenHeight = UIScreen.main.bounds.height
            let normX = location.x / screenWidth
            let normY = location.y / screenHeight
            addBurst(originX: normX, originY: normY)
        }
        .onAppear {
            // Initial celebration burst from center
            addBurst(originX: 0.5, originY: 0.45)
        }
    }

    // MARK: - Public

    /// Fire a new confetti burst at the given normalized coordinates.
    private func addBurst(originX: Double, originY: Double) {
        let newParticles = (0..<particleCount).map { _ in
            Particle.random(originX: originX, originY: originY)
        }
        let burst = Burst(
            particles: newParticles,
            startTime: .now,
            originX: originX,
            originY: originY
        )
        bursts.append(burst)

        // Cleanup old finished bursts after they expire to save memory
        let dur = duration
        DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.5) {
            bursts.removeAll { Date().timeIntervalSince($0.startTime) > dur }
        }
    }

    // MARK: - Drawing

    private func draw(
        particle: Particle,
        progress: Double,
        origin: CGPoint,
        in ctx: GraphicsContext,
        size: CGSize
    ) {
        let t = progress
        let x = origin.x + particle.velocityX * t * 400
        let y = origin.y
            + particle.velocityY * t * 400
            + 0.5 * 800 * t * t  // gravity

        let opacity = 1.0 - max(0, (t - 0.7) / 0.3)

        let rect = CGRect(
            x: x - particle.size / 2,
            y: y - particle.size / 2,
            width: particle.size,
            height: particle.size
        )

        var path = Path()
        let rotation = Angle.degrees(particle.rotation + t * particle.rotationSpeed * 360)
        let transform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .rotated(by: rotation.radians)
            .translatedBy(x: -rect.midX, y: -rect.midY)

        path.addRect(rect)
        path = path.applying(transform)

        ctx.fill(path, with: .color(particle.color.opacity(opacity)))
    }

    // MARK: - Particle model

    struct Particle {
        let velocityX: Double
        let velocityY: Double
        let size: Double
        let rotation: Double
        let rotationSpeed: Double
        let color: Color

        static func random(originX: Double = 0.5, originY: Double = 0.5) -> Particle {
            let palette: [Color] = [
                Color(red: 0.988, green: 0.420, blue: 0.208),  // orange
                Color(red: 0.118, green: 0.227, blue: 0.373),  // deep blue
                Color(red: 0.992, green: 0.831, blue: 0.247),  // yellow
                Color(red: 0.290, green: 0.714, blue: 0.490),  // green
                Color(red: 0.922, green: 0.341, blue: 0.522),  // pink
            ]
            return Particle(
                velocityX: Double.random(in: -1.2...1.2),
                velocityY: Double.random(in: -2.2...(-0.6)),
                size: Double.random(in: 6...12),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: 1...3),
                color: palette.randomElement() ?? .orange
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.05)
        VStack {
            Text("🎉 마스터!").font(.largeTitle.bold())
            Text("아무 곳이나 터치해보세요").font(.caption).foregroundStyle(.secondary)
        }
        ConfettiView()
    }
    .ignoresSafeArea()
}
