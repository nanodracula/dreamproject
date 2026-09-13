import SwiftUI

/// The top-level destinations, in navigation order.
nonisolated enum AppDestination: CaseIterable, GlassNavigationItem {
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
