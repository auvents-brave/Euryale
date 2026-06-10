internal import Foundation
internal import Security

// MARK: - KeychainStore

/// A small, typed wrapper around the system Keychain for storing per-item
/// secrets (access tokens, passwords) keyed by a stable string.
///
/// Secrets are stored as generic passwords scoped to a single `service`
/// namespace, with each secret addressed by an arbitrary `key` (for example a
/// connection's `UUID` string). Items are marked **synchronizable**, so they
/// ride iCloud Keychain to the user's other devices when that is enabled —
/// matching the way ``CloudKeyValueStore`` synchronises non-secret settings.
///
/// Reads and writes are synchronous and cheap; the type is a value type holding
/// only the service name, so it is freely `Sendable`.
///
/// ## Usage
/// ```swift
/// let keychain = KeychainStore(service: "com.example.app.connections")
/// keychain.setSecret(token, for: connection.id.uuidString)
/// let token = keychain.secret(for: connection.id.uuidString)
/// keychain.setSecret(nil, for: connection.id.uuidString) // delete
/// ```
public struct KeychainStore: Sendable {

	private let service: String

	/// Creates a store scoped to a Keychain service namespace.
	/// - Parameter service: A reverse-DNS identifier grouping these secrets,
	///   typically `"<bundle id>.<purpose>"`.
	public init(service: String) {
		self.service = service
	}

	/// Reads the secret stored for `key`, or `nil` when none exists.
	/// - Parameter key: The item key, unique within this store's service.
	/// - Returns: The stored secret, or `nil` if absent or undecodable.
	public func secret(for key: String) -> String? {
		var query = baseQuery(for: key)
		query[kSecMatchLimit as String] = kSecMatchLimitOne
		query[kSecReturnData as String] = kCFBooleanTrue

		var result: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &result)
		guard status == errSecSuccess,
			let data = result as? Data,
			let value = String(data: data, encoding: .utf8)
		else { return nil }
		return value
	}

	/// Stores `value` for `key`, replacing any existing secret. Passing `nil`
	/// removes the stored secret.
	/// - Parameters:
	///   - value: The secret to store, or `nil` to delete.
	///   - key: The item key, unique within this store's service.
	public func setSecret(_ value: String?, for key: String) {
		guard let value, let data = value.data(using: .utf8) else {
			SecItemDelete(baseQuery(for: key) as CFDictionary)
			return
		}

		let update: [String: Any] = [kSecValueData as String: data]
		let status = SecItemUpdate(baseQuery(for: key) as CFDictionary, update as CFDictionary)
		if status == errSecItemNotFound {
			var insert = baseQuery(for: key)
			insert[kSecValueData as String] = data
			SecItemAdd(insert as CFDictionary, nil)
		}
	}

	/// The query identifying a single synchronizable generic-password item.
	private func baseQuery(for key: String) -> [String: Any] {
		[
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: key,
			kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
		]
	}
}
