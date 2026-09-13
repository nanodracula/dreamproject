import SwiftUI

/// The top-level destinations, in navigation order.
nonisolated private enum AppDestination: CaseIterable, GlassNavigationItem {
    case dictionary
    case feed
    case add
    case player
    case settings

    var title: LocalizedStringResource {
        switch self {
        case .dictionary: "Dictionary"
        case .feed: "Feed"
        case .add: "Add"
        case .player: "Player"
        case .settings: LocalizedStringResource("title", table: "Settings")
        }
    }

    var symbol: String {
        switch self {
        case .dictionary: "books.vertical"
        case .feed: "rectangle.stack"
        case .add: "plus.circle"
        case .player: "play.circle"
        case .settings: "gearshape"
        }
    }

    var selectedSymbol: String {
        symbol + ".fill"
    }
}

/// Hosts a navigation stack per tab, with a custom glass bar in the bottom safe area.
struct RootView: View {
    @State private var selectedDestination: AppDestination = .dictionary

    var body: some View {
        TabView(selection: $selectedDestination) {
            ForEach(AppDestination.allCases, id: \.self) { destination in
                Tab(value: destination) {
                    NavigationStack {
                        if destination == .settings {
                            SettingsView()
                        } else {
                            PlaceholderView(destination: destination)
                        }
                    }
                    .toolbarVisibility(.hidden, for: .tabBar)
                } label: {
                    Label {
                        Text(destination.title)
                    } icon: {
                        Image(systemName: destination.symbol)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: GlassNavigationMetrics.contentGap) {
            GlassNavigation(items: AppDestination.allCases, selection: $selectedDestination)
                .padding(.horizontal, GlassNavigationMetrics.sideInset)
        }
        .background(AppColors.background)
    }
}

/// Stands in for a feature screen until it is implemented.
private struct PlaceholderView: View {
    let destination: AppDestination

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: destination.selectedSymbol)
                .font(.system(size: 48))
                .foregroundStyle(AppColors.textSecondary)
            Text(destination.title)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(AppColors.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .navigationTitle(Text(destination.title))
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

#Preview {
    RootView()
        .previewDependencies()
}
