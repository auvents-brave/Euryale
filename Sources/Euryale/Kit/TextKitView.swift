#if !os(macOS) && !os(watchOS)
	public import SwiftUI
	import UIKit

	// MARK: - TextKitView (UIKit — UITextView on iOS / iPadOS / tvOS / Catalyst / visionOS)

	/// A SwiftUI view backed by the native platform rich-text view
	/// (`UITextView` on UIKit platforms, `NSTextView` on macOS) for
	/// displaying attributed text and HTML content with scrolling,
	/// text selection, and automatic link / data detection where supported.
	///
	/// Available on macOS, iOS, iPadOS, tvOS, Mac Catalyst and visionOS.
	/// **Not available on watchOS** — the file compiles to an empty stub
	/// there; use ``HtmlView`` for cross-platform inline HTML rendering.
	///
	/// ```swift
	/// var view = TextKitView()
	/// view.setHTML("<h2>Hello</h2><p>This is <b>HTML</b>.</p>")
	/// ```
	public struct TextKitView: View {

		// MARK: Properties

		var textView = UITextView()

		// MARK: Init

		/// Creates an empty `TextKitView`.  Populate it afterwards by calling
		/// ``setHTML(_:)`` with the markup to display.
		public init() {
			textView = UITextView()
		}

		// MARK: Body

		public var body: some View {
			WrapperView(view: textView)
				.ignoresSafeArea()
				.accessibilityIdentifier("TextKitView.textView")
		}

		// MARK: Public API

		/// Renders the given HTML string into the wrapped `UITextView`.
		///
		/// The HTML is decoded as UTF-8 via `NSAttributedString.DocumentType.html`;
		/// any run missing a font is back-filled with the user's preferred body
		/// font (`UIFont.preferredFont(forTextStyle: .body)`).  On platforms other
		/// than tvOS, `UIDataDetectorTypes.all` is enabled so links, dates and
		/// phone numbers become tappable.
		///
		/// - Parameter html: A self-contained HTML string (typically a full
		///   document with `<style>` for fonts and colours).
		public func setHTML(_ html: String) {
			let data = Data(html.utf8)
			let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
				.documentType: NSAttributedString.DocumentType.html,
				.characterEncoding: String.Encoding.utf8.rawValue,
			]
			if let attributed = try? NSMutableAttributedString(
				data: data, options: opts, documentAttributes: nil)
			{
				let fullRange = NSRange(location: 0, length: attributed.length)
				attributed.enumerateAttribute(.font, in: fullRange) { value, range, _ in
					if value == nil {
						attributed.addAttribute(
							.font, value: UIFont.preferredFont(forTextStyle: .body), range: range)
					}
				}
				textView.attributedText = attributed
				textView.isScrollEnabled = true
				textView.textContainer.lineFragmentPadding = 0
				textView.textContainerInset = .zero
				#if !os(tvOS)
					textView.isEditable = false
					textView.dataDetectorTypes = [.all]
				#endif
			}
		}
	}
#elseif os(macOS)
	public import SwiftUI
	import AppKit

	// MARK: - TextKitView (AppKit — NSTextView wrapped in an NSScrollView)

	/// A SwiftUI view backed by the native platform rich-text view
	/// (`UITextView` on UIKit platforms, `NSTextView` on macOS) for
	/// displaying attributed text and HTML content with scrolling,
	/// text selection, and automatic link / data detection where supported.
	///
	/// Available on macOS, iOS, iPadOS, tvOS, Mac Catalyst and visionOS.
	/// **Not available on watchOS** — the file compiles to an empty stub
	/// there; use ``HtmlView`` for cross-platform inline HTML rendering.
	///
	/// ```swift
	/// var view = TextKitView()
	/// view.setHTML("<h2>Hello</h2><p>This is <b>HTML</b>.</p>")
	/// ```
	public struct TextKitView: View {

		// MARK: Properties

		let scrollView: NSScrollView
		let textView: NSTextView

		// MARK: Init

		/// Creates an empty `TextKitView`.  Populate it afterwards by calling
		/// ``setHTML(_:)`` with the markup to display.
		public init() {
			let scroll = NSScrollView()
			scroll.hasVerticalScroller = true
			scroll.hasHorizontalScroller = false
			scroll.autohidesScrollers = true
			scroll.borderType = .noBorder
			scroll.drawsBackground = false

			let tv = NSTextView()
			tv.isEditable = false
			tv.isSelectable = true
			tv.isAutomaticLinkDetectionEnabled = true
			tv.isAutomaticDataDetectionEnabled = true
			tv.drawsBackground = false
			tv.textContainerInset = .zero
			tv.textContainer?.lineFragmentPadding = 0
			tv.autoresizingMask = [.width]

			scroll.documentView = tv
			self.scrollView = scroll
			self.textView = tv
		}

		// MARK: Body

		public var body: some View {
			WrapperView(view: scrollView)
				.ignoresSafeArea()
				.accessibilityIdentifier("TextKitView.textView")
		}

		// MARK: Public API

		/// Renders the given HTML string into the wrapped `NSTextView`.
		///
		/// The HTML is decoded as UTF-8 via `NSAttributedString.DocumentType.html`;
		/// any run missing a font is back-filled with the user's preferred body
		/// font (`NSFont.preferredFont(forTextStyle: .body, options: [:])`).
		/// Automatic link and data detection are enabled at view creation time,
		/// so URLs, dates, phone numbers and addresses become clickable.
		///
		/// - Parameter html: A self-contained HTML string (typically a full
		///   document with `<style>` for fonts and colours).
		public func setHTML(_ html: String) {
			let data = Data(html.utf8)
			let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
				.documentType: NSAttributedString.DocumentType.html,
				.characterEncoding: String.Encoding.utf8.rawValue,
			]
			if let attributed = try? NSMutableAttributedString(
				data: data, options: opts, documentAttributes: nil)
			{
				let fullRange = NSRange(location: 0, length: attributed.length)
				attributed.enumerateAttribute(.font, in: fullRange) { value, range, _ in
					if value == nil {
						attributed.addAttribute(
							.font,
							value: NSFont.preferredFont(forTextStyle: .body, options: [:]),
							range: range
						)
					}
				}
				textView.textStorage?.setAttributedString(attributed)
			}
		}
	}
#else
	import SwiftUI  // needed for #Preview on watchOS
#endif

// MARK: - Previews

#Preview("HTML") {
	#if !os(watchOS)
		let view = TextKitView()

		let css = """
			<meta name="color-scheme" content="light dark">
			<style>
			  :root { font: -apple-system-body; }
			  body {
			 color: label;
			 margin: 0;
			 padding: 0 16px;
			  }
			  a { color: link; }
			  img {
			 max-width: 100%;
			 height: auto;
			 display: block;
			 margin: 12px 0;
			 border-radius: 12px;
			  }
			  h2 { margin-top: 16px; }
			</style>
			"""

		let html = """
			<!doctype html><html><head>\(css)</head><body>
			  <h2>Hello</h2>
			  <p>This is <b>HTML</b> with an <a href="https://apple.com">Apple link</a>.</p>
			  <img src="https://picsum.photos/600/300" alt="Internet image" />
			</body></html>
			"""

		view.setHTML(html)
		return view
	#else
		Text("Not supported on watchOS — use HtmlView instead")
	#endif
}
