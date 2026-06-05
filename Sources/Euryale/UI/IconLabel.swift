public import SwiftUI

// MARK: - IconLabel

/// A compact horizontal pairing of an SF Symbol and a text title.
///
/// `IconLabel` exists for the places where SwiftUI's own `Label` won't render
/// its icon — most notably inside a **segmented `Picker` on macOS**, which drops
/// a `Label`'s glyph and shows the title only. Because `IconLabel` is a plain
/// `HStack` of an `Image` and a `Text`, both always appear, so it can stand in
/// for `Label` as a picker segment or in any custom control (a button row, a
/// chip, a toolbar item).
///
/// The title is a `LocalizedStringKey`, so string literals are localised from
/// the String Catalog automatically.
///
/// ```swift
/// Picker("Filter", selection: $filter) {
///     ForEach(Filter.allCases) { filter in
///         IconLabel(filter.title, systemImage: filter.systemImage).tag(filter)
///     }
/// }
/// .pickerStyle(.segmented)
/// ```
public struct IconLabel: View {

    // MARK: Properties

    private let title: Text
    private let systemImage: String
    private let spacing: CGFloat

    // MARK: Initialisers

    /// Creates an icon-and-text label from a localised title key.
    /// - Parameters:
    ///   - titleKey: The title, localised from the String Catalog when it is a literal.
    ///   - systemImage: The SF Symbol name shown before the title.
    ///   - spacing: The gap between the icon and the title. Defaults to `4`.
    public init(_ titleKey: LocalizedStringKey, systemImage: String, spacing: CGFloat = 4) {
        title = Text(titleKey)
        self.systemImage = systemImage
        self.spacing = spacing
    }

    /// Creates an icon-and-text label from a plain string (shown verbatim, not
    /// re-localised — use this for values already resolved with `String(localized:)`).
    /// - Parameters:
    ///   - title: The title string, displayed as-is.
    ///   - systemImage: The SF Symbol name shown before the title.
    ///   - spacing: The gap between the icon and the title. Defaults to `4`.
    public init(_ title: some StringProtocol, systemImage: String, spacing: CGFloat = 4) {
        self.title = Text(title)
        self.systemImage = systemImage
        self.spacing = spacing
    }

    // MARK: Body

    public var body: some View {
        HStack(spacing: spacing) {
            Image(systemName: systemImage)
            title
        }
    }
}

// MARK: - Previews

#Preview("Standalone") {
    VStack(alignment: .leading, spacing: 12) {
        IconLabel("Marks", systemImage: "mappin.and.ellipse")
        IconLabel("Routes", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
        IconLabel("Traces", systemImage: "scribble.variable")
    }
    .padding()
}

// The segmented picker style is unavailable on watchOS and tvOS.
#if !os(watchOS) && !os(tvOS)
#Preview("In a segmented Picker") {
    enum Filter: String, CaseIterable, Identifiable {
        case all, marks, routes
        var id: String { rawValue }
        var title: LocalizedStringKey { LocalizedStringKey(rawValue.capitalized) }
        var systemImage: String {
            switch self {
            case .all: "square.grid.2x2"
            case .marks: "mappin.and.ellipse"
            case .routes: "point.topleft.down.to.point.bottomright.curvepath"
            }
        }
    }
    struct PickerPreview: View {
        @State private var filter: Filter = .all
        var body: some View {
            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { filter in
                    IconLabel(filter.title, systemImage: filter.systemImage).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()
        }
    }
    return PickerPreview()
}
#endif
