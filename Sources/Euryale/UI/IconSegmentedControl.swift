public import SwiftUI

// MARK: - IconSegmentedControl

/// A horizontal segmented control whose every segment is a single, fully
/// clickable icon-and-text button.
///
/// SwiftUI's `Picker` with `.pickerStyle(.segmented)` is unsuitable when each
/// option needs both a glyph and a title: on macOS it **splits** a composed
/// label into two separate segments (one for the icon, one for the text) and
/// forces the symbols to render monochrome. `IconSegmentedControl` keeps each
/// option as one button, so a tap anywhere on it selects that option, and its
/// `Image` honours the surrounding ``SwiftUICore/View/symbolRenderingMode(_:)``
/// — so multicolour symbols stay multicolour.
///
/// The selected segment is filled with `selectionTint` (the accent colour by
/// default); segments share the available width equally.
///
/// ```swift
/// enum Filter: String, CaseIterable, Hashable { case all, marks, routes }
///
/// IconSegmentedControl(
///     selection: $filter,
///     options: Filter.allCases,
///     systemImage: { $0.systemImage },
///     label: { Text($0.title) }
/// )
/// ```
public struct IconSegmentedControl<Value: Hashable>: View {
	// MARK: Properties

	@Binding private var selection: Value
	private let options: [Value]
	private let selectionTint: Color
	private let systemImage: (Value) -> String
	private let label: (Value) -> Text

	// MARK: Initialiser

	/// Creates a segmented control over a sequence of values.
	/// - Parameters:
	///   - selection: A binding to the currently selected value.
	///   - options: The selectable values, in display order.
	///   - selectionTint: The fill behind the selected segment. Defaults to the accent colour.
	///   - systemImage: The SF Symbol name for a value.
	///   - label: The title for a value (wrap a `String` or a `LocalizedStringKey` in `Text`).
	public init<C: RandomAccessCollection>(
		selection: Binding<Value>,
		options: C,
		selectionTint: Color = .accentColor,
		systemImage: @escaping (Value) -> String,
		label: @escaping (Value) -> Text
	) where C.Element == Value {
		_selection = selection
		self.options = Array(options)
		self.selectionTint = selectionTint
		self.systemImage = systemImage
		self.label = label
	}

	// MARK: Body

	/// The content and behaviour of the view.
	public var body: some View {
		HStack(spacing: 3) {
			ForEach(Array(options.enumerated()), id: \.offset) { item in
				segment(for: item.element)
			}
		}
		.padding(3)
		.background(Color.secondary.opacity(0.14), in: Capsule())
	}

	private func segment(for value: Value) -> some View {
		let isSelected = value == selection
		return Button {
			withAnimation(.easeInOut(duration: 0.15)) { selection = value }
		} label: {
			HStack(spacing: 5) {
				// No `foregroundStyle` on the icon: it keeps its own rendering
				// mode (multicolour) inherited from the environment.
				Image(systemName: systemImage(value))
					.symbolRenderingMode(.hierarchical)
				label(value)
					.lineLimit(1)
					.foregroundStyle(isSelected ? Color.white : Color.primary)
			}
			.font(.callout)
			.padding(.vertical, 5)
			.padding(.horizontal, 12)
			.background {
				if isSelected {
					Capsule().fill(selectionTint)
				}
			}
			.contentShape(Capsule())
		}
		.buttonStyle(.plain)
		.accessibilityAddTraits(isSelected ? [.isSelected] : [])
	}
}

// MARK: - Preview

#Preview("Filter & layout") {
	enum Filter: String, CaseIterable, Hashable, Identifiable {
		case all, marks, routes, traces
		var id: String { rawValue }
		var title: LocalizedStringKey { LocalizedStringKey(rawValue.capitalized) }
		var systemImage: String {
			switch self {
			case .all: "square.grid.2x2"
			case .marks: "mappin.and.ellipse"
			case .routes: "point.topleft.down.to.point.bottomright.curvepath"
			case .traces: "scribble.variable"
			}
		}
	}
	struct Demo: View {
		@State private var filter: Filter = .marks
		var body: some View {
			IconSegmentedControl(
				selection: $filter,
				options: Filter.allCases,
				systemImage: { $0.systemImage },
				label: { Text($0.title) }
			)
			.symbolRenderingMode(.hierarchical)
			.padding()
		}
	}
	return Demo()
}
