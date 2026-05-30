public import SwiftUI

// MARK: - IPAddressField

/// A single text field filtered to a specific network address format.
///
/// - `.ipv4` — digits only; a dot is inserted automatically after each 3-digit
///   octet, and an explicit dot still ends a shorter octet (`10.0.0.1`).
///   Each octet is clamped to 0–255, four octets max.
/// - `.ipv6` — hex digits and colons only.
/// - `.port` — digits only, clamped to 0–65 535.
///
/// Uses a local display buffer with insertion/deletion detection so the
/// automatic dot never fights the Delete key.
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
    @State private var display: String = ""

    // MARK: Init

    public init(_ filter: Filter, text: Binding<String>) {
        self.filter = filter
        _text = text
    }

    // MARK: Body

    public var body: some View {
        TextField(placeholder, text: $display)
            .multilineTextAlignment(.leading)
            #if os(iOS)
            .keyboardType(keyboardType)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            #endif
            .onAppear { display = text }
            .onChange(of: display) { old, new in
                let formatted = format(new, inserting: new.count > old.count)
                if formatted != new { display = formatted }
                if formatted != text { text = formatted }
            }
            .onChange(of: text) { _, new in
                // Reflect external programmatic changes (e.g. a reset).
                if new != display { display = new }
            }
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

    // MARK: Formatting

    private func format(_ input: String, inserting: Bool) -> String {
        switch filter {
        case .ipv4: formatIPv4(input, inserting: inserting)
        case .ipv6: sanitizeIPv6(input)
        case .port: sanitizePort(input)
        }
    }

    /// Groups digits into up to four octets (≤ 3 digits, ≤ 255 each).
    /// On insertion only, appends a dot once an octet fills up — so the dot
    /// appears right after the 3rd digit, yet Delete can still remove it.
    private func formatIPv4(_ input: String, inserting: Bool) -> String {
        var octets: [String] = [""]
        for character in input {
            if character == "." {
                if octets.count < 4, octets[octets.count - 1].isEmpty == false {
                    octets.append("")
                }
            } else if character.isNumber {
                if octets[octets.count - 1].count == 3 {
                    if octets.count < 4 { octets.append(String(character)) }
                } else {
                    var current = octets[octets.count - 1] + String(character)
                    if let value = Int(current), value > 255 { current = "255" }
                    octets[octets.count - 1] = current
                }
            }
        }
        var result = octets.joined(separator: ".")
        if inserting, octets.count < 4, octets[octets.count - 1].count == 3 {
            result += "."
        }
        return result
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
