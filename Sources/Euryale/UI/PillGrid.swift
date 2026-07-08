public import SwiftUI

/// An adaptive grid of pill cells whose column density adapts to the platform.
///
/// `PillGrid` wraps a `LazyVGrid` with an `.adaptive` column whose minimum
/// width and spacing come from ``PillMetrics``. On the touch and desktop
/// platforms that means a dense grid of compact pills; on **tvOS**, where
/// system fonts are much larger, it means a handful of wide, legible columns so
/// pill content is never clipped.
///
/// Pair it with ``View/pillSelectable(onSelect:)`` (single-page cells) or with
/// the `onSelect:` argument of ``PaginatedPill`` (multi-page cells) so every
/// cell is focusable and selectable on tvOS.
///
/// ```swift
/// PillGrid(groups) { group in
///     pill(for: group, onSelect: { selected = group })
/// }
/// ```
public struct PillGrid<Data: RandomAccessCollection, Content: View>: View
where Data.Element: Identifiable {

	private let data: Data
	@ContentBuilder private let content: (Data.Element) -> Content

	/// Creates a pill grid.
	/// - Parameters:
	///   - data: The identifiable items, one pill cell per element.
	///   - content: Builds the cell for a given element.
	public init(_ data: Data, @ContentBuilder content: @escaping (Data.Element) -> Content) {
		self.data = data
		self.content = content
	}

	/// The content and behaviour of the view.
	public var body: some View {
		LazyVGrid(
			columns: [GridItem(.adaptive(minimum: PillMetrics.gridMinimum), spacing: PillMetrics.gridSpacing)],
			spacing: PillMetrics.gridSpacing
		) {
			ForEach(data) { element in
				content(element)
			}
		}
		.accessibilityIdentifier("PillGrid")
	}
}

// MARK: - Previews

#Preview("PillGrid") {
	struct Room: Identifiable {
		let id = UUID()
		let name: String
		let count: Int
	}
	let rooms = (1...6).map { Room(name: "Room \($0)", count: $0) }
	return ScrollView {
		PillGrid(rooms) { room in
			Pill(label: room.name, value: room.count)
				.pillSelectable {}
		}
		.padding()
	}
}
