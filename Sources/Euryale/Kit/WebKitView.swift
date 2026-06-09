public import SwiftUI

#if os(tvOS) || os(watchOS)
  // MARK: - WebKitView

  /// On tvOS and watchOS, this view displays a placeholder indicating lack of WebKit support.
  public struct WebKitView: View {

    /// Creates a non-functional WebKitView for unsupported platforms.
    ///
    /// - Parameter url: The URL that would have been loaded, ignored on unsupported platforms.
    public init(url: URL) {
    }

    /// The content and behaviour of the view.
    public var body: some View {
      Text("Not supported", bundle: .module)
        .ignoresSafeArea()
        .accessibilityIdentifier("WebKitView.webView")
    }
  }
#else
  import WebKit

  // MARK: - WebKitView

  /// On iOS, macOS, and compatible platforms, this view loads a URL or string into a WKWebView.
  public struct WebKitView: View {

    var web = WKWebView()

    /// Initialises a WebKitView to load the specified URL.
    ///
    /// - Parameter url: The URL to display in the embedded WKWebView.
    public init(url: URL) {
      web.load(URLRequest(url: url))
    }

    /// Initialises a WebKitView to load a given URL string.
    ///
    /// - Parameter string: A string convertible to a valid URL to load in the WKWebView.
    public init(string: String) {
      self.init(url: URL(string: string)!)
    }

    /// The content and behaviour of the view.
    public var body: some View {
      WrapperView(view: web)
        .ignoresSafeArea()
        .accessibilityIdentifier("WebKitView.webView")
    }
  }
#endif

// MARK: - Previews

#Preview {
  WebKitView(url: URL(string: "https://example.com")!)
}
