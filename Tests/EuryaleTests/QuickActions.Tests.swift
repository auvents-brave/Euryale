import SwiftUI
import Testing

@testable import Euryale

// Cross-platform value semantics of `QuickAction`, plus the registry
// behaviour of `QuickActions` (install / perform / pending launch action) and,
// on macOS, the Dock-menu construction with its group separators.
@MainActor
@Suite("QuickActions")
struct QuickActionsTests {

	// MARK: - QuickAction value semantics

	@Test func `action stores its fields with the expected defaults`() {
		let action = QuickAction(id: "x", title: "X", systemImage: "star") {}

		#expect(action.id == "x")
		#expect(action.title == "X")
		#expect(action.subtitle == nil)
		#expect(action.systemImage == "star")
		#expect(action.separatorBefore == false)
	}

	@Test func `separatorBefore and subtitle are stored`() {
		let action = QuickAction(
			id: "y",
			title: "Y",
			subtitle: "More",
			systemImage: "pin",
			separatorBefore: true
		) {}

		#expect(action.subtitle == "More")
		#expect(action.separatorBefore)
	}

	// MARK: - Registry (macOS: install is storage-only, no UIKit side effects)

	#if os(macOS)
		@Test func `perform runs the matching handler and reports misses`() {
			var ran = false
			QuickActions.install([
				QuickAction(id: "run", title: "Run", systemImage: "play") { ran = true }
			])

			#expect(QuickActions.perform(id: "run"))
			#expect(ran)
			#expect(QuickActions.perform(id: "missing") == false)
		}

		@Test func `pending launch action runs exactly once`() {
			var count = 0
			QuickActions.install([
				QuickAction(id: "cold", title: "Cold", systemImage: "snowflake") { count += 1 }
			])

			QuickActions.rememberLaunchAction(id: "cold")
			QuickActions.performPendingLaunchAction()
			QuickActions.performPendingLaunchAction()

			#expect(count == 1)
		}

		// MARK: - Dock menu

		@Test func `dock menu inserts a separator before a flagged action`() {
			QuickActions.install([
				QuickAction(id: "a", title: "A", systemImage: "1.circle") {},
				QuickAction(id: "b", title: "B", systemImage: "2.circle") {},
				QuickAction(id: "c", title: "C", systemImage: "3.circle", separatorBefore: true) {},
			])

			let menu = QuickActions.dockMenu()

			// A, B, ───, C
			#expect(menu.items.count == 4)
			#expect(menu.items[0].title == "A")
			#expect(menu.items[1].title == "B")
			#expect(menu.items[2].isSeparatorItem)
			#expect(menu.items[3].title == "C")
			#expect(menu.items[3].representedObject as? String == "c")
		}

		@Test func `dock menu never starts with a separator`() {
			QuickActions.install([
				QuickAction(id: "first", title: "First", systemImage: "1.circle", separatorBefore: true) {}
			])

			let menu = QuickActions.dockMenu()

			#expect(menu.items.count == 1)
			#expect(menu.items[0].isSeparatorItem == false)
		}

		@Test func `dock menu item click routes to the action handler`() throws {
			var ran = false
			QuickActions.install([
				QuickAction(id: "click", title: "Click", systemImage: "cursorarrow") { ran = true }
			])

			let menu = QuickActions.dockMenu()
			let item = try #require(menu.items.first)
			_ = item.target?.perform(item.action, with: item)

			#expect(ran)
		}
	#endif
}
