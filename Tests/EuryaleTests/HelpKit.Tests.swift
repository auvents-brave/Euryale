import Foundation
import Testing

@testable import Euryale

// Covers the in-memory HelpBook model: the flattened topic tree, slug and
// relative-link lookup, and the ranked, diacritic-insensitive search.
@Suite("HelpKit")
struct HelpKitTests {

	private let book = HelpBook(topics: [
		HelpTopic(
			id: "connecting", title: "Connecting", keywords: ["network", "wifi"],
			body: "How to connect over Wi-Fi.", file: "connecting.md",
			children: [
				HelpTopic(id: "vhf", title: "VHF calls", keywords: ["dsc"], body: "Placing a DSC call.", file: "vhf.md")
			]),
		HelpTopic(id: "logbook", title: "Logbook", body: "The étrave and the journal.", file: "logbook.md"),
		HelpTopic(id: "network-setup", title: "Network setup", body: "Configure the gateway.", file: "network.md"),
	])

	@Test func `allTopics flattens the tree depth-first`() {
		#expect(book.allTopics.map(\.id) == ["connecting", "vhf", "logbook", "network-setup"])
		#expect(book.topics.count == 3)  // top-level only
	}

	@Test func `topic(id:) finds nested topics and misses cleanly`() {
		#expect(book.topic(id: "vhf")?.title == "VHF calls")
		#expect(book.topic(id: "connecting")?.children.count == 1)
		#expect(book.topic(id: "absent") == nil)
	}

	@Test func `topic(linkedBy:) resolves by file, falls back to slug, ignores absolute links`() {
		#expect(book.topic(linkedBy: URL(string: "vhf.md")!)?.id == "vhf")
		#expect(book.topic(linkedBy: URL(string: "connecting")!)?.id == "connecting")  // slug fallback
		#expect(book.topic(linkedBy: URL(string: "https://example.com/x")!) == nil)  // absolute
		#expect(book.topic(linkedBy: URL(string: "/")!) == nil)  // empty path
	}

	@Test func `search returns nothing for an empty query`() {
		#expect(book.search("").isEmpty)
	}

	@Test func `search matches title, keyword and body, diacritic-insensitively`() {
		#expect(book.search("log").map(\.id) == ["logbook"])  // title
		#expect(book.search("dsc").map(\.id) == ["vhf"])  // keyword
		#expect(book.search("etrave").map(\.id) == ["logbook"])  // body, "étrave"
	}

	@Test func `search ranks a title match ahead of a keyword match`() {
		// "network" is the title of one topic and a keyword of another.
		#expect(book.search("network").map(\.id) == ["network-setup", "connecting"])
	}
}
