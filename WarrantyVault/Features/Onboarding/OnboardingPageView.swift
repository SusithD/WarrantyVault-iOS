import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    let currentIndex: Int
    let totalPages: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Spacer(minLength: 0)

            OnboardingIllustrationView(kind: page.illustration)
                .padding(.horizontal, 40)

            Spacer(minLength: 0)

            VStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text(page.titleFirstLine)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(page.titleSecondLine)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(
                            page.titleSecondLineIsAccent
                            ? AppColors.brandBlue
                            : AppColors.textPrimary
                        )
                }
                .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            PageIndicator(total: totalPages, current: currentIndex)
                .padding(.bottom, 24)

            PrimaryButton(
                title: page.primaryButtonTitle,
                icon: page.primaryButtonIcon,
                action: onNext
            )
            .padding(.horizontal, 24)

            if page.showSkip && !page.showBrandHeader {
                // inline skip below next button (page 2 style)
                SecondaryTextButton(title: "SKIP", action: onSkip)
                    .padding(.top, 4)
            } else {
                Spacer(minLength: 28)
            }

            if let footer = page.footerCaption {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 11, weight: .semibold))
                    Text(footer)
                        .font(AppTypography.overline)
                        .tracking(1.5)
                }
                .foregroundStyle(AppColors.textTertiary)
                .padding(.top, 12)
                .padding(.bottom, 24)
            } else {
                Spacer(minLength: 24)
            }
        }
    }

    @ViewBuilder
    private var topBar: some View {
        if page.showBrandHeader {
            HStack {
                Spacer()
                Text("WarrantyVault")
                    .font(AppTypography.subhead)
                    .foregroundStyle(AppColors.brandBlue)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                if page.showSkip {
                    Button(action: onSkip) {
                        Text("SKIP")
                            .font(AppTypography.captionStrong)
                            .tracking(1.2)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        } else if page.showSkip {
            HStack {
                Spacer()
                Button(action: onSkip) {
                    Text("SKIP")
                        .font(AppTypography.captionStrong)
                        .tracking(1.2)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        } else {
            // Empty top bar to keep layout consistent
            Color.clear.frame(height: 20)
        }
    }
}

#Preview {
    OnboardingPageView(
        page: OnboardingContent.pages[0],
        currentIndex: 0,
        totalPages: 3,
        onNext: {},
        onSkip: {}
    )
    .background(GradientBackground())
}
