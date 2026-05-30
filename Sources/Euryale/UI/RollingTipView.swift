public import SwiftUI

/// Displays one randomly chosen Siri tip from a list, rotating to a new one
/// whenever the current tip is dismissed.
///
/// Provide ``SiriTipItem`` values — each wraps an intent and a visibility binding.
/// `RollingTipView` picks one at random from those currently visible and shows it.
/// When the user dismisses the shown tip, a new one is automatically chosen.
///
/// ```swift
/// RollingTipView(
///     .init(intent: CountFurnitureIntent(), isVisible: $showFurnitureTip),
///     .init(intent: CountThingsIntent(),    isVisible: $showThingsTip)
/// )
/// ```
public struct RollingTipView: View {
    private let items: [SiriTipItem]
    @State private var selectedIndex: Int?

    /// Variadic initialiser — pass items as individual arguments.
    public init(_ items: SiriTipItem...) {
        self.items = items
    }

    /// Array initialiser.
    public init(_ items: [SiriTipItem]) {
        self.items = items
    }

    private var visibleIndices: [Int] {
        items.indices.filter { items[$0].isVisible.wrappedValue }
    }

    public var body: some View {
        Group {
            if let idx = selectedIndex,
               idx < items.count,
               items[idx].isVisible.wrappedValue {
                items[idx].view
            }
        }
        .onAppear(perform: pickIfNeeded)
        .onChange(of: items.map { $0.isVisible.wrappedValue }) { _, newValues in
            guard let idx = selectedIndex,
                  idx < newValues.count,
                  !newValues[idx] else { return }
            pickIfNeeded()
        }
    }

    private func pickIfNeeded() {
        selectedIndex = visibleIndices.randomElement()
    }
}
