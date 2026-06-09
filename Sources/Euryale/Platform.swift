/// Cross-platform typealiases that resolve to the native equivalent on each
/// Apple OS.  Use these in code shared between iOS / iPadOS / tvOS / watchOS /
/// visionOS / Mac Catalyst / macOS to avoid platform-conditional `#if` blocks
/// at every reference site.
///
/// | Type alias        | watchOS         | iOS / tvOS / Catalyst / vision | macOS         |
/// |-------------------|-----------------|--------------------------------|---------------|
/// | ``PlatformApplication`` | `WKExtension`   | `UIApplication`                | `NSApplication` |
/// | ``PlatformDelegate``    | `NSObject`      | `UIResponder`                  | `NSObject`    |
/// | ``PlatformView``        | *unavailable*   | `UIView`                       | `NSView`      |
/// | ``PlatformColor``       | `UIColor`       | `UIColor`                      | `NSColor`     |
/// | ``PlatformImage``       | `UIImage`       | `UIImage`                      | `NSImage`     |
/// | ``PlatformFont``        | `UIFont`        | `UIFont`                       | `NSFont`      |
///
/// Use ``PlatformApplication/platformShared`` to access the singleton application
/// instance without writing platform branches:
///
/// ```swift
/// PlatformApplication.platformShared.openURL(url)
/// ```

import Foundation

// MARK: - Per-platform typealiases

#if canImport(WatchKit)
    public import WatchKit // WKExtension and UIColor/UIImage/UIFont used in public typealiases

    /// Singleton-style application class — `WKExtension` on watchOS.
    public typealias PlatformApplication = WKApplication
    /// Native colour type — `UIColor` on watchOS.
    public typealias PlatformColor = UIColor
    /// Native image type — `UIImage` on watchOS.
    public typealias PlatformImage = UIImage
    /// Native font type — `UIFont` on watchOS.
    public typealias PlatformFont = UIFont
    /// Base class for delegate types — `NSObject` on watchOS (WatchKit
    /// delegates such as `WKApplicationDelegate` inherit from `NSObject`;
    /// there is no `UIResponder` on this platform).
    public typealias PlatformDelegate = NSObject

#elseif canImport(UIKit)
    public import UIKit // UIApplication/UIView/UIColor/UIImage/UIFont used in public typealiases

    /// Singleton-style application class — `UIApplication` on UIKit platforms.
    public typealias PlatformApplication = UIApplication
    /// Native view type — `UIView` on UIKit platforms.
    public typealias PlatformView = UIView
    /// Native colour type — `UIColor` on UIKit platforms.
    public typealias PlatformColor = UIColor
    /// Native image type — `UIImage` on UIKit platforms.
    public typealias PlatformImage = UIImage
    /// Native font type — `UIFont` on UIKit platforms.
    public typealias PlatformFont = UIFont
    /// Base class for delegate types — `UIResponder` on UIKit platforms
    /// (iOS / iPadOS / tvOS / Mac Catalyst / visionOS), so delegate classes
    /// can participate in the UIKit responder chain when appropriate.
    public typealias PlatformDelegate = UIResponder

#elseif canImport(AppKit)
    public import AppKit // NSApplication/NSView/NSColor/NSImage/NSFont used in public typealiases

    /// Singleton-style application class — `NSApplication` on macOS.
    public typealias PlatformApplication = NSApplication
    /// Native view type — `NSView` on macOS.
    public typealias PlatformView = NSView
    /// Native colour type — `NSColor` on macOS.
    public typealias PlatformColor = NSColor
    /// Native image type — `NSImage` on macOS.
    public typealias PlatformImage = NSImage
    /// Native font type — `NSFont` on macOS.
    public typealias PlatformFont = NSFont
    /// Base class for delegate types — `NSObject` on macOS (AppKit delegate
    /// protocols such as `NSApplicationDelegate` are conformed by classes
    /// that inherit from `NSObject`).
    public typealias PlatformDelegate = NSObject
#endif

// MARK: - Shared extension on PlatformApplication

/// Cross-platform shorthand for the app's shared instance.
///
/// `UIApplication` and `NSApplication` both expose `shared` as a class
/// property, whereas `WKExtension` exposes `shared()` as a class method —
/// the body branches on `canImport(WatchKit)` to pick the right form, and
/// returns the resolved concrete type via the ``PlatformApplication`` typealias.
///
/// ```swift
/// PlatformApplication.platformShared.openURL(url)
/// ```
extension PlatformApplication {
    public static var platformShared: PlatformApplication {
        #if canImport(WatchKit)
            shared()
        #else
            shared
        #endif
    }

    /// Opens a URL through the platform's system handler — `NSWorkspace` on
    /// macOS, the shared application elsewhere — so callers never branch on the
    /// platform themselves.
    /// - Parameter url: The URL to hand to the system.
    public static func openSystemURL(_ url: URL) {
        #if os(macOS)
            NSWorkspace.shared.open(url)
        #elseif canImport(WatchKit)
            platformShared.openSystemURL(url)
        #else
            platformShared.open(url)
        #endif
    }

    /// Opens this app's notification settings inside the system settings, where
    /// permission, sounds and banners are managed. A no-op on platforms without
    /// such a deep-link (tvOS, watchOS).
    public static func openNotificationSettings() {
        #if os(iOS) || os(visionOS)
            if let url = URL(string: PlatformApplication.openNotificationSettingsURLString) {
                openSystemURL(url)
            }
        #elseif os(macOS)
            if let url = URL(
                string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                openSystemURL(url)
            }
        #endif
    }
}
