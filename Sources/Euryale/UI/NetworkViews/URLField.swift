import Foundation
public import SwiftUI

/// A text field for entering a URL. It strips whitespace as you type and shows
/// whether the current text parses as a URL with a host and an accepted scheme.
///
/// By default only `http`/`https`/`ws`/`wss` are accepted. Pass a wider
/// ``schemes`` set to allow other transports (for example `tcp`/`udp`).
public struct URLField: View {

	@Binding private var text: String
	private let placeholder: String
	private let schemes: Set<String>

	/// Creates a URL field.
	/// - Parameters:
	///   - placeholder: Placeholder text shown when empty.
	///   - text: The URL string binding.
	///   - schemes: The lower-cased URL schemes considered valid. Defaults to
	///     the web schemes `http`/`https`/`ws`/`wss`.
	public init(
		_ placeholder: String = "https://example.com",
		text: Binding<String>,
		schemes: Set<String> = ["http", "https", "ws", "wss"]
	) {
		self.placeholder = placeholder
		_text = text
		self.schemes = schemes
	}

	/// The content and behaviour of the view.
	public var body: some View {
		HStack {
			TextField(placeholder, text: $text)
				.autocorrectionDisabled()
				#if os(iOS) || os(visionOS)
					.textInputAutocapitalization(.never)
					.keyboardType(.URL)
				#endif
				.onChange(of: text) { _, newValue in
					let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
					if cleaned != newValue { text = cleaned }
				}

			if !text.isEmpty {
				Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
					.foregroundStyle(isValid ? Color.green : Color.orange)
					.accessibilityHidden(true)
			}
		}
	}

	/// Whether `text` parses as a URL with a host and one of the accepted schemes.
	public var isValid: Bool {
		guard let url = URL(string: text),
			let scheme = url.scheme?.lowercased(),
			url.host?.isEmpty == false
		else { return false }
		return schemes.contains(scheme)
	}
}

#if DEBUG
	#Preview("URLField") {
		@Previewable @State var url = "https://demo.signalk.org"
		Form {
			URLField(text: $url)
		}
	}
#endif
