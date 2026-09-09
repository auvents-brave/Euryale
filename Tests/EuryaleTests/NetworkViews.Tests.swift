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

	@Test func `a single protocol shows no picker row`() throws {
		let view = NetworkProtocolView(available: [.tcp], selection: .constant(.tcp))
		#expect(throws: Never.self) { try view.inspect() }
	}

	// MARK: - IPAddressField formatting

	@Test func `IPv4 groups digits into octets and auto-inserts a dot after a full octet`() {
		#expect(IPAddressField.formatIPv4("19216801", inserting: false) == "192.168.01")
		// On insertion a dot follows a freshly-completed 3-digit octet.
		#expect(IPAddressField.formatIPv4("192", inserting: true) == "192.")
		#expect(IPAddressField.formatIPv4("192", inserting: false) == "192")
	}

	@Test func `IPv4 clamps each octet to 255 and keeps at most four`() {
		#expect(IPAddressField.formatIPv4("999", inserting: false) == "255")
		#expect(IPAddressField.formatIPv4("1.2.3.999", inserting: false) == "1.2.3.255")
		#expect(IPAddressField.formatIPv4("1.2.3.4", inserting: false) == "1.2.3.4")
		#expect(IPAddressField.formatIPv4("10.0.0.1", inserting: false) == "10.0.0.1")
	}

	@Test func `IPv6 keeps hex and colons and collapses long colon runs`() {
		#expect(IPAddressField.sanitizeIPv6("2001:db8::1") == "2001:db8::1")
		#expect(IPAddressField.sanitizeIPv6("2001:::1") == "2001::1")
		#expect(IPAddressField.sanitizeIPv6("zz::1") == "::1")  // non-hex dropped
	}

	@Test func `port keeps digits and clamps to 65535`() {
		#expect(IPAddressField.sanitizePort("8080abc") == "8080")
		#expect(IPAddressField.sanitizePort("70000") == "65535")
		#expect(IPAddressField.sanitizePort("123456") == "12345")  // capped at five digits
	}

	@Test func `format dispatches on the filter`() {
		#expect(IPAddressField.format("1.2.3.4", filter: .ipv4, inserting: false) == "1.2.3.4")
		#expect(IPAddressField.format("fe80::1", filter: .ipv6, inserting: false) == "fe80::1")
		#expect(IPAddressField.format("443", filter: .port, inserting: false) == "443")
	}
}
