import Foundation

#if os(iOS)
  public import UIKit
#elseif os(macOS)
  public import AppKit
#endif

// MARK: - QuickAction

/// A single home/dock quick action — a row in the iPhone Home Screen long-press
/// menu and in the macOS Dock menu.
public struct QuickAction: Identifiable, Sendable {

  /// Stable identifier used to route the action back to its `handler`.
  public let id: String
  /// Title shown on the menu row.
  public let title: String
  /// Optional secondary line (iOS only; the Dock menu ignores it).
  public let subtitle: String?
  /// SF Symbol shown on the menu row.
  public let systemImage: String
  /// When `true`, the macOS Dock menu draws a separator before this action,
  /// grouping it apart from the preceding items. Ignored on iOS, where Home
  /// Screen shortcuts are a flat list.
  public let separatorBefore: Bool
  /// Work performed when the user picks the action (always on the main actor).
  public let handler: @MainActor @Sendable () -> Void

  /// Creates a quick action.
  /// - Parameters:
  ///   - id: Stable identifier (also the iOS shortcut `type`).
  ///   - title: Title shown on the menu row.
  ///   - subtitle: Optional secondary line (iOS only).
  ///   - systemImage: SF Symbol for the row.
  ///   - separatorBefore: Draw a Dock-menu separator before this action (macOS).
  ///   - handler: Work performed when the action is picked.
  public init(
    id: String,
    title: String,
    subtitle: String? = nil,
    systemImage: String,
    separatorBefore: Bool = false,
    handler: @escaping @MainActor @Sendable () -> Void
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.systemImage = systemImage
    self.separatorBefore = separatorBefore
    self.handler = handler
  }
}

// MARK: - QuickActions

/// Cross-platform home/dock quick actions from a single list.
///
/// One call — ``install(_:)`` — wires the **iPhone Home Screen** shortcut menu
/// and the **macOS Dock** menu from the same `QuickAction` array. It is a no-op
/// on platforms without the feature (iPadOS, tvOS, watchOS, visionOS).
///
/// Adopt ``QuickActionsAppDelegate`` so the picks are delivered:
///
/// ```swift
/// #if os(iOS)
///     @UIApplicationDelegateAdaptor(QuickActionsAppDelegate.self) private var qa
/// #elseif os(macOS)
///     @NSApplicationDelegateAdaptor(QuickActionsAppDelegate.self) private var qa
/// #endif
/// ```
///
/// ```swift
/// QuickActions.install([
///     QuickAction(id: "settings", title: "Settings", systemImage: "gearshape") { … }
/// ])
/// ```
@MainActor
public enum QuickActions {

  private static var actions: [QuickAction] = []
  private static var pendingLaunchActionID: String?

  /// Registers the quick actions for the current launch.
  ///
  /// - iOS: publishes them as `UIApplicationShortcutItem`s.
  /// - macOS: keeps them for the Dock menu (built on demand by the delegate).
  /// - Elsewhere: no-op.
  public static func install(_ actions: [QuickAction]) {
    self.actions = actions
    #if os(iOS)
      publishShortcutItems()
    #endif
  }

  #if os(iOS)
    /// Re-publishes the installed actions as Home Screen shortcut items.
    ///
    /// Dynamic shortcut items set at launch are not reliably captured by
    /// SpringBoard until the app next enters the background, so call this from
    /// the scene's background transition to make the long-press menu appear.
    public static func refreshShortcutItems() {
      publishShortcutItems()
    }

    private static func publishShortcutItems() {
      UIApplication.shared.shortcutItems = actions.map { action in
        UIApplicationShortcutItem(
          type: action.id,
          localizedTitle: action.title,
          localizedSubtitle: action.subtitle,
          icon: UIApplicationShortcutIcon(systemImageName: action.systemImage),
          userInfo: nil
        )
      }
    }
  #endif

  /// Runs the handler registered for `id`.
  /// - Returns: `false` when no registered action matches.
  @discardableResult
  public static func perform(id: String) -> Bool {
    guard let action = actions.first(where: { $0.id == id }) else { return false }
    action.handler()
    return true
  }

  /// Performs — once — a quick action that cold-launched the app.
  ///
  /// Call this when the UI is ready (e.g. from the root view's `.task`); the
  /// pending action, if any, is cleared after running.
  public static func performPendingLaunchAction() {
    guard let id = pendingLaunchActionID else { return }
    pendingLaunchActionID = nil
    perform(id: id)
  }

  /// Records a cold-launch action to be performed once the UI is ready.
  static func rememberLaunchAction(id: String) {
    pendingLaunchActionID = id
  }

  #if os(macOS)
    /// Builds the Dock menu — used by ``QuickActionsAppDelegate``.
    ///
    /// The Dock renders custom menu items as text only, so ``QuickAction``'s
    /// `systemImage` is intentionally not applied here (it serves the iOS
    /// Home Screen shortcuts).
    static func dockMenu() -> NSMenu {
      let menu = NSMenu()
      for action in actions {
        if action.separatorBefore, menu.items.isEmpty == false {
          menu.addItem(.separator())
        }
        let item = NSMenuItem(
          title: action.title,
          action: #selector(DockMenuTarget.run(_:)),
          keyEquivalent: ""
        )
        item.representedObject = action.id
        item.target = dockMenuTarget
        menu.addItem(item)
      }
      return menu
    }

