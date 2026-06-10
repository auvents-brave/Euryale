public import SwiftUI

// MARK: - StatusPill

/// A small SwiftUI badge that pairs an SF Symbol with a short label, tinted
/// according to a semantic status (OK / warning / error).
///
/// Used to surface health, validation, or progress states in lists, cells or
/// settings screens.  The pill stretches horizontally to fill the available
/// width and sits on a rounded rectangle background tinted with the status
/// colour at 20 % opacity.
///
/// ```swift
/// VStack(spacing: 8) {
///     StatusPill(label: "All Good",         status: .ok)
///     StatusPill(label: "Check Items",      status: .warning)
///     StatusPill(label: "Needs Attention",  status: .error)
/// }
/// ```
///
/// For a label-and-integer-value badge (no status), see ``Pill``.
public struct StatusPill: View {

	// MARK: Nested types

	/// The semantic level a ``StatusPill`` conveys.
	///
	/// Each case maps to an SF Symbol and a tint colour:
	///
	/// | Case      | Symbol                              | Tint   |
	/// |-----------|-------------------------------------|--------|
	/// | ``ok``    | `checkmark.circle.fill`             | green  |
	/// | ``warning`` | `exclamationmark.triangle.fill`   | yellow |
	/// | ``error`` | `xmark.circle.fill`                 | red    |
	public enum Status {
		/// Everything is fine — green checkmark.
		case ok
		/// Action required, not blocking — yellow triangle.
		case warning
		/// Something failed or is blocking — red cross.
		case error

		var symbolName: String {
			switch self {
			case .ok:
				return "checkmark.circle.fill"
			case .warning:
				return "exclamationmark.triangle.fill"
			case .error:
				return "xmark.circle.fill"
			}
		}

		var backgroundColor: Color {
			return symbolColor.opacity(0.2)
		}

		var symbolColor: Color {
			switch self {
			case .ok:
				return Color.green
			case .warning:
				return Color.yellow
			case .error:
				return Color.red
			}
		}
	}

	// MARK: Properties

	let label: String
	let status: Status

	// MARK: Init

	/// Creates a status pill.
	/// - Parameters:
	///   - label: The text shown next to the status symbol.
	///   - status: The semantic level — see ``Status``.
	public init(label: String, status: Status) {
		self.label = label
		self.status = status
	}

	// MARK: Body

	public var body: some View {
		HStack(spacing: 6) {
			Image(systemName: status.symbolName)
				.foregroundStyle(status.symbolColor)
			Text(label)
				.font(.caption)
		}
		.padding(10)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(status.backgroundColor)
		.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
		.accessibilityIdentifier("StatusPill")
	}
}

// MARK: - Previews

#Preview("StatusPill") {
	VStack(spacing: 8) {
		StatusPill(label: "All Good", status: .ok)
		StatusPill(label: "Check Items", status: .warning)
		StatusPill(label: "Needs Attention", status: .error)
	}
	.padding()
}
