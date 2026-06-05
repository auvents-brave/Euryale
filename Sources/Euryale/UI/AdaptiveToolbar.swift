public import SwiftUI

// MARK: - ToolbarShareItem

/// One shareable file offered by a share action. A single item renders as a
/// `ShareLink`; several render as a menu of `ShareLink`s (e.g. format choice).
public struct ToolbarShareItem: Identifiable {
    public let id = UUID()
    let title: String
    let systemImage: String
    let url: URL

    /// Creates a share item.
    /// - Parameters:
    ///   - title: Menu row label (when there's more than one item).
    ///   - systemImage: SF Symbol for the menu row.
    ///   - url: File to share.
    public init(title: String, systemImage: String, url: URL) {
        self.title = title
        self.systemImage = systemImage
        self.url = url
    }
}

// MARK: - ToolbarAction

/// One action shown in an ``AdaptiveToolbar``.
public struct ToolbarAction: Identifiable {

    /// How the action's title behaves as horizontal space tightens.
    public enum LabelDisplay {
        /// Title always shown next to the icon; never collapsed.
        case always
        /// Title shown when there's room, dropped to icon-only, then to the
        /// overflow popover as space runs out.
        case adaptive
        /// Icon only; the title is used for the tooltip / accessibility.
        case iconOnly
    }

    public let id: String
    let title: String
    let systemImage: String
    let display: LabelDisplay
    let role: ButtonRole?
    let isEnabled: Bool
    let isSelected: Bool
    let canOverflow: Bool
    let opensSettings: Bool
    let shareItems: [ToolbarShareItem]
    let action: @MainActor () -> Void

    /// Creates a toolbar action.
    /// - Parameters:
    ///   - id: Stable identifier (defaults to `title`).
    ///   - title: Label, also used for the tooltip, accessibility, and the
    ///     overflow menu row text (so it is always required).
    ///   - systemImage: SF Symbol for the icon.
    ///   - display: How the title adapts to available width. Use `.iconOnly`
    ///     for an action that shows only its icon in the bar.
    ///   - role: Optional button role, e.g. `.destructive` (shown in red).
    ///   - isEnabled: Whether the action is tappable.
    ///   - isSelected: Whether the action is the active one in a selection
    ///     group; shown with a highlighted, "pressed" background.
    ///   - canOverflow: Whether the action may fold into the overflow popover
    ///     when space is tight. Selection items usually set this to `false`.
    ///   - opensSettings: On macOS, render as a `SettingsLink` that opens the
    ///     standard Settings window (the only supported way since macOS 14).
    ///     Ignored elsewhere, where `action` runs instead.
    ///   - shareItems: When non-empty, the action shares these files — a single
    ///     item renders as a `ShareLink`, several as a `Menu` of `ShareLink`s
    ///     (e.g. format choice). Ignored on tvOS/watchOS (no `ShareLink`).
    ///   - action: Work performed when tapped.
    public init(
        id: String? = nil,
        title: String,
        systemImage: String,
        display: LabelDisplay = .adaptive,
        role: ButtonRole? = nil,
        isEnabled: Bool = true,
        isSelected: Bool = false,
        canOverflow: Bool = true,
        opensSettings: Bool = false,
        shareItems: [ToolbarShareItem] = [],
        action: @escaping @MainActor () -> Void
    ) {
        self.id = id ?? title
        self.title = title
        self.systemImage = systemImage
        self.display = display
        self.role = role
        self.isEnabled = isEnabled
        self.isSelected = isSelected
        self.canOverflow = canOverflow
        self.opensSettings = opensSettings
        self.shareItems = shareItems
        self.action = action
    }
}

// MARK: - AdaptiveToolbar

/// A custom, cross-platform toolbar that mirrors the system toolbars: each
/// action shows as an icon or icon + label, labels collapse to icons as space
/// tightens, and the tightest layouts fold trailing actions into an overflow
/// popover. Supports Liquid Glass where available, with a material-capsule
/// fallback.
///
/// Actions can be split into **groups** separated by a divider — e.g. a leading
/// radio-style selection group (using ``ToolbarAction/isSelected`` and
/// `canOverflow: false`) followed by a group of commands.
///
/// Built on `ViewThatFits`: a list of candidate layouts is offered from
/// roomiest (all labels) to tightest (overflow). ``ToolbarAction/LabelDisplay``
/// decides what each action drops first; `.always` actions never collapse, and
/// `canOverflow == false` actions never fold into overflow.
///
/// ```swift
/// AdaptiveToolbar(groups: [
///     [ .init(title: "Furniture", systemImage: "cabinet.fill", isSelected: true, canOverflow: false) { … },
///       .init(title: "Things",    systemImage: "shippingbox.fill", canOverflow: false) { … } ],
///     [ .init(title: "Delete All", systemImage: "trash", role: .destructive) { … },
///       .init(title: "Settings",   systemImage: "gearshape") { … } ],
/// ])
/// ```
public struct AdaptiveToolbar: View {

