import SwiftUI

struct FilterPanel: View {
    @Environment(SearchViewModel.self) private var searchVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
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
            .background(Color.appBackground)
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if searchVM.activeFilterCount > 0 {
                        Button("Nullstill") {
                            searchVM.clearFilters()
                        }
                        .font(.buttonText)
                        .foregroundStyle(Color.appAccent)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ferdig") {
                        dismiss()
                    }
                    .font(.buttonText)
                    .foregroundStyle(Color.appAccent)
                }
            }
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
