public import SwiftUI

// MARK: - IPAddressField

/// A text field filtered to a specific network address format.
///
/// - `.ipv4` — four segmented octets separated by visible dots (`192·168·1·1`).
///   Focus advances automatically after three digits; each octet is clamped to 0–255.
/// - `.ipv6` — a single field restricted to hex digits and colons.
/// - `.port` — a single numeric field clamped to 0–65 535.
///
/// Filtering uses get/set `Binding`s so input is sanitised as you type without
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

    /// Octet strings backing the IPv4 segmented display (source of truth for `.ipv4`).
    @State private var octets: [String] = ["", "", "", ""]
    @FocusState private var octetFocus: Int?

    // MARK: Init

    public init(_ filter: Filter, text: Binding<String>) {
        self.filter = filter
        _text = text
    }

    // MARK: Body

    public var body: some View {
        Group {
            switch filter {
            case .ipv4:
                ipv4Field
            case .ipv6:
                TextField("::", text: sanitizing(sanitizeIPv6))
                    #if os(iOS)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    #endif
            case .port:
                TextField("0", text: sanitizing(sanitizePort))
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }
        }
        .onAppear { syncOctetsFromText() }
    }

    // MARK: IPv4 segmented field

    private var ipv4Field: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { idx in
                TextField("0", text: octetBinding(idx))
                    .frame(width: 44)
                    .multilineTextAlignment(.center)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .focused($octetFocus, equals: idx)

                if idx < 3 {
                    Text(".")
                        .foregroundStyle(.secondary)
                        .onTapGesture { octetFocus = idx + 1 }
                }
            }
        }
    }

    // MARK: Bindings

    /// A binding that mirrors `text` but runs `sanitize` on every edit.
    private func sanitizing(_ sanitize: @escaping (String) -> String) -> Binding<String> {
        Binding(
            get: { text },
            set: { text = sanitize($0) }
        )
    }

    /// A binding for one IPv4 octet: clamps to 0–255, rebuilds `text`, auto-advances focus.
    private func octetBinding(_ idx: Int) -> Binding<String> {
        Binding(
            get: { octets[idx] },
            set: { newValue in
                let clamped = clampOctet(newValue)
                octets[idx] = clamped
                text = octets.joined(separator: ".")
                if clamped.count == 3, idx < 3 { octetFocus = idx + 1 }
            }
        )
    }

    // MARK: Sanitisers

    private func clampOctet(_ input: String) -> String {
        let digits = String(input.filter(\.isNumber).prefix(3))
        if let value = Int(digits), value > 255 { return "255" }
        return digits
    }

    private func sanitizeIPv6(_ input: String) -> String {
        var s = String(input.filter { $0.isHexDigit || $0 == ":" })
        while s.contains(":::") { s = s.replacingOccurrences(of: ":::", with: "::") }
        return String(s.prefix(39)) // max IPv6 string length
    }

    private func sanitizePort(_ input: String) -> String {
        let digits = String(input.filter(\.isNumber).prefix(5))
        if let value = Int(digits), value > 65_535 { return "65535" }
        return digits
    }

    // MARK: Seed octets from an incoming IPv4 string

    private func syncOctetsFromText() {
        guard filter == .ipv4 else { return }
        let parts = text.components(separatedBy: ".").prefix(4)
        let padded = parts + Array(repeating: "", count: max(0, 4 - parts.count))
        let newOctets = padded.map { clampOctet(String($0)) }
        if newOctets != octets { octets = newOctets }
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
