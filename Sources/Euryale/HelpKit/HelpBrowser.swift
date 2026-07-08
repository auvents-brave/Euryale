#if os(iOS) || os(macOS) || os(visionOS)
	public import SwiftUI

	internal import MarkdownUI

	/// A self-contained, searchable help reader rendering a ``HelpBook``.
	///
	/// Use it as the content of a sheet, window or pushed destination. It shows
	/// the topic tree in a sidebar with a search field, and renders the selected
	/// topic's Markdown body in the detail pane.
	///
	/// ```swift
	/// .sheet(isPresented: $showingHelp) {
	///     if let book { HelpBrowser(book: book) }
	/// }
	/// ```
	public struct HelpBrowser: View {
		private let book: HelpBook
		@State private var selection: HelpTopic.ID?
		@State private var query = ""

		/// Creates a help browser for the given book, optionally pre-selecting a
		/// topic.
		/// - Parameters:
		///   - book: The loaded help content to present.
		///   - initialTopic: The slug to show first. Defaults to the first
		///     top-level topic.
		public init(book: HelpBook, initialTopic: HelpTopic.ID? = nil) {
			self.book = book
			_selection = State(initialValue: initialTopic ?? book.topics.first?.id)
		}

		/// The content and behaviour of the view.
		public var body: some View {
			NavigationSplitView {
				sidebar
					.navigationTitle(Text("Help", bundle: .module))
					#if os(macOS)
						.navigationSplitViewColumnWidth(min: 200, ideal: 240)
					#endif
			} detail: {
				detail
			}
			.searchable(
				text: $query,
				prompt: Text("Search Help", bundle: .module)
			)
		}

		@ContentBuilder
		private var sidebar: some View {
			List(selection: $selection) {
				if query.isEmpty {
					OutlineGroup(book.topics, id: \.id, children: \.childrenOrNil) { topic in
						Text(topic.title).tag(topic.id)
					}
				} else {
					let results = book.search(query)
					if results.isEmpty {
						Text("No results", bundle: .module)
							.foregroundStyle(.secondary)
					} else {
						ForEach(results) { topic in
							Text(topic.title).tag(topic.id)
						}
					}
				}
			}
		}

		@ContentBuilder
		private var detail: some View {
			if let id = selection, let topic = book.topic(id: id) {
				ScrollView {
					Markdown(topic.body)
						.markdownImageProvider(HelpImageProvider(baseURL: book.baseURL))
						.textSelection(.enabled)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding()
				}
				.navigationTitle(topic.title)
				// Articles cross-reference each other with relative Markdown links
				// (`[…](connecting.md)`). Resolve those to the matching topic instead
				// of handing them to the system (which cannot open them); everything
				// else — http links etc. — keeps the default behaviour.
				.environment(
					\.openURL,
					OpenURLAction { url in
						guard let target = linkedTopic(for: url) else { return .systemAction }
						selection = target.id
						return .handled
					})
			} else {
				ContentUnavailableView {
					Label {
						Text("Select a Topic", bundle: .module)
					} icon: {
						Image(systemName: "questionmark.circle")
					}
				} description: {
					Text("Choose a help topic from the sidebar.", bundle: .module)
				}
			}
		}
	}

	extension HelpBrowser {
		/// The topic a relative article link points at, matched by its source file
		/// name (`connecting.md`) and falling back to the slug (`connecting`).
		/// `nil` for absolute links (http…), which keep the system behaviour.
		private func linkedTopic(for url: URL) -> HelpTopic? {
			guard url.scheme == nil || url.scheme?.isEmpty == true else { return nil }
			let name = url.lastPathComponent
			guard name.isEmpty == false else { return nil }
			return book.allTopics.first { $0.file == name }
				?? book.topic(id: url.deletingPathExtension().lastPathComponent)
		}
	}

	extension HelpTopic {
		/// Children for `OutlineGroup`, collapsing an empty array to `nil` so
		/// leaf topics show no disclosure triangle.
		fileprivate var childrenOrNil: [HelpTopic]? {
			children.isEmpty ? nil : children
		}
	}

	#Preview("HelpBrowser") {
		HelpBrowser(
			book: HelpBook(topics: [
				HelpTopic(
					id: "getting-started",
					title: "Getting started",
					body:
						"Welcome to **Thoosa**.\n\nConnect to your boat and watch the instruments come alive."
				),
				HelpTopic(
					id: "logbook",
					title: "Logbook",
					body: "Record a voyage and review its entries.",
					children: [
						HelpTopic(
							id: "logbook-units", title: "Units", body: "Choose nautical miles, knots and more.")
					]
				),
			]))
	}
#endif
