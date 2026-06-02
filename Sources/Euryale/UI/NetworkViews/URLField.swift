public import SwiftUI

import Foundation

/// A text field for entering a URL. It strips whitespace as you type and shows
/// whether the current text parses as a valid `http`/`https`/`ws`/`wss` URL.
public struct URLField: View {

    @Binding private var text: String
    private let placeholder: String

    /// Creates a URL field.
    /// - Parameters:
    ///   - placeholder: Placeholder text shown when empty.
    ///   - text: The URL string binding.
    public init(_ placeholder: String = "https://example.com", text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }

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

    /// Whether `text` parses as a URL with a supported scheme and a host.
    public var isValid: Bool {
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              url.host?.isEmpty == false
        else { return false }
        return ["http", "https", "ws", "wss"].contains(scheme)
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
