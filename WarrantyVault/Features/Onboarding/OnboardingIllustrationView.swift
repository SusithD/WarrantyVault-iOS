import SwiftUI

struct OnboardingIllustrationView: View {
    let kind: OnboardingIllustration

    var body: some View {
        switch kind {
        case .vault:         VaultIllustration()
        case .notification:  NotificationIllustration()
        case .biometric:     BiometricIllustration()
        }
    }
}


private struct VaultIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AppColors.border,
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 6])
                )
                .frame(width: 280, height: 280)

            GlassCard(padding: 20, cornerRadius: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ZStack {
                            Circle().fill(AppColors.brandBlue)
                                .frame(width: 48, height: 48)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(.top, 4)

                    RoundedRectangle(cornerRadius: 4).fill(AppColors.border.opacity(0.9))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4).fill(AppColors.border.opacity(0.6))
                        .frame(width: 120, height: 8)

                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6).fill(AppColors.warningSoft)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "rosette")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(AppColors.warning)
                            )
                        RoundedRectangle(cornerRadius: 4).fill(AppColors.border.opacity(0.6))
                            .frame(height: 8)
                    }
                    .padding(.top, 4)
                }
                .frame(width: 160)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                Image(systemName: "qrcode")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppColors.brandBlue)
            }
            .offset(x: 100, y: -110)
        }
        .frame(height: 300)
    }
}


private struct NotificationIllustration: View {
    var body: some View {
        ZStack {
            GlassCard(padding: 24, cornerRadius: 28) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.surfaceMuted)
                        .frame(width: 160, height: 100)
                        .rotationEffect(.degrees(-4))
                        .offset(x: -8, y: -8)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white)
                        .frame(width: 160, height: 100)
                        .overlay(
                            HStack(alignment: .top, spacing: 8) {
                                ZStack {
                                    Circle().fill(AppColors.warningSoft)
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(AppColors.warning)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ALERT")
                                        .font(AppTypography.overline)
                                        .foregroundStyle(AppColors.textSecondary)
                                    Text("30 Days Left")
                                        .font(AppTypography.bodyStrong)
                                        .foregroundStyle(AppColors.textPrimary)
                                }
                                Spacer()
                            }
                            .padding(12)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)

                    ZStack {
                        Circle().fill(AppColors.brandBlue)
                            .frame(width: 56, height: 56)
                            .shadow(color: AppColors.brandBlue.opacity(0.35), radius: 10, x: 0, y: 6)
                        Image(systemName: "bell.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 72, y: -52)
                }
                .frame(width: 200, height: 160)
            }
        }
        .frame(height: 260)
    }
}


private struct BiometricIllustration: View {
    var body: some View {
        ZStack {
            GlassCard(padding: 24, cornerRadius: 28) {
                ZStack {
                    Circle()
                        .stroke(AppColors.brandBlue, lineWidth: 2.5)
                        .frame(width: 80, height: 80)

                    VStack(spacing: 4) {
                        HStack(spacing: 10) {
                            Circle().fill(AppColors.brandBlue).frame(width: 6, height: 6)
                            Circle().fill(AppColors.brandBlue).frame(width: 6, height: 6)
                        }
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(AppColors.brandBlue)
                            .frame(width: 20, height: 2)
                    }
                }
                .frame(width: 200, height: 160)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.warning)
            }
            .offset(x: 96, y: -86)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.brandBlue)
            }
            .offset(x: -96, y: 20)
        }
        .frame(height: 260)
    }
}

#Preview {
    VStack(spacing: 32) {
        OnboardingIllustrationView(kind: .vault)
        OnboardingIllustrationView(kind: .notification)
        OnboardingIllustrationView(kind: .biometric)
    }
    .padding()
    .background(GradientBackground())
}
