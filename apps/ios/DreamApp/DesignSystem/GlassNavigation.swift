import SwiftUI

/// A destination the `GlassNavigation` bar can show.
nonisolated protocol GlassNavigationItem: Hashable {
    var title: LocalizedStringResource { get }
    /// SF Symbol shown while the item is not selected.
    var symbol: String { get }
    /// SF Symbol shown while the item is selected.
    var selectedSymbol: String { get }
}

/// Layout values shared with the screen that positions the bar.
enum GlassNavigationMetrics {
    static let height: CGFloat = 58
    /// Horizontal distance from the screen edges.
    static let sideInset: CGFloat = 32
    /// Gap kept between content and the top of the bar.
    static let contentGap: CGFloat = 4
}

/// A floating Liquid Glass capsule with icon-only destinations. Selection is shown by a
/// translucent pill whose edges move on separate springs, so it stretches
/// toward the new destination and settles behind it.
struct GlassNavigation<Item: GlassNavigationItem>: View {
    let items: [Item]
    @Binding var selection: Item

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Pill edges in slot units: 0 is the leading edge of the first slot.
    @State private var pillStart: CGFloat
    @State private var pillEnd: CGFloat

    init(items: [Item], selection: Binding<Item>) {
        self.items = items
        _selection = selection
        let index = CGFloat(items.firstIndex(of: selection.wrappedValue) ?? 0)
        _pillStart = State(initialValue: index)
        _pillEnd = State(initialValue: index + 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let slotWidth = proxy.size.width / CGFloat(max(items.count, 1))
            ZStack(alignment: .leading) {
                pill(slotWidth: slotWidth)
                HStack(spacing: 0) {
                    ForEach(items, id: \.self) { item in
                        slot(for: item)
                    }
                }
            }
        }
        .frame(height: Layout.pillHeight)
        .padding(Layout.inset)
        .frame(height: GlassNavigationMetrics.height)
        .glassEffect(.regular, in: .capsule)
        .overlay {
            Capsule().strokeBorder(Palette.border, lineWidth: Layout.borderWidth)
        }
        .clipShape(Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Navigation"))
        .onChange(of: selection) { _, newValue in
            movePill(to: items.firstIndex(of: newValue) ?? 0)
        }
    }

    private func pill(slotWidth: CGFloat) -> some View {
        Capsule()
            .fill(Palette.pill)
            .frame(width: (pillEnd - pillStart) * slotWidth, height: Layout.pillHeight)
            .offset(x: pillStart * slotWidth)
            // Under Reduce Motion the pill crossfades between slots instead of sliding.
            .id(reduceMotion ? Int(pillStart) : 0)
            .transition(.opacity)
    }

    private func slot(for item: Item) -> some View {
        let isSelected = item == selection
        return Button {
            selection = item
        } label: {
            ZStack {
                Image(systemName: item.symbol)
                    .opacity(isSelected ? 0 : 1)
                Image(systemName: item.selectedSymbol)
                    .opacity(isSelected ? 1 : 0)
            }
            .font(.system(size: Layout.iconSize))
            .foregroundStyle(isSelected ? Palette.activeGlyph : Palette.inactiveGlyph)
            .animation(Motion.glyphCrossfade, value: isSelected)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(SlotButtonStyle(animation: reduceMotion ? nil : Motion.icon))
        .accessibilityLabel(Text(item.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func movePill(to index: Int) {
        let start = CGFloat(index)
        let end = start + 1
        if reduceMotion {
            withAnimation(Motion.reduced) {
                pillStart = start
                pillEnd = end
            }
            return
        }
        let movingForward = start > pillStart
        withAnimation(Motion.leadingEdge) {
            if movingForward { pillEnd = end } else { pillStart = start }
        }
        withAnimation(Motion.trailingEdge) {
            if movingForward { pillStart = start } else { pillEnd = end }
        }
    }
}

private enum Layout {
    static let padding: CGFloat = 6
    static let borderWidth: CGFloat = 1
    static let inset = padding + borderWidth
    static let pillHeight = GlassNavigationMetrics.height - inset * 2
    static let iconSize: CGFloat = 23
}

private enum Palette {
    static let border = Color.white.opacity(0.12)
    static let pill = Color.white.opacity(0.14)
    static let activeGlyph = Color(hex: 0xE9ECEF)
    static let inactiveGlyph = Color(hex: 0xB0B4BA)
}

private enum Motion {
    /// Pill edge racing ahead toward the new destination.
    static let leadingEdge = Animation.spring(Spring(mass: 0.7, stiffness: 400, damping: 30))
    /// Pill edge catching up.
    static let trailingEdge = Animation.spring(Spring(mass: 0.9, stiffness: 240, damping: 28))
    static let icon = Animation.spring(Spring(mass: 0.6, stiffness: 300, damping: 14))
    static let glyphCrossfade = Animation.easeInOut(duration: 0.2)
    static let reduced = Animation.easeInOut(duration: 0.2)
}

/// Lifts the glyph slightly while pressed; no motion when `animation` is nil.
private struct SlotButtonStyle: ButtonStyle {
    let animation: Animation?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && animation != nil ? 1.06 : 1)
            .animation(animation, value: configuration.isPressed)
    }
}

#Preview {
    nonisolated struct PreviewItem: GlassNavigationItem {
        let title: LocalizedStringResource
        let symbol: String
        let selectedSymbol: String

        static func == (lhs: Self, rhs: Self) -> Bool { lhs.symbol == rhs.symbol }
        func hash(into hasher: inout Hasher) { hasher.combine(symbol) }
    }
    struct Host: View {
        let items = [
            PreviewItem(title: "One", symbol: "books.vertical", selectedSymbol: "books.vertical.fill"),
            PreviewItem(title: "Two", symbol: "rectangle.stack", selectedSymbol: "rectangle.stack.fill"),
            PreviewItem(title: "Three", symbol: "plus.circle", selectedSymbol: "plus.circle.fill"),
        ]
        @State private var selection: PreviewItem
        init() { _selection = State(initialValue: items[0]) }
        var body: some View {
            GlassNavigation(items: items, selection: $selection)
                .padding(.horizontal, GlassNavigationMetrics.sideInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .background(AppColors.background)
        }
    }
    return Host().preferredColorScheme(.dark)
}
