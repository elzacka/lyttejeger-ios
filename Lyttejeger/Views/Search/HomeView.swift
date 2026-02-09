import SwiftUI

struct HomeView: View {
    @Environment(SearchViewModel.self) private var searchVM
    @State private var showFilters = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        @Bindable var vm = searchVM

        VStack(spacing: 0) {
            // Search + tabs toolbar
            VStack(spacing: AppSpacing.md) {
                // Search field — warm, understated, belongs to the beige world
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.appAccent.opacity(0.6))
                        .font(.system(size: 16))

                    TextField(vm.activeTab == .podcasts ? "Søk etter podkaster..." : "Søk etter episoder...", text: Binding(
                        get: { searchVM.filters.query },
                        set: { searchVM.setQuery($0) }
                    ))
                    .font(.bodyText)
                    .foregroundStyle(Color.appForeground)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                    if !searchVM.filters.query.isEmpty {
                        Button {
                            searchVM.setQuery("")
                            isSearchFocused = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.appBorder)
                        }
                        .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    }

                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: searchVM.activeFilterCount > 0
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(searchVM.activeFilterCount > 0 ? Color.appAccent : Color.appAccent.opacity(0.6))
                    }
                    .frame(minWidth: AppSize.touchTarget, minHeight: AppSize.touchTarget)
                    .accessibilityLabel(searchVM.activeFilterCount > 0 ? "Filter, \(searchVM.activeFilterCount) aktive" : "Filter")
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 44)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.appBorder.opacity(0.4))
                        .frame(height: 1)
                }

                // Tab switcher
                HStack(spacing: 0) {
                    ForEach(SearchViewModel.SearchTab.allCases, id: \.self) { tab in
                        Button {
                            if UIAccessibility.isReduceMotionEnabled {
                                vm.activeTab = tab
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    vm.activeTab = tab
                                }
                            }
                        } label: {
                            Text(tab == .podcasts ? "Podkaster" : "Episoder")
                                .font(.buttonText)
                                .foregroundStyle(vm.activeTab == tab ? Color.appAccent : Color.appMutedForeground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.xs)
                        }
                        .accessibilityAddTraits(vm.activeTab == tab ? .isSelected : [])
                    }
                }
                .overlay(alignment: .bottom) {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.appAccent)
                            .frame(width: geo.size.width / 2, height: 2)
                            .offset(x: vm.activeTab == .podcasts ? 0 : geo.size.width / 2)
                            .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeOut(duration: 0.2), value: vm.activeTab)
                    }
                    .frame(height: 2)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)

            // Results
            if !searchVM.isLoading && searchVM.error == nil && searchVM.filters.query.isEmpty && searchVM.podcasts.isEmpty && !searchVM.hasActiveFilters {
                Spacer()

                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "headphones")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Color.appBorder)

                    Text("Finn din neste favoritt")
                        .font(.bodyText)
                        .foregroundStyle(Color.appMutedForeground)
                }

                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        if searchVM.isLoading {
                            ProgressView()
                                .tint(Color.appAccent)
                                .padding(.top, AppSpacing.xxxl)
                        } else if let error = searchVM.error {
                            Text(error)
                                .font(.bodyText)
                                .foregroundStyle(Color.appError)
                                .padding(.top, AppSpacing.xxxl)
                        } else if searchVM.activeTab == .podcasts {
                            if searchVM.podcasts.isEmpty && !searchVM.filters.query.isEmpty {
                                NoResultsView()
                            } else {
                                ForEach(searchVM.podcasts) { podcast in
                                    NavigationLink(value: podcast) {
                                        PodcastCard(podcast: podcast)
                                    }
                                    .buttonStyle(CardButtonStyle())
                                }
                            }
                        } else {
                            if searchVM.episodes.isEmpty && !searchVM.filters.query.isEmpty {
                                NoResultsView()
                            } else {
                                ForEach(searchVM.episodes) { episodeWithPodcast in
                                    EpisodeCard(
                                        episode: episodeWithPodcast.episode,
                                        podcastTitle: episodeWithPodcast.podcastTitle,
                                        podcastImage: episodeWithPodcast.podcastImage
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showFilters) {
            FilterPanel()
        }
        .navigationDestination(for: Podcast.self) { podcast in
            PodcastDetailView(podcast: podcast)
        }
    }
}

// MARK: - No Results

private struct NoResultsView: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.appBorder)

            Text("Ingen resultater")
                .font(.bodyText)
                .foregroundStyle(Color.appMutedForeground)
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview("Søkeresultater") {
    PreviewWrapper(searchResults: true) {
        NavigationStack {
            HomeView()
        }
    }
}

#Preview("Oppdaging") {
    PreviewWrapper {
        NavigationStack {
            HomeView()
        }
    }
}
#endif
