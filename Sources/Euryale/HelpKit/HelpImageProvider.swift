#if os(iOS) || os(macOS) || os(visionOS)
	internal import MarkdownUI
	public import SwiftUI

	#if canImport(UIKit)
		import UIKit
	#elseif canImport(AppKit)
		import AppKit
	#endif

	/// Resolves a help article's `images/NAME.ext` reference to the screenshot for
	/// the running platform — `NAME~mac.ext` on macOS, `NAME~iphone.ext` elsewhere
	/// — loaded from the book's localisation directory; falls back to a plain
	/// `NAME.ext` when no platform variant is present.
	///
	/// The same `![](images/NAME.ext)` Markdown drives the website (which shows
	/// both variants side by side) and the in-app help (which shows only its own).
	struct HelpImageProvider: ImageProvider {
		/// The localisation directory holding the `images/` folder, from
		/// ``HelpBook/baseURL``.
		let baseURL: URL?

		@ViewBuilder
		func makeImage(url: URL?) -> some View {
			if let image = resolved(url) {
				image
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(maxWidth: 360)
			}
		}

		/// Loads the platform variant (then the plain file) for `url`'s base name.
		/// Internal rather than private so the resolution can be unit-tested.
		func resolved(_ url: URL?) -> Image? {
			guard let baseURL, let url else { return nil }
			let stem = url.deletingPathExtension().lastPathComponent
			let ext = url.pathExtension
			#if os(macOS)
				let suffix = "mac"
			#else
				let suffix = "iphone"
			#endif
			let directory = baseURL.appendingPathComponent("images")
			for name in ["\(stem)~\(suffix).\(ext)", url.lastPathComponent] {
				guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else {
					continue
				}
				#if canImport(UIKit)
					if let image = UIImage(data: data) { return Image(uiImage: image) }
				#elseif canImport(AppKit)
					if let image = NSImage(data: data) { return Image(nsImage: image) }
				#endif
			}
			return nil
		}
	}
#endif
