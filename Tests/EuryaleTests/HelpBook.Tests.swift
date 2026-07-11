import Foundation
import Testing

@testable import Euryale

private func sampleBook() -> HelpBook {
	HelpBook(topics: [
		HelpTopic(
			id: "getting-started",
			title: "Getting started",
			body: "…",
			file: "getting-started.md",
			children: [
				HelpTopic(id: "connecting", title: "Connecting", body: "…", file: "connecting.md")
			]
		),
		HelpTopic(id: "in-memory", title: "In memory", body: "…"),
	])
}

@Test func `HelpBook flattens the topic tree and looks up slugs`() {
	let book = sampleBook()
	#expect(book.topics.count == 2)
	#expect(book.allTopics.count == 3)
	#expect(book.topic(id: "connecting")?.title == "Connecting")
	#expect(book.topic(id: "missing") == nil)
}

@Test func `a relative article link resolves to the topic with that source file`() throws {
	let book = sampleBook()
	let url = try #require(URL(string: "connecting.md"))
	#expect(book.topic(linkedBy: url)?.id == "connecting")
}

@Test func `a relative link with a directory prefix still matches by file name`() throws {
	let book = sampleBook()
	let url = try #require(URL(string: "articles/getting-started.md"))
	#expect(book.topic(linkedBy: url)?.id == "getting-started")
}

@Test func `a link with no matching file falls back to the slug`() throws {
	let book = sampleBook()
	// `in-memory` has no source file; only the slug can match.
	let url = try #require(URL(string: "in-memory.md"))
	#expect(book.topic(linkedBy: url)?.id == "in-memory")
}

@Test func `absolute links keep the system behaviour`() throws {
	let book = sampleBook()
	let web = try #require(URL(string: "https://example.com/connecting.md"))
	#expect(book.topic(linkedBy: web) == nil)
	let mail = try #require(URL(string: "mailto:someone@example.com"))
	#expect(book.topic(linkedBy: mail) == nil)
}

@Test func `an unresolvable relative link returns nil`() throws {
	let book = sampleBook()
	let url = try #require(URL(string: "nowhere.md"))
	#expect(book.topic(linkedBy: url) == nil)
}
