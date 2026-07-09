/// A single help article, addressable by a stable slug and rendered from
/// Markdown source text.
///
/// Topics form a shallow tree: a topic may carry ``children`` to model a
/// section that groups related articles in the navigation sidebar.
public struct HelpTopic: Identifiable, Hashable, Sendable {
	/// Stable slug identifying the topic. Shared across localisations and with
	/// the website and macOS Help Book, so deep links stay valid everywhere.
	public let id: String

	/// Localised, human-facing title shown in the sidebar and as the heading.
	public let title: String

	/// Extra search terms that should match this topic beyond its title and
	/// body — synonyms, abbreviations, alternate spellings.
	public let keywords: [String]

	/// The Markdown body rendered in the detail pane.
	public let body: String

	/// The Markdown file name the body was loaded from (e.g. `connecting.md`),
	/// so relative links between articles can be resolved back to a topic.
	/// `nil` for in-memory topics.
	public let file: String?

	/// Child topics nested beneath this one in the navigation tree.
	public let children: [HelpTopic]

	/// Creates a help topic.
	/// - Parameters:
	///   - id: Stable slug identifying the topic.
	///   - title: Localised title shown to the reader.
	///   - keywords: Additional search terms. Defaults to none.
	///   - body: Markdown body text.
	///   - file: Source file name, for resolving inter-article links. Defaults
	///     to `nil`.
	///   - children: Nested child topics. Defaults to none.
	public init(
		id: String,
		title: String,
		keywords: [String] = [],
		body: String,
		file: String? = nil,
		children: [HelpTopic] = []
	) {
		self.id = id
		self.title = title
		self.keywords = keywords
		self.body = body
		self.file = file
		self.children = children
	}

	/// This topic and all of its descendants, in depth-first order.
	public var flattened: [HelpTopic] {
		[self] + children.flatMap(\.flattened)
	}
}
