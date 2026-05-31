public import Foundation
import Stheno

/**
 Extension to Bundle to access application name from the app's Info.plist.

 Provides convenient accessors for an app's user-visible name and a helper to synchronise the displayed version into Settings.bundle using UserDefaults.
 This extension adds `displayName` lookup (preferring localised values) and a `synchronizeDisplayedVersion(…)` utility for settings surfaces.
 ## Usage
 ```swift
 let name = Bundle.main.displayName
 ```
 > Tip: To show the version string on the application's Settings pane, see <doc:DisplayAppVersion>.
 */

// MARK: - Bundle + DisplayName

extension Bundle {

    // MARK: Public API

    /// The user-visible application name from Info.plist.
    /// 	This file adds a computed property on `Bundle` that returns the user‑visible
    /// 	application name. It looks up `CFBundleDisplayName` first and falls back to
    /// 	`CFBundleName` when a display name isn't provided. Localised values are
    /// 	preferred when available.
    ///
    /// 	The lookup order is:
    /// 	1. `localizedInfoDictionary["CFBundleDisplayName"]`
    /// 	2. `infoDictionary["CFBundleDisplayName"]`
    /// 	3. `localizedInfoDictionary["CFBundleName"]`
    /// 	4. `infoDictionary["CFBundleName"]`
    /// 	5. `ProcessInfo.processName` (as a last resort)

    /// 	Use this to consistently present the app's name in UI, settings, logs, or
    /// 	diagnostics, regardless of whether the name is localised or configured via
    /// 	`CFBundleDisplayName`.
    public var displayName: String {
        return DisplayName.getDisplayName(self)
    }

    /// Writes ``displayedVersion`` (the `"x.y.z (build)"` string from Stheno's
    /// `Bundle` extension) to `UserDefaults` so a `Settings.bundle` entry can
    /// display the running app version on the iOS Settings pane.
    ///
    /// Call this once at startup, typically from the `App` initialiser:
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///     init() { Bundle.main.synchronizeDisplayedVersion() }
    ///     ...
    /// }
    /// ```
    ///
    /// Pair with a `PSTitleValueSpecifier` entry in `Settings.bundle/Root.plist`
    /// whose `Key` matches `key`.  See <doc:DisplayAppVersion> for the complete
    /// setup recipe.
    ///
    /// - Parameters:
    ///   - key: `UserDefaults` key to write the version string under.
    ///          Defaults to `"version"`.
    ///   - defaults: `UserDefaults` instance to write to. Defaults to `.standard`.
    public func synchronizeDisplayedVersion(
        key: String = "version",
        in defaults: UserDefaults = .standard
    ) {
        defaults.set(displayedVersion, forKey: key)
    }
}

// MARK: - BundleInfoProviding

internal protocol BundleInfoProviding {
    var infoDictionary: [String: Any]? { get }
    var localizedInfoDictionary: [String: Any]? { get }
}

// MARK: - Bundle + BundleInfoProviding

extension Bundle: BundleInfoProviding {}

// MARK: - DisplayName

internal struct DisplayName {
    static func getDisplayName(_ bundle: any BundleInfoProviding) -> String {
        guard let localizedDisplayName = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String else {
            guard let displayName = bundle.infoDictionary?["CFBundleDisplayName"] as? String else {
                guard let localizedBundleName = bundle.localizedInfoDictionary?["CFBundleName"] as? String else {
                    guard let bundleName = bundle.infoDictionary?["CFBundleName"] as? String else {
                        return ProcessInfo.processInfo.processName
                    }
                    return bundleName
                }
                return localizedBundleName
            }
            return displayName
        }
        return localizedDisplayName
    }
}
