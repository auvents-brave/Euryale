public import Stheno
public import SwiftUI

// MARK: - NetworkAddressView

/// An address input that supports IPv4, optional IPv6, and optional domain-name resolution.
///
/// - `.ipv4Only` — shows a single IPv4 field.
/// - `.ipv4IPv6` — shows a segmented picker to switch between IPv4 and IPv6 formats.
///
/// A **Domain Name** disclosure row lets the user resolve a hostname to an IP address
/// in-place — by default via Stheno's ``DomainResolver``. Pass `domainResolver: nil` to hide it.
///
/// ```swift
/// NetworkAddressView(mode: .ipv4IPv6, address: $host, port: $port)
/// ```
public struct NetworkAddressView: View {

	// MARK: IP version mode

	/// Which IP versions the address field offers.
	public enum Mode {
		case ipv4Only
		case ipv4IPv6
	}

	// MARK: State

	private let mode: Mode
	@Binding private var address: String

	/// Optional port binding. When provided a **Port** row is shown.
	private let port: Binding<String>?

	/// When `true`, the address and domain fields are disabled but the **port stays active** —
	/// e.g. UDP broadcast, which targets the whole subnet yet still needs a port.
	private let addressDisabled: Bool

	/// Async closure resolving a hostname to IP address strings.
	/// Defaults to Stheno's ``DomainResolver/resolve(_:)``; pass `nil` to hide the domain-name row.
	private let domainResolver: ((String) async throws -> [String])?

	@State private var ipVersion: IPAddressField.Filter = .ipv4
	@State private var showDomainResolver = false
	@State private var domainName = ""
	@State private var isResolving = false
	@State private var resolveError: String?

	// MARK: Init

	/// Creates an address input.
	/// - Parameters:
	///   - mode: Which IP versions the field offers.
	///   - address: Binding to the edited address string.
	///   - port: Optional port binding; when provided a **Port** row is shown.
	///   - addressDisabled: Disables the address and domain fields while keeping the port active.
	///   - domainResolver: Resolves a hostname to IP strings; pass `nil` to hide the domain-name row.
	public init(
		mode: Mode = .ipv4Only,
		address: Binding<String>,
		port: Binding<String>? = nil,
		addressDisabled: Bool = false,
		domainResolver: ((String) async throws -> [String])? = DomainResolver.resolve
	) {
		self.mode = mode
		_address = address
		self.port = port
		self.addressDisabled = addressDisabled
		self.domainResolver = domainResolver
	}

	// MARK: Body

	public var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			if mode == .ipv4IPv6 {
				versionPicker.disabled(addressDisabled)
			}

			addressRow.disabled(addressDisabled)

			if let port {
				LabeledContent("Port") {
					IPAddressField(.port, text: port)
				}
			}

			if domainResolver != nil {
				domainRow.disabled(addressDisabled)
			}
		}
	}

	// MARK: IP version picker

	private var versionPicker: some View {
		Picker("IP Version", selection: $ipVersion) {
			Text("IPv4").tag(IPAddressField.Filter.ipv4)
			Text("IPv6").tag(IPAddressField.Filter.ipv6)
		}
		#if os(watchOS)
			.pickerStyle(.automatic)  // segmented is unavailable on watchOS
		#else
			.pickerStyle(.segmented)
		#endif
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
								.autocorrectionDisabled()
								.textInputAutocapitalization(.never)
							#endif
							.onChange(of: domainName) { _, new in
								let filtered = sanitizeHostname(new)
								if filtered != new { domainName = filtered }
							}

						Button {
							Task { await resolve() }
						} label: {
							if isResolving {
								ProgressView().controlSize(.small)
							} else {
								Text("Resolve")
							}
						}
						// Explicit style so the tap is captured here and not
						// propagated to the enclosing DisclosureGroup row (which
						// would toggle it closed).
						.buttonStyle(.borderless)
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
			default: picked = results.first
			}
			if let ip = picked {
				address = ip  // shown in the Address row above; panel stays open
			} else {
				resolveError = "No \(ipVersion == .ipv6 ? "IPv6" : "IPv4") address found."
			}
		} catch {
			resolveError = error.localizedDescription
		}
	}

	/// Keeps characters valid in a hostname: ASCII letters, digits, `.` and `-`.
	private func sanitizeHostname(_ input: String) -> String {
		input.filter { character in
			(character.isASCII && (character.isLetter || character.isNumber))
				|| character == "."
				|| character == "-"
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

#Preview("No domain row") {
	@Previewable @State var addr = ""
	Form {
		NetworkAddressView(mode: .ipv4IPv6, address: $addr, domainResolver: nil)
	}
}
