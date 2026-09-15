import SwiftUI
import UIKit

/// SwiftUI adapter; rendering and gestures live in the Telegram source port.
struct MainNavigationTelegram<Item: MainNavigationItem>: MainNavigationBar {
    let items: [Item]
    @Binding var selection: Item
    var contextActions: (Item) -> [MainNavigationAction] = { _ in [] }

    static var metrics: MainNavigationMetrics {
        MainNavigationMetrics(height: 64, sideInset: 12)
    }

    var body: some View {
        TelegramNavigationRepresentable(
            items: items,
            selection: $selection,
            contextActions: contextActions
        )
        .frame(maxWidth: 500)
        .frame(height: Self.metrics.height)
    }
}

private struct TelegramNavigationRepresentable<Item: MainNavigationItem>: UIViewRepresentable {
    let items: [Item]
    @Binding var selection: Item
    let contextActions: (Item) -> [MainNavigationAction]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> TelegramTabBarView {
        TelegramTabBarView(frame: .zero)
    }

    func updateUIView(_ view: TelegramTabBarView, context: Context) {
        let iconConfiguration = UIImage.SymbolConfiguration(pointSize: 27, weight: .regular)
        let menuIconConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        view.selectionChanged = { id in
            if let item = items.first(where: { AnyHashable($0) == id }) { selection = item }
        }
        view.update(
            items: items.map { item in
                TelegramTabBarItem(
                    id: AnyHashable(item),
                    title: String(localized: item.title),
                    image: UIImage(systemName: item.symbol, withConfiguration: iconConfiguration),
                    selectedImage: UIImage(systemName: item.selectedSymbol, withConfiguration: iconConfiguration),
                    contextActions: contextActions(item).map { action in
                        TelegramContextMenuAction(
                            id: action.id,
                            title: String(localized: action.title),
                            icon: UIImage(systemName: action.symbol, withConfiguration: menuIconConfiguration),
                            action: action.action
                        )
                    }
                )
            },
            selectedId: AnyHashable(selection),
            reduceMotion: reduceMotion
        )
    }
}
