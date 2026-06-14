import SwiftUI

/// Per-platform sizing constants shared by the pill family (``Pill``,
/// ``PaginatedView``, ``PaginatedPill`` and ``PillGrid``).
///
/// tvOS is a *ten-foot* interface: system fonts are far larger than on the
/// touch and desktop platforms, so the compact paddings and grid density that
/// look right elsewhere leave pill content clipped. Every dimension below is
/// therefore bumped on tvOS so a pill grows to fit its (correctly sized) text
/// and the grid lays out fewer, wider columns.
enum PillMetrics {

	/// Inner padding between a pill's background and its content.
	static var contentPadding: CGFloat {
		#if os(tvOS)
			28
		#else
			10
		#endif
	}

	/// Corner radius of the rounded pill background.
	static var cornerRadius: CGFloat {
		#if os(tvOS)
			20
		#else
			10
		#endif
	}

	/// Diameter of the active / inactive pagination indicator dots.
	static var indicatorActiveSize: CGFloat {
		#if os(tvOS)
			16
		#else
			10
		#endif
	}

	static var indicatorInactiveSize: CGFloat {
		#if os(tvOS)
			11
		#else
			7
		#endif
	}

	/// Spacing between pagination indicator dots.
	static var indicatorSpacing: CGFloat {
		#if os(tvOS)
			14
		#else
			8
		#endif
	}

	/// Minimum column width used by ``PillGrid``'s adaptive layout. The large
	/// tvOS value yields a handful of wide, legible columns instead of a dozen
	/// cramped ones.
	static var gridMinimum: CGFloat {
		#if os(tvOS)
			460
		#else
			160
		#endif
	}

	/// Spacing between ``PillGrid`` cells, both axes.
	static var gridSpacing: CGFloat {
		#if os(tvOS)
			28
		#else
			12
		#endif
	}

	/// Scale applied to a focused pill on tvOS so it lifts off the grid.
	static let focusScale: CGFloat = 1.06
}
