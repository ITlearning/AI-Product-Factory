import SwiftUI

// MARK: - ProgressIndicator
// Shared component: horizontal capsule bar showing current onboarding step.

struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    private let barHeight: CGFloat = 4

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.warmOrange : Color.gray.opacity(0.3))
                    .frame(height: barHeight)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .padding(.horizontal)
    }
}


#Preview {
    VStack(spacing: 24) {
        ProgressIndicator(currentStep: 0, totalSteps: 3)
        ProgressIndicator(currentStep: 1, totalSteps: 3)
        ProgressIndicator(currentStep: 2, totalSteps: 3)
    }
    .padding()
}
