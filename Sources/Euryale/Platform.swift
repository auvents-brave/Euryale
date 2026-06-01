/// Cross-platform typealiases that resolve to the native equivalent on each
/// Apple OS.  Use these in code shared between iOS / iPadOS / tvOS / watchOS /
/// visionOS / Mac Catalyst / macOS to avoid platform-conditional `#if` blocks
/// at every reference site.
///
/// | Type alias        | watchOS         | iOS / tvOS / Catalyst / vision | macOS         |
/// |-------------------|-----------------|--------------------------------|---------------|
/// | ``OSApplication`` | `WKExtension`   | `UIApplication`                | `NSApplication` |
/// | ``OSDelegate``    | `NSObject`      | `UIResponder`                  | `NSObject`    | 
/// | ``OSView``        | *unavailable*   | `UIView`                       | `NSView`      |
/// | ``OSColor``       | `UIColor`       | `UIColor`                      | `NSColor`     |
/// | ``OSImage``       | `UIImage`       | `UIImage`                      | `NSImage`     |
/// | ``OSFont``        | `UIFont`        | `UIFont`                       | `NSFont`      |
///
/// Use ``OSApplication/osShared`` to access the singleton application
/// instance without writing platform branches:
///
/// ```swift
/// OSApplication.osShared.openURL(url)
/// ```

// MARK: - Per-platform typealiases

#if canImport(WatchKit)
    public import WatchKit  // WKExtension and UIColor/UIImage/UIFont used in public typealiases

    /// Singleton-style application class — `WKExtension` on watchOS.
    public typealias OSApplication = WKExtension
    /// Native colour type — `UIColor` on watchOS.
    public typealias OSColor = UIColor
    /// Native image type — `UIImage` on watchOS.
    public typealias OSImage = UIImage
    /// Native font type — `UIFont` on watchOS.
    public typealias OSFont = UIFont
    /// Base class for delegate types — `NSObject` on watchOS (WatchKit
    /// delegates such as `WKApplicationDelegate` inherit from `NSObject`;
    /// there is no `UIResponder` on this platform).
    public typealias OSDelegate = NSObject

#elseif canImport(UIKit)
    public import UIKit  // UIApplication/UIView/UIColor/UIImage/UIFont used in public typealiases

    /// Singleton-style application class — `UIApplication` on UIKit platforms.
    public typealias OSApplication = UIApplication
    /// Native view type — `UIView` on UIKit platforms.
    public typealias OSView = UIView
    /// Native colour type — `UIColor` on UIKit platforms.
    public typealias OSColor = UIColor
    /// Native image type — `UIImage` on UIKit platforms.
    public typealias OSImage = UIImage
    /// Native font type — `UIFont` on UIKit platforms.
    public typealias OSFont = UIFont
    /// Base class for delegate types — `UIResponder` on UIKit platforms
    /// (iOS / iPadOS / tvOS / Mac Catalyst / visionOS), so delegate classes
    /// can participate in the UIKit responder chain when appropriate.
    public typealias OSDelegate = UIResponder

#elseif canImport(AppKit)
    public import AppKit  // NSApplication/NSView/NSColor/NSImage/NSFont used in public typealiases

    /// Singleton-style application class — `NSApplication` on macOS.
    public typealias OSApplication = NSApplication
    /// Native view type — `NSView` on macOS.
    public typealias OSView = NSView
    /// Native colour type — `NSColor` on macOS.
    public typealias OSColor = NSColor
    /// Native image type — `NSImage` on macOS.
    public typealias OSImage = NSImage
    /// Native font type — `NSFont` on macOS.
    public typealias OSFont = NSFont
    /// Base class for delegate types — `NSObject` on macOS (AppKit delegate
    /// protocols such as `NSApplicationDelegate` are conformed by classes
    /// that inherit from `NSObject`).
    public typealias OSDelegate = NSObject
#endif

// MARK: - Shared extension on OSApplication

/// Cross-platform shorthand for the app's shared instance.
///
/// `UIApplication` and `NSApplication` both expose `shared` as a class
/// property, whereas `WKExtension` exposes `shared()` as a class method —
/// the body branches on `canImport(WatchKit)` to pick the right form, and
/// returns the resolved concrete type via the ``OSApplication`` typealias.
///
/// ```swift
/// OSApplication.osShared.openURL(url)
/// ```
public extension OSApplication {
    static var osShared: OSApplication {
        #if canImport(WatchKit)
            shared()
        #else
            shared
        #endif
    }
}
