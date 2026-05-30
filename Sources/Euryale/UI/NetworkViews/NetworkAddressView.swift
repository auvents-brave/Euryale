public import SwiftUI

// MARK: - NetworkAddressView

/// An address input that supports IPv4, optional IPv6, and optional domain-name resolution.
///
/// - `.ipv4Only` — shows a single IPv4 field.
/// - `.ipv4IPv6` — shows a segmented picker to switch between IPv4 and IPv6 formats.
///
/// When a `domainResolver` closure is provided a **Domain Name** disclosure row appears
/// where the user can type a hostname and resolve it to an IP address in-place.
///
/// ```swift
/// NetworkAddressView(
///     mode: .ipv4IPv6,
///     address: $host,
///     domainResolver: DomainResolver.resolve   // from Stheno
/// )
/// ```
public struct NetworkAddressView: View {

    // MARK: IP version mode

    public enum Mode {
        case ipv4Only
        case ipv4IPv6
    }

    // MARK: State

    private let mode: Mode
    @Binding private var address: String

    /// Optional port binding. When provided a **Port** row is shown.
    private let port: Binding<String>?

    /// Optional async closure that resolves a hostname to IP address strings.
    /// Pass `nil` to hide the domain-name row.
    private let domainResolver: ((String) async throws -> [String])?

    @State private var ipVersion: IPAddressField.Filter = .ipv4
    @State private var showDomainResolver = false
    @State private var domainName = ""
    @State private var isResolving = false
    @State private var resolveError: String?

    // MARK: Init

    public init(
        mode: Mode = .ipv4Only,
        address: Binding<String>,
        port: Binding<String>? = nil,
        domainResolver: ((String) async throws -> [String])? = nil
    ) {
        self.mode = mode
        _address = address
        self.port = port
        self.domainResolver = domainResolver
    }

    // MARK: Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if mode == .ipv4IPv6 {
                versionPicker
            }

            addressRow

            if let port {
                LabeledContent("Port") {
                    IPAddressField(.port, text: port)
                }
            }

            if domainResolver != nil {
                domainRow
            }
        }
    }

    // MARK: IP version picker

    private var versionPicker: some View {
        Picker("IP Version", selection: $ipVersion) {
            Text("IPv4").tag(IPAddressField.Filter.ipv4)
            Text("IPv6").tag(IPAddressField.Filter.ipv6)
        }
        .pickerStyle(.segmented)
        .onChange(of: ipVersion) { _, _ in address = "" }
    }

    // MARK: Address field

    private var addressRow: some View {
        LabeledContent("Address") {
            IPAddressField(ipVersion, text: $address)
        }
    }

    // MARK: Domain name resolver

    private var domainRow: some View {
        DisclosureGroup(
            isExpanded: $showDomainResolver,
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("example.com", text: $domainName)
                            #if os(iOS)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            #endif

                        Button {
                            Task { await resolve() }
                        } label: {
                            if isResolving {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Resolve")
                            }
                        }
                        .disabled(domainName.isEmpty || isResolving)
                    }

                    if let error = resolveError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.top, 4)
            },
            label: {
                Label("Domain Name", systemImage: "network")
                    .foregroundStyle(.secondary)
            }
        )
    }

    // MARK: Resolution

    @MainActor
    private func resolve() async {
        guard let resolver = domainResolver else { return }
        isResolving = true
        resolveError = nil
        defer { isResolving = false }

        do {
            let results = try await resolver(domainName)
            // Pick the address matching the selected IP version
            let picked: String?
            switch ipVersion {
            case .ipv4: picked = results.first { $0.contains(".") }
            case .ipv6: picked = results.first { $0.contains(":") }
            default:    picked = results.first
            }
            if let ip = picked {
                address = ip
                showDomainResolver = false
            } else {
                resolveError = "No \(ipVersion == .ipv6 ? "IPv6" : "IPv4") address found."
            }
        } catch {
            resolveError = error.localizedDescription
        }
    }
}

// MARK: - Previews

#Preview("IPv4 + Port") {
    @Previewable @State var addr = ""
    @Previewable @State var port = "8080"
    Form { NetworkAddressView(address: $addr, port: $port) }
}

#Preview("IPv4 + IPv6 + Port") {
    @Previewable @State var addr = ""
    @Previewable @State var port = ""
    Form { NetworkAddressView(mode: .ipv4IPv6, address: $addr, port: $port) }
}

#Preview("With domain resolver") {
    @Previewable @State var addr = ""
    Form {
        NetworkAddressView(
            mode: .ipv4IPv6,
            address: $addr,
            domainResolver: { _ in
                try await Task.sleep(for: .seconds(1))
                return ["93.184.216.34", "2606:2800:21f:cb07:6820:80da:af6b:8b2c"]
            }
        )
    }
}
