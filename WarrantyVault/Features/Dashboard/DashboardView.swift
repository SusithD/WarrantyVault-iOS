import SwiftUI

struct DashboardView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                summaryStrip
                searchField
                categoryChips

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Your warranties")
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text("\(store.filteredWarranties.count) ITEMS")
                            .font(AppTypography.mono)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    if store.filteredWarranties.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(store.filteredWarranties) { w in
                                NavigationLink(value: w) {
                                    WarrantyRow(warranty: w)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .top, spacing: 0) { navBar }
        .navigationDestination(for: Warranty.self) { w in
            WarrantyDetailView(warrantyID: w.id)
        }
    }

    // MARK: Subviews

    private var navBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Good morning")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text("WarrantyVault")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(-0.2)
            }
            Spacer()
            Button {
                // placeholder notifications
            } label: {
                IconBadge(
                    symbol: "bell",
                    tint: AppColors.textPrimary,
                    style: .outline,
                    size: .medium
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            GradientBackground().ignoresSafeArea(edges: .top)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back")
                .overlineStyle(color: AppColors.brandBlue)
            Text("Your coverage,\nat a glance.")
                .font(AppTypography.title)
                .tracking(-0.4)
                .foregroundStyle(AppColors.textPrimary)
                .lineSpacing(2)
        }
        .padding(.top, 8)
    }

    private var summaryStrip: some View {
        HStack(spacing: 10) {
            summaryTile(
                title: "Active",
                count: store.activeCount,
                tint: AppColors.success,
                symbol: "checkmark"
            )
            summaryTile(
                title: "Expiring",
                count: store.expiringSoonCount,
                tint: AppColors.warning,
                symbol: "clock"
            )
            summaryTile(
                title: "Open Claims",
                count: store.openClaimsCount,
                tint: AppColors.brandBlue,
                symbol: "doc.text"
            )
        }
    }

    private func summaryTile(title: String, count: Int, tint: Color, symbol: String) -> some View {
        GlassCard(padding: 14, cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 14) {
                IconBadge(symbol: symbol, tint: tint, style: .soft, size: .small)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(-0.6)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(title.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var searchField: some View {
        @Bindable var store = store
        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
            TextField(
                "",
                text: $store.searchText,
                prompt: Text("Search by product, brand, retailer")
                    .foregroundColor(AppColors.textTertiary)
            )
            .font(AppTypography.body)
            .foregroundStyle(AppColors.textPrimary)
            if !store.searchText.isEmpty {
                Button { store.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.surfaceMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private var categoryChips: some View {
        @Bindable var store = store
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(title: "All", isSelected: store.categoryFilter == nil) {
                    store.categoryFilter = nil
                }
                ForEach(WarrantyCategory.allCases) { cat in
                    chip(title: cat.rawValue, isSelected: store.categoryFilter == cat) {
                        store.categoryFilter = (store.categoryFilter == cat) ? nil : cat
                    }
                }
            }
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.chip)
                .foregroundStyle(isSelected ? AppColors.textInverse : AppColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? AppColors.accent : AppColors.bgSurfaceHi)
                )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 10) {
                IconBadge(symbol: "tray", tint: AppColors.textTertiary, style: .outline, size: .medium)
                Text("Nothing matches those filters")
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Try a different search or clear the category filter.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Row

struct WarrantyRow: View {
    let warranty: Warranty

    var body: some View {
        GlassCard(padding: 14, cornerRadius: 14) {
            HStack(spacing: 12) {
                IconBadge(
                    symbol: warranty.category.symbolName,
                    tint: warranty.category.tint,
                    style: .soft,
                    size: .medium
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(warranty.productName)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(warranty.brand)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Text("·")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                        Text(warranty.category.rawValue)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .lineLimit(1)
                    StatusTag(status: warranty.status, daysRemaining: warranty.daysRemaining)
                        .padding(.top, 1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .environment(AppStore())
    }
}