    // Retained so the menu items' (weak) targets stay alive.
    private static let dockMenuTarget = DockMenuTarget()
  #endif
}

#if os(macOS)
  /// Routes Dock-menu clicks to ``QuickActions/perform(id:)``.
  private final class DockMenuTarget: NSObject {
    @MainActor @objc func run(_ sender: NSMenuItem) {
      if let id = sender.representedObject as? String {
        QuickActions.perform(id: id)
      }
    }
  }
#endif

// MARK: - App delegate (same type name on both platforms)

#if os(iOS)
  /// Delivers Home Screen quick-action picks to ``QuickActions``.
  ///
  /// Adopt with `@UIApplicationDelegateAdaptor(QuickActionsAppDelegate.self)`.
  public final class QuickActionsAppDelegate: NSObject, UIApplicationDelegate {

    /// Files opened before a handler is set (e.g. a cold launch via "Open
    /// With") are queued and delivered as soon as it is.
    @MainActor private static var pendingOpenURLs: [URL] = []

    /// A handler for files opened with, or dropped onto, the app. Set it to
    /// treat "open file" as an in-app action (e.g. an import) instead of
    /// letting the system spawn a document window.
    @MainActor public static var openURLsHandler: (([URL]) -> Void)? {
      didSet {
        guard let handler = openURLsHandler, pendingOpenURLs.isEmpty == false else { return }
        let urls = pendingOpenURLs
        pendingOpenURLs = []
        handler(urls)
      }
    }

    public func application(
      _ app: UIApplication,
      open url: URL,
      options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
      MainActor.assumeIsolated {
        if let handler = Self.openURLsHandler {
          handler([url])
        } else {
          Self.pendingOpenURLs.append(url)
        }
        return true
      }
    }

    public func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
      if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
        QuickActions.rememberLaunchAction(id: item.type)
        // Returning false suppresses the duplicate `performActionFor` call;
        // the action is run via performPendingLaunchAction() once ready.
        return false
      }
      return true
    }

    public func application(
      _ application: UIApplication,
      performActionFor shortcutItem: UIApplicationShortcutItem,
      completionHandler: @escaping (Bool) -> Void
    ) {
      completionHandler(QuickActions.perform(id: shortcutItem.type))
    }
  }
#elseif os(macOS)
  /// Provides the Dock menu from the registered ``QuickAction``s.
  ///
  /// Adopt with `@NSApplicationDelegateAdaptor(QuickActionsAppDelegate.self)`.
  public final class QuickActionsAppDelegate: NSObject, NSApplicationDelegate {
    /// Files opened before a handler is set (e.g. a cold launch via "Open
    /// With") are queued and delivered as soon as it is.
    @MainActor private static var pendingOpenURLs: [URL] = []

    /// A handler for files opened with, or dropped onto, the app. Set it to
    /// treat "open file" as an in-app action (e.g. an import) instead of
    /// letting the system spawn a document window. Receives every file from a
    /// multi-file open in a single call.
    @MainActor public static var openURLsHandler: (([URL]) -> Void)? {
      didSet {
        guard let handler = openURLsHandler, pendingOpenURLs.isEmpty == false else { return }
        let urls = pendingOpenURLs
        pendingOpenURLs = []
        handler(urls)
      }
    }

    public func application(_ application: NSApplication, open urls: [URL]) {
      MainActor.assumeIsolated {
        if let handler = Self.openURLsHandler {
          handler(urls)
        } else {
          Self.pendingOpenURLs.append(contentsOf: urls)
        }
      }
    }

    /// Activities delivered before a handler is set (e.g. a cold launch from
    /// Spotlight) are queued and delivered as soon as it is.
    @MainActor private static var pendingUserActivities: [NSUserActivity] = []

    /// A handler for incoming `NSUserActivity` — most notably a tapped Spotlight
    /// result (`CSSearchableItemActionType`), which SwiftUI's
    /// `.onContinueUserActivity` doesn't reliably deliver on macOS.
    @MainActor public static var continueUserActivityHandler: ((NSUserActivity) -> Void)? {
      didSet {
        guard let handler = continueUserActivityHandler, pendingUserActivities.isEmpty == false
        else { return }
        let activities = pendingUserActivities
        pendingUserActivities = []
        activities.forEach(handler)
      }
    }

    public func application(
      _ application: NSApplication,
      continue userActivity: NSUserActivity,
      restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void
    ) -> Bool {
      MainActor.assumeIsolated {
        if let handler = Self.continueUserActivityHandler {
          handler(userActivity)
        } else {
          Self.pendingUserActivities.append(userActivity)
        }
        return true
      }
    }

    public func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
      QuickActions.dockMenu()
    }
  }
#endif
