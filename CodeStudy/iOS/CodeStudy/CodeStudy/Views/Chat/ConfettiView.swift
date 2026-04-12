import SwiftUI

/// Lightweight confetti particle animation for celebration moments.
/// Zero dependencies — pure SwiftUI Canvas + TimelineView.
struct ConfettiView: View {
    let particleCount: Int
    let duration: Double

    init(particleCount: Int = 80, duration: Double = 2.5) {
        self.particleCount = particleCount
        self.duration = duration
    }

    @State private var particles: [Particle] = []
    @State private var startTime: Date = .now

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let elapsed = context.date.timeIntervalSince(startTime)
                guard elapsed < duration else { return }
                let progress = elapsed / duration

                for particle in particles {
                    draw(particle: particle, progress: progress, in: ctx, size: size)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            particles = (0..<particleCount).map { _ in Particle.random() }
            startTime = .now
        }
    }

    // MARK: - Drawing

    private func draw(particle: Particle, progress: Double, in ctx: GraphicsContext, size: CGSize) {
        // Parabolic trajectory: up + gravity
        let t = progress
        let x = particle.startX * size.width + particle.velocityX * t * 400
        let y = particle.startY * size.height
            + particle.velocityY * t * 400
            + 0.5 * 800 * t * t  // gravity

        // Fade out near the end
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

    private struct Particle {
        let startX: Double      // 0...1 (fraction of width)
        let startY: Double      // 0...1
        let velocityX: Double   // -1...1
        let velocityY: Double   // negative = up
        let size: Double
        let rotation: Double
        let rotationSpeed: Double
        let color: Color

        static func random() -> Particle {
            let palette: [Color] = [
                Color(red: 0.988, green: 0.420, blue: 0.208),  // orange
                Color(red: 0.118, green: 0.227, blue: 0.373),  // deep blue
                Color(red: 0.992, green: 0.831, blue: 0.247),  // yellow
                Color(red: 0.290, green: 0.714, blue: 0.490),  // green
                Color(red: 0.922, green: 0.341, blue: 0.522),  // pink
            ]
            return Particle(
                startX: Double.random(in: 0.3...0.7),
                startY: Double.random(in: 0.4...0.6),
                velocityX: Double.random(in: -1.0...1.0),
                velocityY: Double.random(in: -2.0...(-0.8)),
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
        }
        ConfettiView()
    }
    .ignoresSafeArea()
}