    private let groups: [[ToolbarAction]]
    private let showsBackground: Bool
    private let allowsOverflow: Bool
    private let collapsesToIcons: Bool

    /// Creates a toolbar from a single ordered list of actions.
    /// - Parameters:
    ///   - actions: The actions to show.
    ///   - showsBackground: Whether to draw the glass/material capsule. Set to
    ///     `false` when embedding in a native container (e.g. a window toolbar)
    ///     that already provides chrome.
    ///   - allowsOverflow: Whether tight widths fold trailing actions into an
    ///     overflow `…` button. Set to `false` when embedding in a native window
    ///     toolbar (where a popover/menu from a toolbar item is unreliable);
    ///     actions then simply collapse to icons.
    ///   - collapsesToIcons: Whether labels may drop to icons as width tightens.
    ///     Set to `false` inside a native window toolbar, where `ViewThatFits`
    ///     can't see the real available width and would always pick icons —
    ///     each action then follows its own ``ToolbarAction/LabelDisplay``.
    public init(
        _ actions: [ToolbarAction],
        showsBackground: Bool = true,
        allowsOverflow: Bool = true,
        collapsesToIcons: Bool = true
    ) {
        self.groups = [actions]
        self.showsBackground = showsBackground
        self.allowsOverflow = allowsOverflow
        self.collapsesToIcons = collapsesToIcons
    }

    /// Creates a toolbar from ordered groups of actions, separated by dividers.
    /// - Parameters:
    ///   - groups: The action groups, rendered with a divider between them.
    ///   - showsBackground: Whether to draw the glass/material capsule. Set to
    ///     `false` when embedding in a native container (e.g. a window toolbar).
    ///   - allowsOverflow: Whether tight widths fold trailing actions into an
    ///     overflow `…` button (see the other initialiser).
    ///   - collapsesToIcons: Whether labels may drop to icons as width tightens
    ///     (see the other initialiser).
    public init(
        groups: [[ToolbarAction]],
        showsBackground: Bool = true,
        allowsOverflow: Bool = true,
        collapsesToIcons: Bool = true
    ) {
        self.groups = groups
        self.showsBackground = showsBackground
        self.allowsOverflow = allowsOverflow
        self.collapsesToIcons = collapsesToIcons
    }

    private var allActions: [ToolbarAction] {
        groups.flatMap { $0 }
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Array(candidates.enumerated()), id: \.offset) { _, candidate in
                candidate
            }
        }
        #if os(tvOS)
            // Horizontal inset keeps the first/last button's highlight clear of
            // the capsule's rounded ends; the capsule then clips anything that
            // would bleed past the bar.
            .padding(.horizontal, showsBackground ? 28 : 0)
            .padding(.vertical, showsBackground ? 8 : 0)
        #else
            .padding(.horizontal, showsBackground ? 10 : 0)
            .padding(.vertical, showsBackground ? 5 : 0)
        #endif
        .modifier(GlassCapsuleBackground(isEnabled: showsBackground))
        #if os(tvOS)
            .clipShape(Capsule())
        #endif
        .accessibilityIdentifier("AdaptiveToolbar")
    }

    /// Candidate layouts, roomiest first: full labels, then all icons, then
    /// progressively more foldable actions moved into the overflow popover.
    private var candidates: [AnyView] {
        // In a native toolbar `ViewThatFits` can't measure the real width, so
        // keep a single full-label row and let each action's display decide.
        guard collapsesToIcons else {
            return [AnyView(row(hideCount: 0, compact: false))]
        }
        var result: [AnyView] = [
            AnyView(row(hideCount: 0, compact: false)),
            AnyView(row(hideCount: 0, compact: true)),
        ]
        let foldableCount = foldOrder.count
        if allowsOverflow, foldableCount > 0 {
            for hide in 1 ... foldableCount {
                result.append(AnyView(row(hideCount: hide, compact: true)))
            }
        }
        return result
    }

    /// IDs of foldable actions in the order they leave the bar: `.adaptive`
    /// before `.iconOnly`, trailing-first within each. `.always` and
    /// `canOverflow == false` actions are excluded.
    private var foldOrder: [String] {
        let foldable = allActions.filter { $0.canOverflow && $0.display != .always }
        return foldable.filter { $0.display == .adaptive }.reversed().map(\.id)
            + foldable.filter { $0.display == .iconOnly }.reversed().map(\.id)
    }

    @ViewBuilder
    private func row(hideCount: Int, compact: Bool) -> some View {
        let hiddenIDs = Set(foldOrder.prefix(hideCount))
        let overflow = allActions.filter { hiddenIDs.contains($0.id) }

        HStack(spacing: 8) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                let visible = group.filter { !hiddenIDs.contains($0.id) }
                if !visible.isEmpty {
                    if index > 0 {
                        Divider().frame(height: 20)
                    }
                    HStack(spacing: 4) {
                        ForEach(visible) { action in
                            ToolbarButton(action: action, iconOnly: iconOnly(action, compact: compact))
                        }
                    }
                }
            }
            if !overflow.isEmpty {
                Divider().frame(height: 20)
                OverflowButton(actions: overflow)
            }
        }
    }

    private func iconOnly(_ action: ToolbarAction, compact: Bool) -> Bool {
        switch action.display {
        case .iconOnly: return true
        case .always:   return false
        case .adaptive: return compact
        }
    }
}

