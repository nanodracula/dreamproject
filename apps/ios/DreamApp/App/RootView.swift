import SwiftUI

/// Hosts the destinations behind the floating glass navigation. Every
/// destination keeps its own `NavigationStack` and stays alive while hidden,
/// so switching back restores its state.
struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var selectedDestination: AppDestination = .dictionary

    var body: some View {
        GeometryReader { proxy in
            let safeAreaBottom = proxy.safeAreaInsets.bottom
            ZStack {
                ForEach(AppDestination.allCases, id: \.self) { destination in
                    let isSelected = destination == selectedDestination
                    NavigationStack {
                        PlaceholderScreen(destination: destination)
                    }
                    .zIndex(isSelected ? 1 : 0)
                    .allowsHitTesting(isSelected)
                    .accessibilityHidden(!isSelected)
                }
            }
            .safeAreaPadding(.bottom, GlassNavigationMetrics.contentInset(safeAreaBottom: safeAreaBottom))
            .overlay(alignment: .bottom) {
                GlassNavigation(items: AppDestination.allCases, selection: $selectedDestination)
                    .padding(.horizontal, GlassNavigationMetrics.sideInset)
                    .padding(.bottom, GlassNavigationMetrics.bottomOffset(safeAreaBottom: safeAreaBottom) - safeAreaBottom)
            }
        }
        .background(AppColors.background)
        .preferredColorScheme(.dark)
    }
}

/// Stands in for a feature screen until it is implemented.
private struct PlaceholderScreen: View {
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
        .environment(AppDependencies(database: try! AppDatabase.openInMemory()))
}
