import SwiftUI
import Testing
import ViewInspector

@testable import Euryale

// Covers ToolbarAction's value semantics and the AdaptiveToolbar layouts via
// ViewInspector — rendering-independent, so it runs identically on every
// destination (unlike the snapshot suite, which is tied to one simulator).
@MainActor
@Suite("AdaptiveToolbar")
struct AdaptiveToolbarTests {

	// MARK: - ToolbarAction value semantics

	@Test func `action id defaults to its title`() {
		let action = ToolbarAction(title: "Add", systemImage: "plus") {}

		#expect(action.id == "Add")
		#expect(action.isEnabled)
		#expect(action.isSelected == false)
		#expect(action.canOverflow)
		#expect(action.opensSettings == false)
		#expect(action.shareItems.isEmpty)
	}

	@Test func `explicit id wins over the title`() {
		let action = ToolbarAction(id: "custom", title: "Add", systemImage: "plus") {}

		#expect(action.id == "custom")
	}

	// MARK: - Collapsed-as-menu mode

	@Test func `collapsed-as-menu renders the single ellipsis button`() throws {
		let bar = AdaptiveToolbar(
			[
				ToolbarAction(title: "Centre", systemImage: "location.fill") {},
				ToolbarAction(title: "Mark", systemImage: "mappin.and.ellipse") {},
				ToolbarAction(title: "Inspector", systemImage: "ladybug.fill") {},
			],
			collapsedAsMenu: true
		)

		// The whole bar collapses into one "…" control, however many actions.
		let image = try bar.inspect().find(ViewType.Image.self)
		#expect(try image.actualImage().name() == "ellipsis")
	}

	@Test func `collapsed-as-menu also works with grouped actions`() throws {
		let bar = AdaptiveToolbar(
			groups: [
				[ToolbarAction(title: "One", systemImage: "1.circle") {}],
				[ToolbarAction(title: "Two", systemImage: "2.circle") {}],
			],
			collapsedAsMenu: true
		)

		let image = try bar.inspect().find(ViewType.Image.self)
		#expect(try image.actualImage().name() == "ellipsis")
	}
}
