public import SwiftUI

#if canImport(WebKit)
	import WebKit
#endif

// MARK: - PopupWebView

/// A SwiftUI button that opens an embedded ``WebKitView`` in a popover, with
/// an additional "Open in Browser" button to escape to the user's default
/// browser via the SwiftUI `openURL` environment action.
///
/// On watchOS the popover is replaced by a plain `Link` (WebKit is unavailable).
/// On tvOS the "Open in Browser" button is hidden (no system browser).
///
/// ```swift
/// PopupWebView(url: URL(string: "https://example.com")!, title: "Example")
/// ```
public struct PopupWebView: View {

	// MARK: Properties

	@Environment(\.openURL) private var openURL

	var url: URL
	var title: String?

	// MARK: Init

	/// Creates a popup web-page presenter.
	///
	/// - Parameters:
	///   - url: Web page loaded inside the embedded `WKWebView` (or shown as a
	///     `Link` destination on watchOS).
	///   - title: Optional label used as the watchOS `Link` text.  Defaults to
	///     the URL string when `nil`.
	public init(url: URL, title: String? = nil) {
		self.url = url
		self.title = title
	}

	// MARK: Body

	public var body: some View {
		#if os(watchOS)
			Link(title ?? url.absoluteString, destination: url)
				.accessibilityIdentifier("PopupWebView.button")
		#else
			HStack {
				PopupPresenter {
					if let title, !title.isEmpty {
						Label(title, systemImage: "link")
					} else {
						Image(systemName: "link")
					}
				} presentedContent: {
					ZStack(alignment: .bottomTrailing) {
						WebKitView(url: url)
							.frame(maxWidth: .infinity, maxHeight: .infinity)

						#if !os(tvOS)
							Button {
								openURL(url)
							} label: {
								Label {
									Text("Open in Browser", bundle: .module)
								} icon: {
									Image(systemName: "safari")
								}
							}
							.padding(.trailing, 20)
							.padding(.bottom, 20)
							.PreferredAvailableButtonStyle()
							.accessibilityIdentifier("PopupWebView.openInBrowser")
						#endif
					}
				}
			}
			.accessibilityIdentifier("PopupWebView.button")
		#endif
	}
}

// MARK: - Previews

#Preview("No title") {
	PopupWebView(url: URL(string: "https://example.com")!)
}

#Preview("With title") {
	PopupWebView(url: URL(string: "https://example.com")!, title: "Example")
}

#Preview("In List") {
	List {
		PopupWebView(url: URL(string: "https://apple.com")!, title: "Apple")
		PopupWebView(url: URL(string: "https://example.com")!, title: "Example")
	}
}
