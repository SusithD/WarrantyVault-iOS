# WarrantyVault — iOS App Boilerplate

SwiftUI boilerplate for the WarrantyVault app. This package contains the **first 5 entry-flow screens**, wired together with a lightweight coordinator, plus a reusable design-system layer that matches the finalized Figma designs.

## What's included

### Screens (5)
1. **Splash** (`Features/Splash/SplashView.swift`) — 1.8s branded splash with scale-in vault badge, auto-advances to onboarding.
2. **Onboarding 1 — Store** (`Features/Onboarding/*`) — "Your warranties, always at hand."
3. **Onboarding 2 — Remind** — "Never miss an expiry again."
4. **Onboarding 3 — Protect** — "Family-safe. Biometrically locked."
5. **Authentication** (`Features/Authentication/AuthenticationView.swift`) — Face ID / Touch ID with passcode fallback (uses `LocalAuthentication`).

### Design system (`DesignSystem/`)
- `AppColors.swift` — brand blue `#0A84FF`, background gradient, text tokens, status colors.
- `AppTypography.swift` — SF Pro type scale + `.overlineStyle()` modifier for ALL-CAPS labels.
- `GradientBackground.swift` — screen-wide vertical gradient.
- `PrimaryButton.swift` — 52pt pill CTA + `SecondaryTextButton`.
- `PageIndicator.swift` — capsule dash indicator that widens the current page.
- `GlassCard.swift` — white glassmorphic card with soft shadow.

### Navigation
- `App/AppCoordinator.swift` — `@Observable` coordinator exposing `stage: AppFlowStage` (`.splash` → `.onboarding` → `.authentication` → `.mainApp`) with transitions.
- `WarrantyVaultApp.swift` — root `RootView` switches on stage with a cross-fade.

## Requirements
- **Xcode 15** or newer
- **iOS 17.0** deployment target
- **Swift 5.0**

## How to open
1. Double-click `WarrantyVault.xcodeproj` (or open it from Xcode → *File → Open*).
2. Select the **WarrantyVault** scheme.
3. Choose an iOS 17+ simulator (e.g. iPhone 15).
4. Press **⌘R** to build and run.

## Face ID note
`Info.plist` values are set via build settings:
- `INFOPLIST_KEY_NSFaceIDUsageDescription = "Authenticate to securely access your warranty vault."`

The authentication screen calls `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)`. On the simulator, use **Features → Face ID → Matching Face** to test the success path.

## Folder layout
```
WarrantyVault/
├── App/
│   └── AppCoordinator.swift
├── DesignSystem/
│   ├── AppColors.swift
│   ├── AppTypography.swift
│   ├── GradientBackground.swift
│   ├── PrimaryButton.swift
│   ├── PageIndicator.swift
│   └── GlassCard.swift
├── Features/
│   ├── Splash/SplashView.swift
│   ├── Onboarding/
│   │   ├── OnboardingData.swift
│   │   ├── OnboardingIllustrationView.swift
│   │   ├── OnboardingPageView.swift
│   │   └── OnboardingContainerView.swift
│   └── Authentication/
│       ├── AuthenticationView.swift
│       └── MainAppPlaceholderView.swift
├── Assets.xcassets/  (AppIcon + AccentColor #0A84FF)
├── Preview Content/
└── WarrantyVaultApp.swift
```

## Main app flow (now wired up)
After the entry flow, `.mainApp` routes into `MainTabView`, a custom 5-tab shell (Home · Claims · Add · Family · Profile) with a floating blue Add button.

### Core screens
- **Dashboard** — warranty list with search, category chips, status summary tiles.
- **Warranty Detail** — coverage progress, timeline dates, receipt card, File Claim / Edit actions, delete confirmation.
- **Add / Edit Warranty** — category picker, date pickers, price, retailer, serial, notes, receipt toggle.

### Claim feature
- **Claims list** — all filed claims with status chips and updated-at labels.
- **File a Claim** — item picker, issue type grid, summary, description, photo attachments, receipt confirmation.
- **Status Timeline** — per-claim timeline with done/pending indicators, chat entry point.
- **Chat with Support** — bubble chat UI with composer, agent header, online status.

### Household feature
- **Create / Join** — onboarding for first-time users (segmented Create vs Join with invite code).
- **Household Hub** — stats header (members / items / open claims), Members and Activity segments.
- **Member Management** — roles, per-member menu (change role, remove), invite button.
- **Invite Member** — shareable invite code + email invite with role selection.
- **Activity Feed** — actor avatars and kind tags (added, updated, claimed, invited, expiring soon).

### Profile
- Account card, notifications and Face ID toggles, help / feedback / terms rows, Sign out (returns to auth stage).

## State
`AppStore` (`@Observable`) is the in-memory source of truth, seeded from `MockData`. Mutations live on the store:
- `addWarranty`, `updateWarranty`, `deleteWarranty`
- `addClaim`, `appendMessage`
- `addMember`, `removeMember`, `updateMemberRole`

Swap this for persistence (SwiftData / CoreData / API) later without touching views.

## Sample data
See `Models/MockData.swift` for 7 warranties, 3 claims, a 5-message chat, a 4-member household, and 5 activity entries.

