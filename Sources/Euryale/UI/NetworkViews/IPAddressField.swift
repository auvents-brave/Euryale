public import SwiftUI

// MARK: - IPAddressField

/// A single text field filtered to a specific network address format.
///
/// - `.ipv4` — digits and dots only, capped at four octets, each clamped to 0–255
///   (e.g. `192.168.1.1`).
/// - `.ipv6` — hex digits and colons only.
/// - `.port` — digits only, clamped to 0–65 535.
///
/// Filtering uses a get/set `Binding` so input is sanitised as you type, without
/// the character-dropping issues of the `onChange`-revert pattern.
///
/// ```swift
/// IPAddressField(.ipv4, text: $address)
/// IPAddressField(.port, text: $port)
/// ```
public struct IPAddressField: View {

    // MARK: Filter

    public enum Filter {
        case ipv4
        case ipv6
        case port
    }

    // MARK: State

    private let filter: Filter
    @Binding private var text: String

    // MARK: Init

    public init(_ filter: Filter, text: Binding<String>) {
        self.filter = filter
        _text = text
    }

    // MARK: Body

    public var body: some View {
        TextField(placeholder, text: sanitizedBinding)
            .multilineTextAlignment(.leading)
            #if os(iOS)
            .keyboardType(keyboardType)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            #endif
    }

    // MARK: Configuration per filter

    private var placeholder: String {
        switch filter {
        case .ipv4: "0.0.0.0"
        case .ipv6: "::"
        case .port: "0"
        }
    }

    #if os(iOS)
        private var keyboardType: UIKeyboardType {
            switch filter {
            case .ipv4: .numbersAndPunctuation
            case .ipv6: .asciiCapable
            case .port: .numberPad
            }
        }
    #endif

    /// A binding that mirrors `text` but sanitises every edit for the active filter.
    private var sanitizedBinding: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                switch filter {
                case .ipv4: text = sanitizeIPv4(newValue)
                case .ipv6: text = sanitizeIPv6(newValue)
                case .port: text = sanitizePort(newValue)
                }
            }
        )
    }

    // MARK: Sanitisers

    /// Builds up to four octets from the input. A dot is inserted automatically
    /// once an octet reaches three digits, so only digits need to be typed —
    /// but an explicit dot is still honoured to end a shorter octet (`1.1.1.1`).
    /// Each octet is clamped to 0–255.
    private func sanitizeIPv4(_ input: String) -> String {
        var octets: [String] = [""]
        for character in input {
            if character == "." {
                if octets.count < 4, octets[octets.count - 1].isEmpty == false {
                    octets.append("")
                }
            } else if character.isNumber {
                if octets[octets.count - 1].count == 3 {
                    // Current octet is full → auto-start the next one.
                    if octets.count < 4 { octets.append(String(character)) }
                } else {
                    var current = octets[octets.count - 1] + String(character)
                    if let value = Int(current), value > 255 { current = "255" }
                    octets[octets.count - 1] = current
                }
            }
            // Any other character is ignored.
        }
        return octets.joined(separator: ".")
    }

    /// Keeps hex digits and colons; collapses runs of 3+ colons to `::`.
    private func sanitizeIPv6(_ input: String) -> String {
        var s = String(input.filter { $0.isHexDigit || $0 == ":" })
        while s.contains(":::") { s = s.replacingOccurrences(of: ":::", with: "::") }
        return String(s.prefix(39)) // max IPv6 string length
    }

    /// Keeps digits only; clamps to 0–65 535.
    private func sanitizePort(_ input: String) -> String {
        let digits = String(input.filter(\.isNumber).prefix(5))
        if let value = Int(digits), value > 65_535 { return "65535" }
        return digits
    }
}

// MARK: - Previews

#Preview("IPv4") {
    @Previewable @State var addr = "192.168.1.1"
    Form { IPAddressField(.ipv4, text: $addr) }
}

#Preview("IPv6") {
    @Previewable @State var addr = ""
    Form { IPAddressField(.ipv6, text: $addr) }
}

#Preview("Port") {
    @Previewable @State var port = "8080"
    Form { IPAddressField(.port, text: $port) }
}
