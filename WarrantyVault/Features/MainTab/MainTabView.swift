import SwiftUI

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @State private var presentingAdd = false
    @State private var presentingFileClaim = false

    var body: some View {
        @Bindable var store = store

        ZStack {
            GradientBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch store.selectedTab {
                    case .dashboard:
                        NavigationStack { DashboardView() }
                    case .claims:
                        NavigationStack { ClaimsListView(presentingFileClaim: $presentingFileClaim) }
                    case .add:
                        EmptyView()
                    case .household:
                        HouseholdHubView()
                    case .profile:
                        NavigationStack { ProfileView() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                BottomNavBar(
                    selected: $store.selectedTab,
                    onAddTapped: { presentingAdd = true }
                )
            }
        }
        .sheet(isPresented: $presentingAdd) {
            NavigationStack { AddWarrantyView() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $presentingFileClaim) {
            NavigationStack { FileClaimView() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Bottom navigation

struct BottomNavBar: View {
    @Binding var selected: MainTab
    var onAddTapped: () -> Void

    private let addSize: CGFloat = 56

    var body: some View {
        HStack(spacing: 0) {
            navItem(.dashboard, symbol: "square.grid.2x2", filledSymbol: "square.grid.2x2.fill", title: "Home")
            navItem(.claims,    symbol: "doc.text.magnifyingglass", filledSymbol: "doc.text.magnifyingglass", title: "Claims")

            // Invisible spacer reserves width for the floating + button
            Color.clear
                .frame(width: addSize + 12, height: 1)

            navItem(.household, symbol: "person.2", filledSymbol: "person.2.fill", title: "Family")
            navItem(.profile,   symbol: "person.crop.circle", filledSymbol: "person.crop.circle.fill", title: "Profile")
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            AppColors.bgSurface
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            addButton
                .offset(y: -(addSize / 2))
        }
    }

    @ViewBuilder
    private func navItem(_ tab: MainTab, symbol: String, filledSymbol: String, title: String) -> some View {
        let isSelected = selected == tab

        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selected = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? filledSymbol : symbol)
                    .font(.system(size: 19, weight: isSelected ? .semibold : .medium))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.2)
            }
            .foregroundStyle(isSelected ? AppColors.accent : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        // Make this look like a tab to VoiceOver and announce its state.
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "" : "Double-tap to switch to \(title) tab")
    }

    /// Floating circular CTA. Lime fill, black plus icon. Wrapped in a
    /// 3pt black ring so it reads as a separate "lozenge" against the
    /// dark grey tab bar.
    private var addButton: some View {
        Button(action: onAddTapped) {
            Circle()
                .fill(AppColors.accent)
                .frame(width: addSize, height: addSize)
                .overlay(
                    Circle().stroke(AppColors.bgApp, lineWidth: 3)
                )
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.textInverse)
                )
        }
        .buttonStyle(.plain)
        // The visible content is just a "+" — VoiceOver can't infer "Add new
        // warranty" from that. Provide an explicit label.
        .accessibilityLabel("Add new warranty")
        .accessibilityHint("Double-tap to open the warranty creation form")
    }
}
