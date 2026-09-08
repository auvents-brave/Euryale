import SwiftUI
import Testing
import ViewInspector

@testable import Euryale

// Renders the network address / protocol views so their body — the protocol,
// address, port, domain-name and Bonjour rows — is evaluated. Rendering-independent
// (ViewInspector), so it runs identically on every destination.
@MainActor
@Suite("Network views")
struct NetworkViewsTests {

	@Test func `NetworkAddressView renders its address, port and domain rows`() throws {
		let view = NetworkAddressView(
			mode: .ipv4IPv6, address: .constant("10.0.0.1"), port: .constant("2000"))
		let texts = try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
		// The version picker's IPv4 / IPv6 labels are always present.
		#expect(texts.contains("IPv4"))
		#expect(texts.contains("IPv6"))
	}

	@Test func `NetworkAddressView without a port or domain row still renders`() throws {
		let view = NetworkAddressView(mode: .ipv4Only, address: .constant(""), domainResolver: nil)
		#expect(try view.inspect().findAll(ViewType.Text.self).isEmpty == false)
	}

	@Test func `NetworkProtocolView renders the protocol picker and Bonjour row`() throws {
		let view = NetworkProtocolView(
			available: [.tcp, .udpBroadcast, .udpMulticast],
			selection: .constant(.tcp),
			bonjourServiceTypes: ["_signalk-ws._tcp"]
		)
		let images = try view.inspect().findAll(ViewType.Image.self).compactMap { try? $0.actualImage().name() }
		#expect(images.contains("bonjour"))
	}
}
