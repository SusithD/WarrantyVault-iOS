import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    var action: () -> Void

    private let height: CGFloat = 52

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(AppTypography.button)
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundStyle(isEnabled ? AppColors.textInverse : AppColors.textTertiary)
            .background(
                Capsule()
                    .fill(isEnabled ? AppColors.accent : AppColors.bgSurfaceHi)
            )
        }
        .disabled(!isEnabled)
        .buttonStyle(PressDimStyle())
    }
}


struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    private let height: CGFloat = 52

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(AppTypography.button)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundStyle(AppColors.textPrimary)
            .background(
                Capsule()
                    .fill(AppColors.bgSurface)
            )
        }
        .buttonStyle(PressDimStyle())
    }
}

private struct PressDimStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

struct SecondaryTextButton: View {
    let title: String
    var color: Color = AppColors.textSecondary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(PressDimStyle())
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Log in") { }
        PrimaryButton(title: "File Claim", icon: "doc.badge.plus") { }
        PrimaryButton(title: "Disabled", isEnabled: false) { }
        SecondaryButton(title: "Edit", icon: "pencil") { }
        SecondaryTextButton(title: "Forgot Passcode?") { }
    }
    .padding()
    .background(GradientBackground())
}
