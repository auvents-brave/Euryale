public import Foundation  // UserDefaults / NSUbiquitousKeyValueStore used in public init

/// Synchronises UserDefaults with iCloud's NSUbiquitousKeyValueStore, optionally filtering keys by prefix.
///
/// Changes made on other devices are listened for automatically via notifications and propagated as appropriate.
/// `NSUbiquitousKeyValueStore` automatically syncs periodically.
/// You can call `.SyncToCloud()` manually, but it doesn't guarantee instant sync.
/// ## Usage
/// Initialise in your `AppDelegate` using:
/// ```swift
/// let sync = UserDefaultsCloudSync()
/// ```
/// to synchronise all UserDefaults, or:
/// ```swift
/// let sync = UserDefaultsCloudSync(prefix: "prefix")
/// ```
/// to synchronise only keys starting with "prefix"
public class UserDefaultsCloudSync {
    /// Initialises the sync manager.
    /// - Parameters:
    ///   - prefix: The prefix used for filtering. Defaults to `nil` (all keys synced).
    ///   - defaults: A `UserDefaults` instance. Defaults to `.standard`.
    ///   - ubiquitousStore: The iCloud KV store. Defaults to `.default`.
    public init(prefix: String? = nil,
                defaults: UserDefaults = .standard,
                ubiquitousStore: NSUbiquitousKeyValueStore = .default) {
        self.prefix = prefix
        self.defaults = defaults
        self.ubiquitousStore = ubiquitousStore

        /// Observe changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )

        /// Start syncing
        ubiquitousStore.synchronize()
    }

    /// Sync from UserDefaults to iCloud
    /// > Instant sync is not guaranteed.
    public func SyncToCloud() {
        for (key, value) in defaults.dictionaryRepresentation() {
            if IsSyncable(key) {
                ubiquitousStore.set(value, forKey: key)
            }
        }
        ubiquitousStore.synchronize()
    }

    /// Sync from iCloud to UserDefaults
    @objc internal func iCloudDidChange(_ notification: Notification) {
        for (key, _) in defaults.dictionaryRepresentation() {
            if IsSyncable(key) {
                let value = ubiquitousStore.object(forKey: key)
                defaults.set(value, forKey: key)
            }
        }
    }

    /// An optional prefix used to filter which UserDefaults keys are included in sync operations. Only keys starting with this prefix will be synced; if nil, all keys are synced.
    private let prefix: String?

    private let ubiquitousStore: NSUbiquitousKeyValueStore
    private let defaults: UserDefaults

    private func IsSyncable(_ key: String) -> Bool {
        return (prefix != nil) ? key.hasPrefix(prefix!) : true
    }
}
