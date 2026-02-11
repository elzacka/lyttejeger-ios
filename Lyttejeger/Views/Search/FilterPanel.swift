import SwiftUI

struct FilterPanel: View {
    @Environment(SearchViewModel.self) private var searchVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if searchVM.activeFilterCount > 0 {
                    Button("Nullstill") { searchVM.clearFilters() }
                        .font(.buttonText)
                        .foregroundStyle(Color.appAccent)
                        .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                } else {
                    Spacer()
                        .frame(width: AppSize.touchTarget)
                }

                Spacer()

                Text("Filter")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.appForeground)

                Spacer()

                Button("Ferdig") { dismiss() }
                    .font(.buttonText)
                    .foregroundStyle(Color.appAccent)
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    // Active filters summary
                    if searchVM.activeFilterCount > 0 {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Aktive filter")
                                .font(.caption2Text)
                                .foregroundStyle(Color.appMutedForeground)
                                .textCase(.uppercase)

                            FlowLayout(spacing: AppSpacing.sm) {
                                ForEach(searchVM.filters.languages.sorted(), id: \.self) { lang in
                                    activeChip(lang) { searchVM.toggleLanguage(lang) }
                                }
                                ForEach(searchVM.filters.categories.sorted(), id: \.self) { cat in
                                    activeChip(translateCategory(cat)) { searchVM.toggleCategory(cat) }
                                }
                                if searchVM.filters.sortBy != .relevance {
                                    activeChip(searchVM.filters.sortBy.label) { searchVM.setSortBy(.relevance) }
                                }
                                if let duration = searchVM.filters.durationFilter {
                                    activeChip(duration.label) { searchVM.setDurationFilter(nil) }
                                }
                                if searchVM.filters.dateFrom != nil || searchVM.filters.dateTo != nil {
                                    activeChip("Datofilter") {
                                        searchVM.setDateFrom(nil)
                                        searchVM.setDateTo(nil)
                                    }
                                }
                            }
                        }
                    }

                    // Languages
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Språk")
                            .font(.sectionTitle)
                            .foregroundStyle(Color.appForeground)

                        FlowLayout(spacing: AppSpacing.sm) {
                            ForEach(allLanguages, id: \.self) { language in
                                FilterChip(
                                    label: language,
                                    isSelected: searchVM.filters.languages.contains(language)
                                ) {
                                    searchVM.toggleLanguage(language)
                                }
                            }
                        }
                    }

                    // Sort
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Sorter")
                            .font(.sectionTitle)
                            .foregroundStyle(Color.appForeground)

                        Picker("Sorter", selection: Binding(
                            get: { searchVM.filters.sortBy },
                            set: { searchVM.setSortBy($0) }
                        )) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Duration (episode search only)
                    if searchVM.activeTab == .episodes {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Varighet")
                                .font(.sectionTitle)
                                .foregroundStyle(Color.appForeground)

                            FlowLayout(spacing: AppSpacing.sm) {
                                ForEach(DurationFilter.allCases, id: \.self) { duration in
                                    FilterChip(
                                        label: duration.label,
                                        isSelected: searchVM.filters.durationFilter == duration
                                    ) {
                                        searchVM.toggleDurationFilter(duration)
                                    }
                                }
                            }
                        }
                    }

                    // Categories
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Kategorier")
                            .font(.sectionTitle)
                            .foregroundStyle(Color.appForeground)

                        FlowLayout(spacing: AppSpacing.sm) {
                            ForEach(allCategories) { category in
                                FilterChip(
                                    label: category.label,
                                    isSelected: searchVM.filters.categories.contains(category.value)
                                ) {
                                    searchVM.toggleCategory(category.value)
                                }
                            }
                        }
                    }
                }
                .padding(AppSpacing.lg)
            }
        }
        .background(Color.appBackground)
    }

    private func activeChip(_ label: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack(spacing: AppSpacing.xs) {
                Text(label)
                    .font(.badgeText)
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.appAccent)
            .clipShape(.rect(cornerRadius: AppRadius.full))
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.badgeText)
                .foregroundStyle(isSelected ? .white : Color.appForeground)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(isSelected ? Color.appAccent : Color.appMuted)
                .clipShape(.rect(cornerRadius: AppRadius.full))
        }
        .frame(minHeight: AppSize.touchTarget)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#if DEBUG
#Preview {
    PreviewWrapper {
        FilterPanel()
    }
}
#endif
