public import SwiftUI

/// A small SwiftUI badge displaying a caption above an integer value.
///
/// `Pill` is a compact summary tile.  The label appears in the caption font as
/// secondary text, and the value below it in the headline font with monospaced
/// digits.  The whole thing sits on a rounded rectangle background tinted with
/// the secondary colour at 10 % opacity.
///
/// Use ``PillsView`` to lay out a collection of pills that adapt to the
/// available horizontal space.
///
/// ```swift
/// Pill(label: "Bedrooms", value: 3)
/// ```
public struct Pill: View {
    let label: String
    let value: Int

    /// Creates a pill.
    /// - Parameters:
    ///   - label: Caption shown above the value.
    ///   - value: Integer displayed in the headline font.
    public init(label: String, value: Int) {
        self.label = label
        self.value = value
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.headline)
                .monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityIdentifier("Pill")
    }
}

/// A SwiftUI container that arranges a list of ``Pill`` views horizontally
/// when the available width allows it, otherwise stacks them vertically.
///
/// The layout uses `ViewThatFits(in: .horizontal)`: the horizontal `HStack`
/// branch is tried first, and SwiftUI falls back to a `VStack` when the
/// content does not fit.
///
/// ```swift
/// PillsView(items: [("Home", 12), ("Bathroom", 2), ("Bedroom", 3)])
/// ```
public struct PillsView: View {
    /// A single labelled value to be shown by ``PillsView``.
    public struct Item: Identifiable {
        public let id = UUID()
        let label: String
        let value: Int

        /// Creates an item.
        /// - Parameters:
        ///   - label: Caption text for the pill.
        ///   - value: Integer value shown by the pill.
        public init(label: String, value: Int) {
            self.label = label
            self.value = value
        }
    }

    let items: [Item]

    /// Creates a `PillsView` from an explicit ``Item`` array.
    public init(items: [Item]) {
        self.items = items
    }

    /// Creates a `PillsView` from `(label, value)` tuples.
    public init(items: [(String, Int)]) {
        self.items = items.map { Item(label: $0.0, value: $0.1) }
    }

    @ViewBuilder
    private func pillItems() -> some View {
        ForEach(items) { item in
            Pill(label: item.label, value: item.value)
        }
    }

    #if false
        public var body: some View {
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    AnyLayout(
                        proxy.size.height > proxy.size.width
                            ? AnyLayout(VStackLayout(alignment: .leading))
                            : AnyLayout(HStackLayout())
                    ) {
                        pillItems()
                    }
                }
            }
        }
    #else
        public var body: some View {
            ViewThatFits(in: .horizontal) {
                HStack {
                    pillItems()
                }
                VStack(alignment: .leading) {
                    pillItems()
                }
            }
            .accessibilityIdentifier("PillsView")
        }
    #endif
}

#Preview("Pill") {
    Pill(label: "Bedroom", value: Int.random(in: 1 ... 30))
        .padding()
}

#Preview("Pills") {
    PillsView(items: [
        .init(label: "Home", value: Int.random(in: 1 ... 30)),
        .init(label: "Bathroom", value: Int.random(in: 1 ... 30)),
        .init(label: "Bedroom", value: Int.random(in: 1 ... 30)),
    ])
    .padding()
}

#Preview("Pills (Constrained)") {
    PillsView(items: [
        ("Home", (1 ... 30).randomElement()!),
        ("Bathroom", (1 ... 30).randomElement()!),
        ("Bedroom", (1 ... 30).randomElement()!),
    ])
    .padding()
    .frame(width: 200)
}