// MARK: - ToolbarButton

private struct ToolbarButton: View {
    let action: ToolbarAction
    let iconOnly: Bool

    @State private var isHovering = false
    #if os(tvOS)
        @FocusState private var isFocused: Bool
    #endif

    var body: some View {
        let labelled = control
            .disabled(!action.isEnabled)
            .help(action.title)
            .accessibilityLabel(action.title)
            .accessibilityAddTraits(action.isSelected ? .isSelected : [])

        // Hover highlight on pointer platforms; on tvOS the default button style
        // draws an oversized system focus "lift" that ignores `focusEffectDisabled`,
        // so a bespoke style renders only the label and our own contained highlight
        // (sized exactly to the button) takes over via `isFocused`.
        #if os(tvOS)
            labelled
                .buttonStyle(ContainedToolbarButtonStyle())
                .focused($isFocused)
                .focusEffectDisabled()
                .animation(.easeInOut(duration: 0.12), value: isFocused)
        #elseif os(watchOS)
            labelled.buttonStyle(.plain)
        #else
            labelled
                .buttonStyle(.plain)
                .onHover { isHovering = $0 }
        #endif
    }

    /// A plain `Button`, or — for special actions — a `SettingsLink` (opens the
    /// macOS Settings window) or a share control (`ShareLink`, or a `Menu` of
    /// them for ``ToolbarAction/shareItems``).
    @ViewBuilder
    private var control: some View {
        #if os(tvOS) || os(watchOS)
            Button(role: action.role, action: action.action) { styledLabel }
        #else
            if action.shareItems.isEmpty == false {
                shareControl
            } else {
                #if os(macOS)
                    if action.opensSettings {
                        SettingsLink { styledLabel }
                    } else {
                        Button(role: action.role, action: action.action) { styledLabel }
                    }
                #else
                    Button(role: action.role, action: action.action) { styledLabel }
                #endif
            }
        #endif
    }

    #if !os(tvOS) && !os(watchOS)
        /// One file → a `ShareLink`; several → a `Menu` of `ShareLink`s (the
        /// menu dismisses on selection, so no chooser sheet lingers behind the
        /// system share sheet).
        @ViewBuilder
        private var shareControl: some View {
            if action.shareItems.count == 1 {
                ShareLink(item: action.shareItems[0].url) { styledLabel }
            } else {
                Menu {
                    ForEach(action.shareItems) { item in
                        ShareLink(item: item.url) {
                            Label(item.title, systemImage: item.systemImage)
                        }
                    }
                } label: {
                    styledLabel
                }
                .menuIndicator(.hidden)
            }
        }
    #endif

