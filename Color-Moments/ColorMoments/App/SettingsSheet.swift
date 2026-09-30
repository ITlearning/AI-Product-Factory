import SwiftUI

/// 홈 오른쪽 위 설정 — 조약돌 모양(고르면 그 자리에서 바뀐다)과 사진 앱 ♥ 담기.
struct SettingsSheet: View {
    /// 미리보기에 세울 하루 — 가장 최근에 받은 조약돌, 없으면 견본.
    let preview: [Moment]

    @Environment(\.dismiss) private var dismiss
    @AppStorage(PebbleStyle.key, store: PebbleStyle.store) private var style: PebbleStyle = .round
    @AppStorage(FavoriteAdopter.enabledKey) private var adoptsFavorites = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("설정").font(Face.lineCeremony).foregroundStyle(Tone.primary)
                Spacer()
                Button { dismiss() } label: {
                    Text("닫기")
                        .font(Face.actionSecondary)
                        .foregroundStyle(Tone.primary)
                        .padding(.horizontal, 16)
                        .frame(minHeight: Shape2.minTouch)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)

            Text("조약돌 모양").font(Face.caption).foregroundStyle(Tone.tertiary)
                .padding(.top, 28)
            HStack(spacing: 12) {
                option(.round, "둥근 돌")
                option(.classic, "반듯한 돌")
            }
            .padding(.top, 12)

            Text("사진 앱").font(Face.caption).foregroundStyle(Tone.tertiary)
                .padding(.top, 28)
            Toggle(isOn: $adoptsFavorites) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("♥ 누른 사진도 담기").font(Face.line).foregroundStyle(Tone.primary)
                    Text("오늘 찍고 사진 앱에서 하트를 누르면 몽돌에도 담겨요.")
                        .font(Face.caption).foregroundStyle(Tone.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Tone.primary.opacity(0.6))
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tone.base.ignoresSafeArea())
        .presentationDetents([.height(470)])
        .presentationBackground(Tone.base)
        .preferredColorScheme(.dark)
    }

    private func option(_ s: PebbleStyle, _ title: String) -> some View {
        let on = style == s
        return Button {
            guard style != s else { return }
            Haptics.tickPassed()
            style = s
            AppIconStyle.apply(s)
        } label: {
            VStack(spacing: 10) {
                Group {
                    switch s {
                    case .round:
                        SoftPebbleView(moments: preview, height: 84 * Shape2.softDiameter, glow: .grid)
                    case .classic:
                        LegacyPebbleView(moments: preview, height: 84)
                    }
                }
                .frame(height: 110)
                Text(title).font(Face.guide).foregroundStyle(on ? Tone.primary : Tone.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: Shape2.cardFront, style: .continuous)
                .fill(.white.opacity(on ? 0.08 : 0.03)))
            .overlay(RoundedRectangle(cornerRadius: Shape2.cardFront, style: .continuous)
                .strokeBorder(on ? Tone.secondary : Tone.hairline, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: Shape2.cardFront, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    static let sample: [Moment] = {
        let base = Date(timeIntervalSince1970: 1_758_000_000)
        return ["#6A7EA0", "#9FBDDB", "#F4E6CF", "#F6C7A2", "#EC9383", "#B86676"].enumerated().map {
            Moment(capturedAt: base.addingTimeInterval(Double($0.offset) * 1800),
                   colorHex: $0.element, fileName: "settings-\($0.offset).jpg", source: .app)
        }
    }()
}
