import SwiftUI

#if os(macOS)
	/// Alias to unify controller references across platforms.
	typealias ViewController = NSViewController

	// MARK: - WrapperView

	/// A SwiftUI wrapper that embeds an `NSView` in SwiftUI views on macOS.
	/// - Parameter V: The type of `NSView` to be wrapped.
	struct WrapperView<V: NSView>: NSViewRepresentable {

		typealias NSViewType = V

		/// Initialises the wrapper with the specified NSView.
		/// - Parameter view: The NSView instance to embed.
		var view: V

		init(view: V) {
			self.view = view
		}

		/// Creates the wrapped NSView.
		/// - Returns: The embedded NSView instance.
		public func makeNSView(context: NSViewRepresentableContext<WrapperView>) -> V {
			return view
		}

		/// Updates the wrapped NSView (no-op here).
		public func updateNSView(_ webView: V, context: NSViewRepresentableContext<WrapperView>) {}
	}

#elseif !os(watchOS)
	/// Alias to unify controller references across platforms.
	typealias ViewController = UIViewController

	// MARK: - WrapperView

	/// A SwiftUI wrapper that embeds a `UIView` in SwiftUI views on iOS and other supported platforms.
	/// - Parameter V: The type of `UIView` to be wrapped.
	struct WrapperView<V: UIView>: UIViewRepresentable {

		/// Initialises the wrapper with the specified UIView.
		/// - Parameter view: The UIView instance to embed.
		var view: V

		init(view: V) {
			self.view = view
		}

		/// Creates the wrapped UIView.
		/// - Returns: The embedded UIView instance.
		func makeUIView(context: Context) -> V {
			return view
		}

		/// Updates the wrapped UIView (no-op here).
		func updateUIView(_ uiView: V, context: Context) {}
	}
#endif
