public import SwiftUI

// MARK: - Pill

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

    // MARK: Properties

    let label: String
    let systemImage: String?
    let value: Int

    #if !os(macOS) && !os(watchOS)
        @Environment(\.verticalSizeClass) private var verticalSizeClass
    #endif

    // MARK: Init

    /// Creates a pill.
    /// - Parameters:
    ///   - label: Caption shown above the value.
    ///   - systemImage: Optional SF Symbol shown alongside the caption.
    ///   - value: Integer displayed in the headline font.
    public init(label: String, systemImage: String? = nil, value: Int) {
        self.label = label
        self.systemImage = systemImage
        self.value = value
    }

    // MARK: Body

    public var body: some View {
        layout
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityIdentifier("Pill")
    }

    /// Caption above the value when there's room; caption and value side by side
    /// when vertical space is tight (e.g. iPhone landscape) to save height.
    @ViewBuilder
    private var layout: some View {
        if isHeightConstrained {
            HStack {
                caption
                Spacer()
                valueText
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                caption
                valueText
            }
        }
    }

    private var caption: some View {
        Group {
            if let systemImage {
                Label(label, systemImage: systemImage)
            } else {
                Text(label)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var valueText: some View {
        Text("\(value)")
            .font(.headline)
            .monospacedDigit()
    }

    /// Whether vertical space is scarce — drives the compact, single-line layout.
    private var isHeightConstrained: Bool {
        #if os(macOS) || os(watchOS)
            false
        #else
            verticalSizeClass == .compact
        #endif
    }
}

// MARK: - PillsView

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

    // MARK: Nested types

    /// A single labelled value to be shown by ``PillsView``.
    public struct Item: Identifiable {
        public let id = UUID()
        let label: String
        let systemImage: String?
        let value: Int

        /// Creates an item.
        /// - Parameters:
        ///   - label: Caption text for the pill.
        ///   - systemImage: Optional SF Symbol shown alongside the caption.
        ///   - value: Integer value shown by the pill.
        public init(label: String, systemImage: String? = nil, value: Int) {
            self.label = label
            self.systemImage = systemImage
            self.value = value
        }
    }

    // MARK: Properties

    let items: [Item]

    // MARK: Init

    /// Creates a `PillsView` from an explicit ``Item`` array.
    public init(items: [Item]) {
        self.items = items
    }

    /// Creates a `PillsView` from `(label, value)` tuples.
    public init(items: [(String, Int)]) {
        self.items = items.map { Item(label: $0.0, value: $0.1) }
    }

    // MARK: Helpers

    @ViewBuilder
    private func pillItems() -> some View {
        ForEach(items) { item in
            Pill(label: item.label, systemImage: item.systemImage, value: item.value)
        }
    }

    // MARK: Body

    public var body: some View {
        // A row when the width allows it, otherwise stacked.
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
}

// MARK: - Previews

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
