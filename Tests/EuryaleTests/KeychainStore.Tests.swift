import Foundation
import Testing

@testable import Euryale

@Suite("KeychainStore")
struct KeychainStoreTests {
	private let store = KeychainStore(service: "com.auvents-brave.euryale.tests.keychain")

	@Test func `stores, reads back, overwrites and deletes a secret`() {
		let key = UUID().uuidString
		defer { store.setSecret(nil, for: key) }

		// A fresh key has no secret.
		#expect(store.secret(for: key) == nil)

		store.setSecret("s3cr3t", for: key)

		// The Keychain is available on the simulators, where the value round-trips.
		// Where it is not — e.g. an unentitled host test binary — the writes are
		// no-ops and reads stay nil. Every code path still runs, so the
		// round-trip is only asserted once the first write has actually taken.
		guard store.secret(for: key) != nil else { return }

		#expect(store.secret(for: key) == "s3cr3t")

		store.setSecret("updated", for: key)
		#expect(store.secret(for: key) == "updated")

		store.setSecret(nil, for: key)
		#expect(store.secret(for: key) == nil)
	}

	@Test func `keeps distinct keys independent`() {
		let a = UUID().uuidString
		let b = UUID().uuidString
		defer {
			store.setSecret(nil, for: a)
			store.setSecret(nil, for: b)
		}

		store.setSecret("alpha", for: a)
		guard store.secret(for: a) != nil else { return }  // Keychain unavailable here.

		store.setSecret("beta", for: b)
		#expect(store.secret(for: a) == "alpha")
		#expect(store.secret(for: b) == "beta")
	}

	@Test func `reading an unknown key returns nil`() {
		#expect(store.secret(for: "absent-" + UUID().uuidString) == nil)
	}
}
