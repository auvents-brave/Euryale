public import Foundation

/// A loaded, localised collection of ``HelpTopic`` articles, ready to display
/// in a ``HelpBrowser`` and to search.
///
/// The content is the single source shared with the website and the macOS Help
/// Book: a `Help` directory holding one subdirectory per localisation, each
/// containing a `manifest.json` index and the Markdown bodies it references.
///
/// ```
/// Help/
///   en/  manifest.json  getting-started.md  …
///   fr/  manifest.json  premiers-pas.md     …
/// ```
public struct HelpBook: Sendable {
	/// The top-level topics, in manifest order.
	public let topics: [HelpTopic]

	/// Every topic and descendant, depth-first — the corpus searched by
	/// ``search(_:)``.
	public let allTopics: [HelpTopic]

	/// The resolved localisation directory the book was loaded from, or `nil` for
	/// an in-memory book. Article images (`images/…`) are resolved against it.
	public let baseURL: URL?

	/// Creates a help book from an in-memory topic tree.
	/// - Parameters:
	///   - topics: The top-level topics.
	///   - baseURL: The directory article images resolve against. Defaults to
	///     `nil` (no on-disk assets).
	public init(topics: [HelpTopic], baseURL: URL? = nil) {
		self.topics = topics
		self.allTopics = topics.flatMap(\.flattened)
		self.baseURL = baseURL
	}

	/// Returns the topic with the given slug, if present anywhere in the tree.
	/// - Parameter id: The slug to look up.
	/// - Returns: The matching topic, or `nil`.
	public func topic(id: String) -> HelpTopic? {
		allTopics.first { $0.id == id }
	}

	/// Returns the topic a relative article link points at, matched by its
	/// source file name (`connecting.md`) and falling back to the slug
	/// (`connecting`).
	/// - Parameter url: The link destination, as tapped in an article body.
	/// - Returns: The matching topic, or `nil` for absolute links (`https:` …)
	///   and empty paths, which keep the system behaviour.
	public func topic(linkedBy url: URL) -> HelpTopic? {
		guard url.scheme == nil || url.scheme?.isEmpty == true else { return nil }
		let name = url.lastPathComponent
		guard name.isEmpty == false else { return nil }
		return allTopics.first { $0.file == name }
			?? topic(id: url.deletingPathExtension().lastPathComponent)
	}

	// MARK: - Loading

	/// A failure encountered while loading help content from a bundle.
	public enum LoadingError: Error, Sendable {
		/// The `Help` directory was not found in the bundle.
		case directoryNotFound(String)
		/// No localisation subdirectory containing a `manifest.json` was found.
		case noLocalizationFound
		/// A Markdown file referenced by the manifest was missing.
		case missingBody(file: String)
	}

	/// Loads the best-matching localised help content shipped in `bundle`.
	///
	/// The localisation is chosen by matching `preferredLanguages` against the
	/// available subdirectories of the `Help` folder, falling back to English
	/// and then to whichever localisation is present.
	///
	/// - Parameters:
	///   - bundle: The bundle that ships the `Help` directory. Defaults to the
	///     main bundle.
	///   - directory: The folder name holding the localisation subdirectories.
	///     Defaults to `"Help"`.
	///   - preferredLanguages: Ordered language identifiers to match against the
	///     available localisations. Defaults to the user's preferences.
	/// - Returns: The loaded help book.
	/// - Throws: A ``LoadingError`` if the content cannot be located or read.
	public static func load(
		from bundle: Bundle = .main,
		directory: String = "Help",
		preferredLanguages: [String] = Locale.preferredLanguages
	) throws -> HelpBook {
		guard let baseURL = bundle.url(forResource: directory, withExtension: nil) else {
			throw LoadingError.directoryNotFound(directory)
		}
		let localeURL = try resolveLocalization(in: baseURL, preferred: preferredLanguages)
		let manifestURL = localeURL.appendingPathComponent("manifest.json")
		let data = try Data(contentsOf: manifestURL)
		let manifest = try JSONDecoder().decode(HelpManifest.self, from: data)
		let topics = try manifest.topics.map { try $0.resolve(in: localeURL) }
		return HelpBook(topics: topics, baseURL: localeURL)
	}

	/// Picks the localisation subdirectory that best matches the preferred
	/// languages, requiring each candidate to contain a `manifest.json`.
	private static func resolveLocalization(
		in baseURL: URL,
		preferred: [String]
	) throws -> URL {
		let manager = FileManager.default
		let entries =
			(try? manager.contentsOfDirectory(
				at: baseURL,
				includingPropertiesForKeys: [.isDirectoryKey]
			)) ?? []

		// Keep only directories that actually hold a manifest.
		let localizations = entries.filter { url in
			(try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
				&& manager.fileExists(atPath: url.appendingPathComponent("manifest.json").path)
		}
		guard localizations.isEmpty == false else {
			throw LoadingError.noLocalizationFound
		}

		// Match each preferred language's base code against a directory name.
		for language in preferred {
			let code = String(language.prefix { $0 != "-" && $0 != "_" }).lowercased()
			if let match = localizations.first(where: {
				$0.lastPathComponent.lowercased().hasPrefix(code)
			}) {
				return match
			}
		}

		// Fall back to English, then to whatever is available.
		return localizations.first { $0.lastPathComponent.lowercased().hasPrefix("en") }
			?? localizations.sorted { $0.lastPathComponent < $1.lastPathComponent }[0]
	}
}

// MARK: - Manifest decoding

/// On-disk index describing the topic tree and pointing at Markdown bodies.
private struct HelpManifest: Decodable {
	let topics: [Entry]

	struct Entry: Decodable {
		let id: String
		let title: String
		let keywords: [String]?
		let file: String?
		let children: [Entry]?

		/// Builds a ``HelpTopic`` by reading this entry's Markdown body (if any)
		/// and resolving its children, relative to `localeURL`.
		func resolve(in localeURL: URL) throws -> HelpTopic {
			let body: String
			if let file {
				let url = localeURL.appendingPathComponent(file)
				guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
					throw HelpBook.LoadingError.missingBody(file: file)
				}
				body = contents
			} else {
				body = ""
			}
			return HelpTopic(
				id: id,
				title: title,
				keywords: keywords ?? [],
				body: body,
				file: file,
				children: try (children ?? []).map { try $0.resolve(in: localeURL) }
			)
		}
	}
}
