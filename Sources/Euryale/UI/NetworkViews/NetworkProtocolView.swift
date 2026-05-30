public import SwiftUI

// MARK: - NetworkProtocol

/// A network transport protocol.
public enum NetworkProtocol: String, CaseIterable, Hashable, Identifiable {
    case tcp           = "TCP"
    case udpBroadcast  = "UDP Broadcast"
    case udpMulticast  = "UDP Multicast"

    public var id: String { rawValue }

    /// Whether this protocol uses broadcast addressing (disables the address field).
    public var isBroadcast: Bool { self == .udpBroadcast }
}

// The selector view relies on DisclosureGroup / segmented Picker — unavailable on
// tvOS/watchOS. The `NetworkProtocol` enum above stays available on every platform.
#if !os(tvOS) && !os(watchOS)

// MARK: - NetworkProtocolView

/// A protocol selector that adapts its presentation to the number of available options.
///
/// - **One** available protocol — no row is shown (nothing to choose).
/// - **Two or three** protocols — displayed as a `Picker` (segmented on iOS, radio on macOS).
///
/// When ``NetworkProtocol/udpBroadcast`` is selected the `addressDisabled` binding
/// is set to `true` so the caller can disable the address field.
///
/// Pass `bonjourServiceTypes` to add an optional Bonjour service-type picker.
///
/// ```swift
/// NetworkProtocolView(
///     available:           [.tcp, .udpBroadcast, .udpMulticast],
///     selection:           $proto,
///     addressDisabled:     $broadcastActive,
///     bonjourServiceTypes: ["_http._tcp", "_nmea._tcp"]
/// )
/// ```
public struct NetworkProtocolView: View {

    // MARK: State

    private let available: [NetworkProtocol]
    @Binding private var selection: NetworkProtocol
    @Binding private var addressDisabled: Bool

    /// Optional list of Bonjour service-type identifiers (e.g. `"_http._tcp"`).
    /// When non-nil a **Bonjour** disclosure row is shown.
    private let bonjourServiceTypes: [String]?
    @Binding private var selectedBonjourType: String?

    @State private var showBonjour = false

    // MARK: Init

    public init(
        available: [NetworkProtocol],
        selection: Binding<NetworkProtocol>,
        addressDisabled: Binding<Bool> = .constant(false),
        bonjourServiceTypes: [String]? = nil,
        selectedBonjourType: Binding<String?> = .constant(nil)
    ) {
        self.available = available
        _selection = selection
        _addressDisabled = addressDisabled
        self.bonjourServiceTypes = bonjourServiceTypes
        _selectedBonjourType = selectedBonjourType
    }

    // MARK: Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            protocolRow
            if let types = bonjourServiceTypes { bonjourRow(types) }
        }
        .onChange(of: selection) { _, new in
            addressDisabled = new.isBroadcast
        }
        .onAppear { addressDisabled = selection.isBroadcast }
    }

    // MARK: Protocol picker / label

    @ViewBuilder
    private var protocolRow: some View {
        // A single protocol means there's nothing to choose — show no row.
        if available.count > 1 {
            LabeledContent("Protocol") {
                Picker("Protocol", selection: $selection) {
                    ForEach(available) { proto in
                        Text(proto.rawValue).tag(proto)
                    }
                }
                #if os(macOS)
                .pickerStyle(.radioGroup)
                #else
                .pickerStyle(.segmented)
                #endif
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    // MARK: Bonjour row

    private func bonjourRow(_ types: [String]) -> some View {
        DisclosureGroup(
            isExpanded: $showBonjour,
            content: {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(types, id: \.self) { type in
                        HStack {
                            Text(type).font(.callout)
                            Spacer()
                            if selectedBonjourType == type {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedBonjourType = type }
                    }
                }
                .padding(.top, 4)
            },
            label: {
                Label {
                    Text("Bonjour")
                    if let sel = selectedBonjourType {
                        Text(sel).font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "bonjour")
                }
                .foregroundStyle(.secondary)
            }
        )
    }
}

// MARK: - Previews

#Preview("TCP only") {
    @Previewable @State var proto = NetworkProtocol.tcp
    @Previewable @State var disabled = false
    Form {
        NetworkProtocolView(available: [.tcp], selection: $proto, addressDisabled: $disabled)
        NetworkAddressView(address: .constant("192.168.1.1"))
            .disabled(disabled)
    }
}

#Preview("TCP + UDP Broadcast — IPv4 / IPv6") {
    @Previewable @State var proto = NetworkProtocol.tcp
    @Previewable @State var addr = ""
    @Previewable @State var disabled = false
    Form {
        NetworkProtocolView(available: [.tcp, .udpBroadcast], selection: $proto, addressDisabled: $disabled)
        NetworkAddressView(mode: .ipv4IPv6, address: $addr)
            .disabled(disabled)
    }
}

#Preview("Full — TCP / Broadcast / Multicast + Bonjour") {
    @Previewable @State var proto = NetworkProtocol.tcp
    @Previewable @State var addr = ""
    @Previewable @State var disabled = false
    @Previewable @State var bonjourType: String? = nil
    Form {
        NetworkProtocolView(
            available: [.tcp, .udpBroadcast, .udpMulticast],
            selection: $proto,
            addressDisabled: $disabled,
            bonjourServiceTypes: ["_http._tcp", "_nmea._tcp", "_signalk._tcp"],
            selectedBonjourType: $bonjourType
        )
        NetworkAddressView(mode: .ipv4IPv6, address: $addr)
            .disabled(disabled)
    }
}

#Preview("Full + Domain Name") {
    @Previewable @State var proto = NetworkProtocol.tcp
    @Previewable @State var addr = ""
    @Previewable @State var disabled = false
    Form {
        NetworkProtocolView(available: [.tcp, .udpMulticast], selection: $proto, addressDisabled: $disabled)
        NetworkAddressView(
            mode: .ipv4IPv6,
            address: $addr,
            domainResolver: { _ in
                try await Task.sleep(for: .milliseconds(800))
                return ["93.184.216.34"]
            }
        )
        .disabled(disabled)
    }
}

#endif
