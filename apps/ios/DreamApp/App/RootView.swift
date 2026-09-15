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
    @State private var settingsPath: [SettingsRoute] = []

    private var navigationMetrics: MainNavigationMetrics {
        MainNavigation<AppDestination>.metrics
    }

    var body: some View {
        ScreenTransitionView(items: AppDestination.allCases, selection: selectedDestination) { destination in
            Group {
                if destination == .settings {
                    NavigationStack(path: $settingsPath) {
                        SettingsView()
                    }
                } else {
                    NavigationStack {
                        PlaceholderView(destination: destination)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: navigationMetrics.contentGap) {
                Color.clear.frame(height: navigationMetrics.height)
            }
            .environment(dependencies)
            .environment(settings)
        }
        // UIKit owns the screen's safe areas. The bar overlays it, while each
        // hosted screen reserves scrolling space without clipping its background.
        .ignoresSafeArea(.container)
        .overlay(alignment: .bottom) {
            MainNavigation(
                items: AppDestination.allCases,
                selection: $selectedDestination,
                contextActions: contextActions
            )
            .padding(.horizontal, navigationMetrics.sideInset)
        }
        .background(AppColors.background)
    }

    private func contextActions(for destination: AppDestination) -> [MainNavigationAction] {
        guard destination == .settings else { return [] }
        return [
            MainNavigationAction(
                id: "general",
                title: LocalizedStringResource("itemsGeneral", table: "Settings"),
                symbol: "gearshape"
            ) {
                openSettings(.general)
            },
            MainNavigationAction(
                id: "languages",
                title: LocalizedStringResource("languagesTitle", table: "Settings"),
                symbol: "globe"
            ) {
                openSettings(.languages)
            },
            MainNavigationAction(
                id: "interface",
                title: LocalizedStringResource("itemsInterface", table: "Settings"),
                symbol: "paintbrush"
            ) {
                openSettings(.interface)
            },
        ]
    }

    private func openSettings(_ route: SettingsRoute) {
        selectedDestination = .settings
        settingsPath = [route]
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
