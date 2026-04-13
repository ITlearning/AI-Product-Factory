import SwiftUI

// MARK: - NotificationStepView (Step 3)
// "매일 학습 리마인더를 받으시겠어요?" — Want daily study reminders?

struct NotificationStepView: View {
    let reminderHour: Int
    let reminderMinute: Int
    let onTimeChange: (Int, Int) -> Void
    let onEnable: () -> Void
    let onSkip: () -> Void

    // Internal time binding
    private var reminderDate: Binding<Date> {
        Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = reminderHour
                components.minute = reminderMinute
                return Calendar.current.date(from: components) ?? .now
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                onTimeChange(components.hour ?? 20, components.minute ?? 0)
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 48)

            // Bell icon
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.warmOrange)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 24)

            // Title
            Text(String(localized: "onboarding.notification.title",
                         defaultValue: "매일 학습 리마인더를 받으시겠어요?"))
                // EN: Want daily study reminders?
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.deepBlue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Description
            Text(String(localized: "onboarding.notification.description",
                         defaultValue: "매일 정해진 시간에 알림을 보내드려요.\n꾸준한 학습이 실력을 만듭니다."))
                // EN: We'll notify you at a set time each day.
                //     Consistency builds skill.
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 32)

            Spacer()
                .frame(height: 40)

            // Time picker
            DatePicker(
                String(localized: "onboarding.notification.time",
                        defaultValue: "알림 시간"),
                // EN: Reminder time
                selection: reminderDate,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 120)
            .padding(.horizontal, 48)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                // Primary: enable notifications
                Button {
                    onEnable()
                } label: {
                    Text(String(localized: "onboarding.notification.enable",
                                 defaultValue: "좋아요"))
                        // EN: Sounds good
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.warmOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Secondary: skip
                Button {
                    onSkip()
                } label: {
                    Text(String(localized: "onboarding.notification.skip",
                                 defaultValue: "괜찮아요"))
                        // EN: No thanks
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    NotificationStepView(
        reminderHour: 20,
        reminderMinute: 0,
        onTimeChange: { _, _ in },
        onEnable: {},
        onSkip: {}
    )
}
