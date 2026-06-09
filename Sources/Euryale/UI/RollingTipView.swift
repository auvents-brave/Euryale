public import SwiftUI

// MARK: - RollingTipView

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
  @State private var order: [Int] = []

  /// Variadic initialiser — pass items as individual arguments.
  public init(_ items: SiriTipItem...) {
    self.items = items
  }

  /// Array initialiser.
  public init(_ items: [SiriTipItem]) {
    self.items = items
  }

  public var body: some View {
    // Siri tips have no surface on tvOS/watchOS — present but inert there,
    // so call sites stay platform-agnostic (same idea as the other shims).
    #if os(tvOS) || os(watchOS)
      EmptyView()
    #else
      Group {
        if let index = shownIndex {
          items[index].view
        }
      }
      .onAppear {
        if order.count != items.count {
          order = Array(items.indices).shuffled()
        }
      }
    #endif
  }

  /// The first still-visible tip, in a stable randomised order.
  ///
  /// Derived on every render rather than stored, so it reacts immediately to
  /// visibility changes: dismissing a tip rolls to the next visible one, and
  /// resetting brings one back — no stale selection to get stuck on.
  private var shownIndex: Int? {
    let sequence = order.count == items.count ? order : Array(items.indices)
    return sequence.first { items[$0].isVisible.wrappedValue }
  }
}
