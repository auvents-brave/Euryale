public import SwiftUI

// MARK: - TipEntry

/// A single entry in a ``RollingTipView``.
///
/// Pairs a visibility binding with the view to display when this entry is chosen.
public struct TipEntry {
    let isVisible: Binding<Bool>
    let view: AnyView

    /// - Parameters:
    ///   - isVisible: Binding that controls whether this entry is eligible to be shown.
    ///     When the entry dismisses itself it sets this binding to `false`.
    ///   - content: The view to display when this entry is the chosen one.
    public init<V: View>(
        isVisible: Binding<Bool>,
        @ViewBuilder content: () -> V
    ) {
        self.isVisible = isVisible
        self.view = AnyView(content())
    }
}

// MARK: - RollingTipView

/// Displays one randomly chosen tip from a list, rotating to a new one
/// whenever the current tip is dismissed.
///
/// Provide a list of ``TipEntry`` values; the view picks one at random from
/// those whose `isVisible` binding is `true` and shows it.  When the shown
/// tip sets its binding to `false` (typically via a dismiss button),
/// `RollingTipView` automatically picks a replacement from the remaining
/// visible entries.
///
/// ```swift
/// RollingTipView([
///     .init(isVisible: $showFirstTip)  { FirstTipView(isVisible: $showFirstTip) },
///     .init(isVisible: $showSecondTip) { SecondTipView(isVisible: $showSecondTip) },
/// ])
/// ```
public struct RollingTipView: View {
    private let entries: [TipEntry]
    @State private var selectedIndex: Int?

    public init(_ entries: [TipEntry]) {
        self.entries = entries
    }

    private var visibleIndices: [Int] {
        entries.indices.filter { entries[$0].isVisible.wrappedValue }
    }

    public var body: some View {
        Group {
            if let idx = selectedIndex,
               idx < entries.count,
               entries[idx].isVisible.wrappedValue {
                entries[idx].view
            }
        }
        .onAppear(perform: pickIfNeeded)
        .onChange(of: entries.map { $0.isVisible.wrappedValue }) { _, newValues in
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
