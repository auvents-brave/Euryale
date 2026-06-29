import Foundation

// MARK: - Per-platform typealiases

#if canImport(WatchKit)
	public import WatchKit

	public typealias PlatformApplication = WKApplication
	public typealias PlatformColor = UIColor
	public typealias PlatformImage = UIImage
	public typealias PlatformFont = UIFont
	public typealias PlatformDelegate = NSObject

#elseif canImport(UIKit)
	public import UIKit
	public import SwiftUI

	public typealias PlatformApplication = UIApplication
	public typealias PlatformView = UIView
	public typealias PlatformColor = UIColor
	public typealias PlatformImage = UIImage
	public typealias PlatformFont = UIFont
	public typealias PlatformDelegate = UIResponder
	public typealias PlatformViewController = UIViewController
	public typealias PlatformHostingController = UIHostingController

#elseif canImport(AppKit)
	public import AppKit
	public import SwiftUI

	public typealias PlatformApplication = NSApplication
	public typealias PlatformView = NSView
	public typealias PlatformColor = NSColor
	public typealias PlatformImage = NSImage
	public typealias PlatformFont = NSFont
	public typealias PlatformDelegate = NSObject

	public typealias PlatformViewController = NSViewController
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
