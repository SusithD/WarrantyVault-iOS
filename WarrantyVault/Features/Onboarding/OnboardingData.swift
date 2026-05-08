import SwiftUI

struct OnboardingPage: Identifiable {
    let id: Int
    let titleFirstLine: String
    let titleSecondLine: String
    let titleSecondLineIsAccent: Bool
    let subtitle: String
    let illustration: OnboardingIllustration
    let primaryButtonTitle: String
    let primaryButtonIcon: String?
    let showBrandHeader: Bool
    let showSkip: Bool
    let footerCaption: String?
}

enum OnboardingIllustration {
    case vault         // page 1 — document with lock + QR
    case notification  // page 2 — card with bell + alert chip
    case biometric     // page 3 — face/avatar with shield + lock
}

enum OnboardingContent {
    static let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            titleFirstLine: "Store Your",
            titleSecondLine: "Warranties Safely",
            titleSecondLineIsAccent: false,
            subtitle: "Keep all your product warranties and receipts in one secure digital vault.",
            illustration: .vault,
            primaryButtonTitle: "Next",
            primaryButtonIcon: "arrow.right",
            showBrandHeader: false,
            showSkip: true,
            footerCaption: nil
        ),
        OnboardingPage(
            id: 1,
            titleFirstLine: "Never Miss",
            titleSecondLine: "an Expiry",
            titleSecondLineIsAccent: false,
            subtitle: "Receive timely notifications before your product warranties expire.",
            illustration: .notification,
            primaryButtonTitle: "Next",
            primaryButtonIcon: nil,
            showBrandHeader: true,
            showSkip: true,
            footerCaption: nil
        ),
        OnboardingPage(
            id: 2,
            titleFirstLine: "Secure and",
            titleSecondLine: "Accessible",
            titleSecondLineIsAccent: true,
            subtitle: "Your data is encrypted and accessible only by you with biometric security.",
            illustration: .biometric,
            primaryButtonTitle: "Get Started",
            primaryButtonIcon: "arrow.right",
            showBrandHeader: false,
            showSkip: false,
            footerCaption: "MILITARY-GRADE ENCRYPTION STANDARD"
        )
    ]
}
