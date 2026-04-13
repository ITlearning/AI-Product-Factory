import SwiftUI

/// Lightweight confetti particle animation.
/// Zero dependencies — pure SwiftUI Canvas + TimelineView.
/// Fires a single burst on appear, then fades out after `duration` seconds.
///
/// Easter egg: to re-fire, change the view's `.id()` from the parent.
/// SwiftUI treats a new ID as a new view → `onAppear` runs again → new burst.
struct ConfettiView: View {
    var particleCount: Int = 80
    var duration: Double = 2.5

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

    private func draw(particle: Particle, progress: Double, in ctx: GraphicsContext, size: CGSize) {
        let t = progress
        let x = particle.startX * size.width + particle.velocityX * t * 400
        let y = particle.startY * size.height
            + particle.velocityY * t * 400
            + 0.5 * 800 * t * t

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

    private struct Particle {
        let startX: Double
        let startY: Double
        let velocityX: Double
        let velocityY: Double
        let size: Double
        let rotation: Double
        let rotationSpeed: Double
        let color: Color

        static func random() -> Particle {
            let palette: [Color] = [
                Color(red: 0.988, green: 0.420, blue: 0.208),
                Color(red: 0.118, green: 0.227, blue: 0.373),
                Color(red: 0.992, green: 0.831, blue: 0.247),
                Color(red: 0.290, green: 0.714, blue: 0.490),
                Color(red: 0.922, green: 0.341, blue: 0.522),
            ]
            return Particle(
                startX: Double.random(in: 0.2...0.8),
                startY: Double.random(in: 0.3...0.5),
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
