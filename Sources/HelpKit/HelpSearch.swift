internal import Foundation

extension HelpBook {
    /// Returns the topics matching `query`, ranked so that title matches come
    /// before keyword matches, which come before body matches.
    ///
    /// Matching is case- and diacritic-insensitive. An empty or whitespace-only
    /// query returns an empty array, letting callers show the full tree instead.
    ///
    /// - Parameter query: The user's search text.
    /// - Returns: Matching topics, best matches first.
    public func search(_ query: String) -> [HelpTopic] {
        let needle = query.folded
        guard needle.isEmpty == false else { return [] }

        var ranked: [(topic: HelpTopic, rank: Int)] = []
        for topic in allTopics {
            if topic.title.folded.contains(needle) {
                ranked.append((topic, 0))
            } else if topic.keywords.contains(where: { $0.folded.contains(needle) }) {
                ranked.append((topic, 1))
            } else if topic.body.folded.contains(needle) {
                ranked.append((topic, 2))
            }
        }
        return ranked
            .sorted { $0.rank < $1.rank }
            .map(\.topic)
    }
}

private extension String {
    /// A lower-cased, diacritic-stripped form for forgiving comparisons
    /// (so "etrave" matches "étrave").
    var folded: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
