public import SwiftUI

// MARK: - IPAddressField

/// A text field filtered to a specific network address format.
///
/// - `.ipv4` — four segmented octets separated by visible dots (`192·168·1·1`).
///   Focus advances automatically after three digits; each octet is clamped to 0–255.
/// - `.ipv6` — a single field restricted to hex digits and colons.
/// - `.port` — a single numeric field clamped to 0–65 535.
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

    /// Internal octets for IPv4 segmented display.
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
            case .ipv4:  ipv4Field
            case .ipv6:  singleField(placeholder: "::", sanitize: sanitizeIPv6)
            case .port:  singleField(placeholder: "0", sanitize: sanitizePort)
            }
        }
        .onAppear { syncOctetsFromText() }
    }

    // MARK: IPv4 segmented field

    private var ipv4Field: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { idx in
                TextField("0", text: $octets[idx])
                    .frame(width: 36)
                    .multilineTextAlignment(.center)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .focused($octetFocus, equals: idx)
                    .onChange(of: octets[idx]) { _, new in
                        // Keep only digits, clamp to 0-255
                        let digits = String(new.filter(\.isNumber).prefix(3))
                        let clamped: String
                        if let val = Int(digits), val > 255 {
                            clamped = "255"
                        } else {
                            clamped = digits
                        }
                        if clamped != octets[idx] { octets[idx] = clamped }
                        // Auto-advance after 3 digits
                        if clamped.count == 3, idx < 3 { octetFocus = idx + 1 }
                        syncTextFromOctets()
                    }

                if idx < 3 {
                    Text(".")
                        .foregroundStyle(.secondary)
                        .onTapGesture { octetFocus = idx + 1 }
                }
            }
        }
    }

    // MARK: Generic single field

    private func singleField(placeholder: String, sanitize: @escaping (String) -> String) -> some View {
        TextField(placeholder, text: $text)
            #if os(iOS)
            .keyboardType(filter == .port ? .numberPad : .asciiCapable)
            #endif
            .onChange(of: text) { _, new in
                let s = sanitize(new)
                if s != new { text = s }
            }
    }

    // MARK: Sanitisers

    private func sanitizeIPv6(_ input: String) -> String {
        var s = String(input.filter { $0.isHexDigit || $0 == ":" })
        // Collapse triple+ colons to "::"
        while s.contains(":::") { s = s.replacingOccurrences(of: ":::", with: "::") }
        return String(s.prefix(39)) // max IPv6 string length
    }

    private func sanitizePort(_ input: String) -> String {
        let digits = String(input.filter(\.isNumber).prefix(5))
        if let val = Int(digits), val > 65_535 { return "65535" }
        return digits
    }

    // MARK: Sync helpers (octets ↔ text binding)

    private func syncTextFromOctets() {
        let joined = octets.joined(separator: ".")
        if joined != text { text = joined }
    }

    private func syncOctetsFromText() {
        let parts = text.components(separatedBy: ".").prefix(4)
        let padded = parts + Array(repeating: "", count: max(0, 4 - parts.count))
        let newOctets = padded.map { String($0.prefix(3)) }
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
