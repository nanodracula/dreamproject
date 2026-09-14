import SwiftUI

/// The top-level destinations, in navigation order.
nonisolated private enum AppDestination: CaseIterable, MainNavigationItem {
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
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppSettingsModel.self) private var settings
    @State private var selectedDestination: AppDestination = .dictionary

    var body: some View {
        ScreenTransitionView(items: AppDestination.allCases, selection: selectedDestination) { destination in
            NavigationStack {
                if destination == .settings {
                    SettingsView()
                } else {
                    PlaceholderView(destination: destination)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: MainNavigationMetrics.contentGap) {
                Color.clear.frame(height: MainNavigationMetrics.height)
            }
            .environment(dependencies)
            .environment(settings)
        }
        // UIKit owns the screen's safe areas. The bar overlays it, while each
        // hosted screen reserves scrolling space without clipping its background.
        .ignoresSafeArea(.container)
        .overlay(alignment: .bottom) {
            MainNavigation(items: AppDestination.allCases, selection: $selectedDestination)
                .padding(.horizontal, MainNavigationMetrics.sideInset)
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
