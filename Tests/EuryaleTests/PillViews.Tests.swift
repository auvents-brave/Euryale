import SwiftUI
import Testing
import ViewInspector

@testable import Euryale

// Renders the paging pill views and the entity list so their bodies are
// evaluated (ViewInspector), covering the page/indicator layout and the list
// rows without a live UI.
@MainActor
@Suite("Pill and list views")
struct PillViewsTests {

	private struct Page: Identifiable { let id: Int }
	private struct Item: Identifiable {
		let id: Int
		let name: String
	}

	@Test func `MultiPagePill renders its first page`() throws {
		let pill = MultiPagePill(pageCount: 3) { index in Text("Page \(index)") }
		let texts = try pill.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
		#expect(texts.contains("Page 0"))
	}

	@Test func `MultiPagePill with a single page still renders`() throws {
		let pill = MultiPagePill { _ in Text("Only") }
		#expect(try pill.inspect().findAll(ViewType.Text.self).isEmpty == false)
	}

	@Test func `PaginatedView renders the current page's content`() throws {
		let view = PaginatedView(pages: [Page(id: 0), Page(id: 1)]) { page in
			Text("page \(page.id)")
		}
		let texts = try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
		#expect(texts.contains("page 0"))
	}

	@Test func `PaginatedPill renders inside its chrome`() throws {
		let pill = PaginatedPill(pages: [Page(id: 0), Page(id: 1)], style: .stacked) { page in
			Text("p\(page.id)")
		}
		#expect(try pill.inspect().findAll(ViewType.Text.self).isEmpty == false)
	}

	@Test func `EntityList renders a row per item`() throws {
		let items = [Item(id: 1, name: "Alpha"), Item(id: 2, name: "Bravo")]
		let list = EntityList(items, selection: .constant(nil), tag: { $0.id }) { item in
			Text(item.name)
		} actions: { _ in
			[.delete {}]
		}
		let texts = try list.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
		#expect(texts.contains("Alpha"))
		#expect(texts.contains("Bravo"))
	}
}
