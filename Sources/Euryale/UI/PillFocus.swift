public import SwiftUI

// MARK: - Pill focus & selection

/// Makes a pill-like cell focusable and selectable.
///
/// On **tvOS** the cell becomes a focus target: it lifts slightly when focused
/// and a press of the Siri Remote's *Select* button invokes `onSelect`. On the
/// pointer and touch platforms a plain tap invokes `onSelect`.
///
/// Multi-page pills (``PaginatedView`` / ``PaginatedPill``) wire their own
/// focus *and* left/right page navigation internally, so do **not** also apply
/// this modifier to them — pass their `onSelect:` argument instead. Use this
/// modifier for single-page pill cells (plain cards) so they share the same
/// focus and selection behaviour inside a ``PillGrid``.
extension View {
	/// Makes the view a focusable, selectable pill cell.
	/// - Parameter onSelect: Invoked on a *Select* press (tvOS) or a tap
	///   (other platforms).
	public func pillSelectable(onSelect: @escaping () -> Void) -> some View {
		modifier(PillFocusModifier(onSelect: onSelect, onMove: nil))
	}
}

/// Shared focus chrome and input wiring for pill cells.
///
/// `onMove` is tvOS-only and, when non-`nil`, intercepts left/right Siri Remote
/// presses so they page *within* the cell rather than moving focus away. It is
/// left `nil` for single-page cells, which keeps left/right free to move focus
/// between neighbouring pills.
struct PillFocusModifier: ViewModifier {

	let onSelect: (() -> Void)?
	let onMove: ((MoveCommandDirection) -> Void)?

	#if os(tvOS)
		@FocusState private var isFocused: Bool

		@ViewBuilder
		func body(content: Content) -> some View {
			let base =
				content
				.focusable(onSelect != nil || onMove != nil)
				.focused($isFocused)
				.scaleEffect(isFocused ? PillMetrics.focusScale : 1)
				.animation(.easeInOut(duration: 0.15), value: isFocused)
				.onTapGesture { onSelect?() }

			if let onMove {
				base.onMoveCommand(perform: onMove)
			} else {
				base
			}
		}
	#else
		@ViewBuilder
		func body(content: Content) -> some View {
			if let onSelect {
				content
					.contentShape(Rectangle())
					.onTapGesture(perform: onSelect)
			} else {
				content
			}
		}
	#endif
}