    private var styledLabel: some View {
        content
            .foregroundStyle(foreground)
            .padding(.vertical, 6)
            .padding(.horizontal, iconOnly ? 8 : 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(background)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var foreground: Color {
        #if os(tvOS)
            // Focus wins over selection: a focused item shows the bright tvOS
            // "lifted" look (dark text on white) even when already selected, so
            // the cursor is always visible.
            if isFocused { return action.role == .destructive ? .red : .black }
        #endif
        if action.role == .destructive { return .red }
        if action.isSelected { return .accentColor }
        return .primary
    }

    private var background: AnyShapeStyle {
        #if os(tvOS)
            if isFocused { return AnyShapeStyle(Color.white) }
        #endif
        if action.isSelected { return AnyShapeStyle(Color.accentColor.opacity(0.18)) }
        if isHovering { return AnyShapeStyle(.quaternary) }
        return AnyShapeStyle(.clear)
    }

    @ViewBuilder
    private var content: some View {
        if iconOnly {
            Image(systemName: action.systemImage)
        } else {
            Label(action.title, systemImage: action.systemImage)
        }
    }
}

// MARK: - OverflowButton

private struct OverflowButton: View {
    let actions: [ToolbarAction]

    @State private var isPresented = false
    @State private var isHovering = false

    private var ellipsis: some View {
        Image(systemName: "ellipsis")
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    var body: some View {
        #if os(macOS)
            // A Menu anchors reliably inside the native window toolbar, where a
            // SwiftUI popover presented from a toolbar item does not.
            Menu {
                ForEach(actions) { action in
                    Button(role: action.role, action: action.action) {
                        Label(action.title, systemImage: action.systemImage)
                    }
                    .disabled(!action.isEnabled)
                }
            } label: {
                ellipsis
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(Text("More", bundle: .module))
            .onHover { isHovering = $0 }
        #elseif os(tvOS) || os(watchOS)
            Button {} label: { ellipsis }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("More", bundle: .module))
        #else
            Button { isPresented = true } label: { ellipsis }
                .buttonStyle(.plain)
                .help(Text("More", bundle: .module))
                .accessibilityLabel(Text("More", bundle: .module))
                .onHover { isHovering = $0 }
                .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                    overflowMenu
                        .presentationCompactAdaptation(.popover)
                }
        #endif
    }

    #if !os(macOS) && !os(tvOS) && !os(watchOS)
        private var overflowMenu: some View {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(actions) { action in
                    Button(role: action.role) {
                        isPresented = false
                        action.action()
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                            .foregroundStyle(action.role == .destructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!action.isEnabled)
                }
            }
            .padding(6)
            .frame(minWidth: 180)
        }
    #endif
}

#if os(tvOS)
    /// Renders only the label (with a brief press dimming) — no system focus
    /// chrome — so the toolbar's own contained highlight defines focus.
    private struct ContainedToolbarButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .opacity(configuration.isPressed ? 0.55 : 1)
        }
    }
#endif

// MARK: - GlassCapsuleBackground

/// Wraps the toolbar in a Liquid Glass capsule where available, otherwise an
/// ultra-thin material capsule — matching the floating system toolbars.
private struct GlassCapsuleBackground: ViewModifier {
    var isEnabled: Bool = true

    @ViewBuilder
    func body(content: Content) -> some View {
        if !isEnabled {
            content
        } else {
            // `glassEffect` is unavailable on visionOS (Liquid Glass is the
            // system default there), so gate it out at compile time and fall
            // back to the material capsule.
            #if os(visionOS)
                content.background(.ultraThinMaterial, in: Capsule())
            #else
                if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
                    content.glassEffect(.regular, in: Capsule())
                } else {
                    content.background(.ultraThinMaterial, in: Capsule())
                }
            #endif
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Grouped, adaptive widths") {
        let groups: [[ToolbarAction]] = [
            [
                .init(title: "Furniture", systemImage: "cabinet.fill", isSelected: true, canOverflow: false) {},
                .init(title: "Things", systemImage: "shippingbox.fill", canOverflow: false) {},
            ],
            [
                .init(title: "Magic Wand", systemImage: "wand.and.stars") {},
				.init(title: "Delete All", systemImage: "trash", role: .destructive) {},
				.init(title: "", systemImage: "gearshape", opensSettings: true) {},
            ],
        ]
        return VStack(alignment: .leading, spacing: 24) {
            Text("Roomy — full labels").font(.caption).foregroundStyle(.secondary)
            AdaptiveToolbar(groups: groups).frame(width: 560, alignment: .leading)

            Text("Medium — icons, separator kept").font(.caption).foregroundStyle(.secondary)
            AdaptiveToolbar(groups: groups).frame(width: 300, alignment: .leading)

            Text("Tight — commands fold into overflow").font(.caption).foregroundStyle(.secondary)
            AdaptiveToolbar(groups: groups).frame(width: 170, alignment: .leading)
        }
        .padding()
    }
#endif
