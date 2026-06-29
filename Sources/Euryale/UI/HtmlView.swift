import Logging
public import SwiftUI

// MARK: - HtmlView

/// Lightweight cross-platform HTML-to-`Text` renderer.
///
/// `HtmlView` is intended for **short, inline HTML fragments** — a paragraph
/// with `<b>`, `<i>`, `<a href>`, inline CSS — embedded inside SwiftUI
/// layouts (lists, cells, stacks).  It auto-adapts to:
///
/// - **Dark / light mode** via `colorScheme` (body text becomes white/black).
/// - **Dynamic Type** via `@ScaledMetric` on the body font size.
///
/// The string is checked with a regex for any HTML tag:
/// - **No tags** → renders as plain `Text(forHTML)` (fast path).
/// - **Has tags** → wraps the input in a minimal `<!doctype html>` document
///   with `font-family: "-apple-system"` and the resolved colour, decodes
///   it via `NSAttributedString(data:options: [.documentType: .html])`, then
///   converts to `AttributedString` and displays via `Text`.
///
/// Available on macOS, iOS, iPadOS, tvOS, watchOS, visionOS and Mac
/// Catalyst — pure SwiftUI, no UIKit/AppKit dependency.
///
/// For **long HTML documents** that need scrolling, link tapping with
/// automatic data detectors, or text selection, use ``TextKitView`` instead
/// (UIKit-only).
///
/// ```swift
/// HtmlView(forHTML: "Hello <b>World</b> with a <a href=\"https://apple.com\">link</a>.")
/// ```
public struct HtmlView: View {

	// MARK: Properties

	@Environment(\.colorScheme) private var colorScheme
	@ScaledMetric private var bodySize = 17.0
	let forHTML: String

	// MARK: Init

	/// Creates an HTML view.
	/// - Parameter forHTML: An HTML fragment or plain text.  Strings with no
	///   tags are rendered as plain `Text` without any HTML processing.
	public init(forHTML: String) {
		self.forHTML = forHTML
	}

	// MARK: Body

	/// The content and behaviour of the view.
	public var body: some View {
		content
			.accessibilityIdentifier("HtmlView")
	}

	// MARK: Helpers

	@ViewBuilder
	private var content: some View {
		let fontColor = (colorScheme == .dark) ? "white" : "black"
		let cleaned = forHTML.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

		if cleaned == forHTML {
			Text(forHTML)
		} else {
			let fullHTML = """
				<!doctype html>
				<html>
				  <head>
					<style>
					  body {
						font-family: "-apple-system";
						font-size: \(Int(bodySize))px;
						color:\(fontColor)
					  }
					</style>
				  </head>
				  <body>
					\(forHTML)
				  </body>
				</html>
				"""
			if let nsAttributedString = try? NSAttributedString(
				data: Data(fullHTML.utf8),
				options: [.documentType: NSAttributedString.DocumentType.html],
				documentAttributes: nil
			) {
				Text(AttributedString(nsAttributedString))
			} else {
				Text("")  // still returns a View
					.onAppear {
						Logger(label: "HtmlView")
							.error("NSAttributedString failed", metadata: ["html": "\(forHTML)"])
					}
			}
		}
	}
}

// MARK: - Previews

#Preview {
	VStack {
		HtmlView(forHTML: "not html text")
		HtmlView(forHTML: "Hello <World>!")  // recognised as html tagged
		HtmlView(forHTML: "0 < 8 < 17")
		HtmlView(forHTML: "0 < 8 > 3")  // recognised as html tagged

		HtmlView(forHTML: "Hello <B>World</B>")
		Divider()
		HtmlView(
			forHTML: "<p style=\"font-family:Georgia, Times, serif;\">Serif font.</p>"
		)
		Divider()
		HtmlView(
			forHTML:
				"<p style=\"color:#B22222\">Color text and <span style=\"color:limegreen;\">another color</span>, and now back to the same. Oh, and here's a <span style=\"background-color:PaleGreen;\">different background color</span> just in case you need it!</p>"
		)
		Divider()
		HtmlView(forHTML: "<tt>Teletype text.</tt>")
	}
	.background(Color(.lightGray))
}
