public import Foundation  // UserDefaults / NSUbiquitousKeyValueStore used in public API

// MARK: - CloudKeyValueStore

/// A typed, main-actor wrapper around iCloud's `NSUbiquitousKeyValueStore`.
///
/// Use this when an app keeps its own typed settings model and only needs the
/// iCloud key-value mechanism underneath: typed reads and writes, plus a
/// callback delivering the keys an other device changed.
///
/// External changes are observed automatically and reported through
/// ``onExternalChange``, always on the main actor, carrying **only** the keys
/// that actually changed (read from `NSUbiquitousKeyValueStoreChangedKeysKey`).
/// `NSUbiquitousKeyValueStore` syncs periodically on its own; ``sync()`` only
/// flushes pending writes and does not guarantee instant propagation.
///
/// ## Usage
/// ```swift
/// let cloud = CloudKeyValueStore()
/// cloud.onExternalChange = { keys in /* re-read the changed keys */ }
/// let enabled = cloud.bool(forKey: "enabled", default: true)
/// cloud.set(false, forKey: "enabled")
/// ```
@MainActor
public final class CloudKeyValueStore {

	/// Creates a store and starts observing external iCloud changes.
	/// - Parameter store: The iCloud KV store. Defaults to `.default`.
	public init(store: NSUbiquitousKeyValueStore = .default) {
		self.store = store
		store.synchronize()
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(storeDidChangeExternally(_:)),
			name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
			object: store
		)
	}

	/// Called on the main actor whenever an other device changes values, with
	/// the set of keys that changed. Assign a handler to react to remote edits.
	public var onExternalChange: (@MainActor (Set<String>) -> Void)?

	// MARK: Typed reads

	/// Returns whether a value exists for `key`.
	public func contains(_ key: String) -> Bool {
		store.object(forKey: key) != nil
	}

	/// Reads a boolean, coercing `NSNumber`-backed values, or `defaultValue` when absent.
	public func bool(forKey key: String, default defaultValue: Bool) -> Bool {
		guard let value = store.object(forKey: key) else { return defaultValue }
		if let value = value as? Bool { return value }
		if let number = value as? NSNumber { return number.boolValue }
		return defaultValue
	}

	/// Reads an integer, coercing `NSNumber`- or `String`-backed values, or `defaultValue` when absent.
	public func int(forKey key: String, default defaultValue: Int) -> Int {
		guard let value = store.object(forKey: key) else { return defaultValue }
		if let value = value as? Int { return value }
		if let number = value as? NSNumber { return number.intValue }
		if let text = value as? String, let parsed = Int(text) { return parsed }
		return defaultValue
	}

	/// Reads a string, or `defaultValue` when absent.
	public func string(forKey key: String, default defaultValue: String) -> String {
		store.string(forKey: key) ?? defaultValue
	}

	/// Reads raw data, or `nil` when absent.
	public func data(forKey key: String) -> Data? {
		store.data(forKey: key)
	}

	// MARK: Typed writes

	/// Stores a boolean for `key`.
	public func set(_ value: Bool, forKey key: String) {
		store.set(value, forKey: key)
	}

	/// Stores an integer for `key`.
	public func set(_ value: Int, forKey key: String) {
		store.set(Int64(value), forKey: key)
	}

	/// Stores a string for `key`.
	public func set(_ value: String, forKey key: String) {
		store.set(value, forKey: key)
	}

	/// Stores data for `key`, or removes the value when `nil`.
	public func set(_ value: Data?, forKey key: String) {
		if let value {
			store.set(value, forKey: key)
		} else {
			store.removeObject(forKey: key)
		}
	}

	/// Flushes pending writes to iCloud. Instant propagation is not guaranteed.
	public func sync() {
		store.synchronize()
	}

	@objc private nonisolated func storeDidChangeExternally(_ notification: Notification) {
		guard let raw = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
			!raw.isEmpty
		else { return }
		let keys = Set(raw)
		Task { @MainActor in
			self.onExternalChange?(keys)
		}
	}

	private let store: NSUbiquitousKeyValueStore
}

// MARK: - UserDefaultsCloudSync

/// Mirrors `UserDefaults` with iCloud's `NSUbiquitousKeyValueStore`, optionally
/// filtering keys by prefix.
///
/// This is the "mirror everything" convenience: use it when an app stores its
/// settings in `UserDefaults` and wants them shadowed to iCloud transparently.
/// For a typed model that owns its own state, prefer ``CloudKeyValueStore``.
///
/// Changes made on other devices are observed automatically and the affected
/// keys are pulled back into `UserDefaults`. `NSUbiquitousKeyValueStore` syncs
/// periodically on its own; you may call ``sync()`` to push local values, but
/// instant propagation is not guaranteed.
///
/// ## Usage
/// Initialise in your `AppDelegate` using:
/// ```swift
/// let sync = UserDefaultsCloudSync()
/// ```
/// to synchronise all keys, or:
/// ```swift
/// let sync = UserDefaultsCloudSync(prefix: "prefix")
/// ```
/// to synchronise only keys starting with `"prefix"`.
@MainActor
public final class UserDefaultsCloudSync {

	/// Initialises the sync manager and starts observing external iCloud changes.
	/// - Parameters:
	///   - prefix: The prefix used for filtering. Defaults to `nil` (all keys synced).
	///   - defaults: A `UserDefaults` instance. Defaults to `.standard`.
	///   - ubiquitousStore: The iCloud KV store. Defaults to `.default`.
	public init(
		prefix: String? = nil,
		defaults: UserDefaults = .standard,
		ubiquitousStore: NSUbiquitousKeyValueStore = .default
	) {
		self.prefix = prefix
		self.defaults = defaults
		self.ubiquitousStore = ubiquitousStore

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(ubiquitousStoreDidChange(_:)),
			name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
			object: ubiquitousStore
		)

		ubiquitousStore.synchronize()
	}

	/// Pushes the syncable `UserDefaults` values to iCloud.
	/// > Instant sync is not guaranteed.
	public func sync() {
		for (key, value) in defaults.dictionaryRepresentation() where isSyncable(key) {
			ubiquitousStore.set(value, forKey: key)
		}
		ubiquitousStore.synchronize()
	}

	@objc private nonisolated func ubiquitousStoreDidChange(_ notification: Notification) {
		guard let raw = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
			!raw.isEmpty
		else { return }
		Task { @MainActor in
			self.pull(keys: raw)
		}
	}

	/// Pulls the given iCloud keys back into `UserDefaults`. Reading the keys
	/// reported by the notification — rather than the local keys — is what lets
	/// values that exist only in iCloud (e.g. on a fresh device) propagate down.
	private func pull(keys: [String]) {
		for key in keys where isSyncable(key) {
			defaults.set(ubiquitousStore.object(forKey: key), forKey: key)
		}
	}

	private func isSyncable(_ key: String) -> Bool {
		guard let prefix else { return true }
		return key.hasPrefix(prefix)
	}

	/// An optional prefix filtering which keys take part in sync. Only keys
	/// starting with this prefix are synced; if `nil`, all keys are synced.
	private let prefix: String?

	private let ubiquitousStore: NSUbiquitousKeyValueStore
	private let defaults: UserDefaults
}
