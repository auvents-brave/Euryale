public import SwiftUI

// MARK: - IconLabel

/// A compact horizontal pairing of an SF Symbol and a text title.
///
/// `IconLabel` is just an `HStack` of an `Image` and a `Text`, so **both always
/// appear** — useful as a `Picker` row, a button, a chip or any custom control
/// where you want the glyph guaranteed beside the title (some menus and `Picker`
/// styles render only a `Label`'s text and drop its icon).
///
/// > Note: it does *not* help inside a `.segmented` `Picker` — a segmented
/// > control shows one `Text` *or* one `Image` per segment, never a composed
/// > view. For an icon + label segmented control, use ``IconSegmentedControl``.
///
/// The title is a `LocalizedStringKey`, so string literals are localised from
/// the String Catalog automatically.
///
/// ```swift
/// Picker("Kind", selection: $kind) {
///     ForEach(Kind.allCases) { kind in
///         IconLabel(kind.title, systemImage: kind.systemImage).tag(kind)
///     }
/// }
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

#if DEBUG
  #Preview("Standalone") {
    VStack(alignment: .leading, spacing: 12) {
      IconLabel("Marks", systemImage: "mappin.and.ellipse")
      IconLabel("Routes", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
      IconLabel("Traces", systemImage: "scribble.variable")
    }
    .padding()
  }

  /// Hosts the demo so the `#Preview` body is one expression — the `enum` and
  /// `@State` live at file scope, not inside the macro (which is brittle with
  /// nested declarations). Mirrors the real use: rows of a default `Picker`.
  ///
  /// `internal` (not `private`) so the snapshot test target can render it and
  /// exercise this preview's view code; it stays inside `#if DEBUG`.
  struct IconLabelPickerPreview: View {
    private enum Kind: String, CaseIterable, Identifiable {
      case marks, routes, traces
      var id: String { rawValue }
      var title: LocalizedStringKey { LocalizedStringKey(rawValue.capitalized) }
      var systemImage: String {
        switch self {
        case .marks: "mappin.and.ellipse"
        case .routes: "point.topleft.down.to.point.bottomright.curvepath"
        case .traces: "scribble.variable"
        }
      }
    }

    @State private var kind: Kind = .marks

    var body: some View {
      Form {
        Picker("Kind", selection: $kind) {
          ForEach(Kind.allCases) { kind in
            IconLabel(kind.title, systemImage: kind.systemImage).tag(kind)
          }
        }
      }
    }
  }

  #Preview("In a Picker") {
    IconLabelPickerPreview()
  }
#endif
