import SwiftUI

struct SplashView: View {
    var onFinish: () -> Void

    @State private var isVisible = false

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.white)
                        .frame(width: 96, height: 96)
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppColors.brandBlue)
                        .frame(width: 72, height: 72)

                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(isVisible ? 1 : 0.9)
                .opacity(isVisible ? 1 : 0)

                Text("WarrantyVault")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.top, 20)

                Text("SECURE ASSET MANAGEMENT")
                    .font(AppTypography.overline)
                    .tracking(2.0)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, 6)

                Spacer()

                PageIndicator(total: 3, current: 0)
                    .padding(.bottom, 48)

                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("BANK-GRADE ENCRYPTION")
                            .font(AppTypography.overline)
                            .tracking(1.5)
                    }
                    .foregroundStyle(AppColors.textTertiary)

                    Text("© 2024 WarrantyVault Inc.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                onFinish()
            }
        }
    }
}

#Preview {
    SplashView(onFinish: {})
}
