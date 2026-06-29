import Foundation

// MARK: - Per-platform typealiases

#if canImport(WatchKit)
	public import WatchKit

	/// The platform's application type — `WKApplication` on watchOS.
	public typealias PlatformApplication = WKApplication
	/// The platform's colour type — `UIColor` on watchOS.
	public typealias PlatformColor = UIColor
	/// The platform's image type — `UIImage` on watchOS.
	public typealias PlatformImage = UIImage
	/// The platform's font type — `UIFont` on watchOS.
	public typealias PlatformFont = UIFont
	/// The platform's app-delegate base type — `NSObject` on watchOS.
	public typealias PlatformDelegate = NSObject

#elseif canImport(UIKit)
	public import UIKit
	public import SwiftUI

	/// The platform's application type — `UIApplication` on UIKit platforms.
	public typealias PlatformApplication = UIApplication
	/// The platform's view type — `UIView` on UIKit platforms.
	public typealias PlatformView = UIView
	/// The platform's colour type — `UIColor` on UIKit platforms.
	public typealias PlatformColor = UIColor
	/// The platform's image type — `UIImage` on UIKit platforms.
	public typealias PlatformImage = UIImage
	/// The platform's font type — `UIFont` on UIKit platforms.
	public typealias PlatformFont = UIFont
	/// The platform's app-delegate base type — `UIResponder` on UIKit platforms.
	public typealias PlatformDelegate = UIResponder
	/// The platform's view-controller type — `UIViewController` on UIKit platforms.
	public typealias PlatformViewController = UIViewController
	/// The platform's SwiftUI hosting controller — `UIHostingController` on UIKit platforms.
	public typealias PlatformHostingController = UIHostingController

#elseif canImport(AppKit)
	public import AppKit
	public import SwiftUI

	/// The platform's application type — `NSApplication` on AppKit platforms.
	public typealias PlatformApplication = NSApplication
	/// The platform's view type — `NSView` on AppKit platforms.
	public typealias PlatformView = NSView
	/// The platform's colour type — `NSColor` on AppKit platforms.
	public typealias PlatformColor = NSColor
	/// The platform's image type — `NSImage` on AppKit platforms.
	public typealias PlatformImage = NSImage
	/// The platform's font type — `NSFont` on AppKit platforms.
	public typealias PlatformFont = NSFont
	/// The platform's app-delegate base type — `NSObject` on AppKit platforms.
	public typealias PlatformDelegate = NSObject

	/// The platform's view-controller type — `NSViewController` on AppKit platforms.
	public typealias PlatformViewController = NSViewController
	/// The platform's SwiftUI hosting controller — `NSHostingController` on AppKit platforms.
	public typealias PlatformHostingController = NSHostingController
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
	/// The platform's shared application instance, resolved per platform.
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
				string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
			{
				openSystemURL(url)
			}
		#endif
	}
}
