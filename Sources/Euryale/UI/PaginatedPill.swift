public import SwiftUI

/// A pill-shaped container that paginates between a list of pages.
///
/// `PaginatedPill` shows one page of arbitrary SwiftUI content at a time
/// inside the same rounded background used by ``Pill``.  Indicator dots —
/// one per page — let the user navigate:
///
/// - **Tap any dot** to jump to that page,
/// - **Swipe horizontally** anywhere on the pill to step to the previous /
///   next page.
///
/// ## Layout
///
/// Two styles are available via ``Style``:
///
/// - ``Style/overlay`` (default) — the content fills the pill edge-to-edge
///   and the indicator row floats on top at `indicatorAlignment`
///   (`.bottomTrailing` by default).
/// - ``Style/stacked`` — the content sits above the indicator row in a
///   `VStack`; only the **horizontal** component of `indicatorAlignment`
///   matters in this mode.
///
/// ## Indicator appearance
///
/// On systems with **Liquid Glass** (macOS 26+ / iOS 26+ / tvOS 26+ /
/// watchOS 26+ / visionOS 26+), the dots are pure glass — no colour tint —
/// distinguished only by size and outline opacity (active dot slightly
/// larger with a stronger outline).
///
/// On older systems the dots are tinted: solid fill for the active dot in
/// the SwiftUI environment tint (`Color.accentColor`, or the explicit
/// `accentColor:` override), hollow outlined circle for the others.
///
/// ## Example
///
/// ```swift
/// struct Room: Identifiable { let id = UUID(); let name: String; let count: Int }
/// let rooms = [
///     Room(name: "Bedrooms",  count: 3),
///     Room(name: "Bathrooms", count: 2),
///     Room(name: "Garage",    count: 1),
/// ]
///
/// PaginatedPill(pages: rooms) { room in
///     Pill(label: room.name, value: room.count)
/// }
/// ```
///
/// For a non-paginated layout of multiple pills, see ``PillsView``.
public struct PaginatedPill<Page: Identifiable, Content: View>: View {
    /// Layout strategy for the indicator dots relative to the page content.
    public enum Style: Sendable {
        /// Content fills the pill; the indicator row floats on top of the
        /// content at `indicatorAlignment`.  This is the default.
        case overlay
        /// Content sits above the indicator row in a vertical stack.  Only
        /// the horizontal component of `indicatorAlignment` is used.
        case stacked
    }

    @State private var currentIndex: Int = 0

    private let pages: [Page]
    private let style: Style
    private let indicatorAlignment: Alignment
    private let accentColor: Color?
    @ViewBuilder private let content: (Page) -> Content

    /// Creates a paginated pill.
    ///
    /// - Parameters:
    ///   - pages: The identifiable items to paginate over.  An empty array
    ///     renders a collapsed empty container with no indicators.
    ///   - style: Layout strategy — see ``Style``.  Defaults to
    ///     ``Style/overlay``.
    ///   - indicatorAlignment: Where the indicator row sits.
    ///     - Under ``Style/overlay``: full `Alignment` semantics (e.g.
    ///       `.bottomTrailing`, `.bottom`, `.topLeading`).
    ///     - Under ``Style/stacked``: only the **horizontal** component is
    ///       used; the dots always appear below the content.
    ///     Defaults to `.bottomTrailing`.
    ///   - accentColor: Optional override for the tint used by the active
    ///     indicator on systems without Liquid Glass.  Ignored on OS 26+.
    ///     Defaults to the SwiftUI environment tint (`Color.accentColor`).
    ///   - content: A view builder producing the content for each page.
    public init(
        pages: [Page],
        style: Style = .overlay,
        indicatorAlignment: Alignment = .bottomTrailing,
        accentColor: Color? = nil,
        @ViewBuilder content: @escaping (Page) -> Content
    ) {
        self.pages = pages
        self.style = style
        self.indicatorAlignment = indicatorAlignment
        self.accentColor = accentColor
        self.content = content
    }

    public var body: some View {
        Group {
            if pages.isEmpty {
                Color.clear
                    .frame(height: 0)
            } else {
                switch style {
                case .overlay:
                    overlayLayout
                case .stacked:
                    stackedLayout
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        // Use `.simultaneousGesture` so the swipe coexists with the per-dot
        // Button taps.  On macOS, a plain `.gesture(...)` on the container
        // preempts pointer events from reaching the inner buttons.
        #if !os(tvOS)
        .simultaneousGesture(swipeGesture)
        #endif
        .accessibilityIdentifier("PaginatedPill")
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            pages.isEmpty
                ? "Empty"
                : "Page \(currentIndex + 1) of \(pages.count)"
        )
    }

    // MARK: - Layouts

    @ViewBuilder
    private var overlayLayout: some View {
        pageStack
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: indicatorAlignment) {
                indicatorRow
            }
    }

    @ViewBuilder
    private var stackedLayout: some View {
        VStack(spacing: 10) {
            pageStack
            indicatorRow
                .frame(maxWidth: .infinity, alignment: stackedHorizontalAlignment)
        }
    }

    /// Maps the horizontal component of `indicatorAlignment` to a frame
    /// alignment usable on a horizontal axis.
    private var stackedHorizontalAlignment: Alignment {
        switch indicatorAlignment.horizontal {
        case .leading:  return .leading
        case .trailing: return .trailing
        default:        return .center
        }
    }

    // MARK: - Page content (cross-fade)

    @ViewBuilder
    private var pageStack: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                content(page)
                    .opacity(index == currentIndex ? 1 : 0)
                    .accessibilityHidden(index != currentIndex)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentIndex)
    }

    // MARK: - Indicator dots

    @ViewBuilder
    private var indicatorRow: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                indicatorButton(for: index)
            }
        }
    }

    @ViewBuilder
    private func indicatorButton(for index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                currentIndex = index
            }
        } label: {
            indicatorShape(isActive: index == currentIndex)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go to page \(index + 1)")
        .accessibilityAddTraits(index == currentIndex ? [.isSelected] : [])
    }

    @ViewBuilder
    private func indicatorShape(isActive: Bool) -> some View {
        let size: CGFloat = isActive ? 10 : 7

        if #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) {
            // Liquid Glass: no colour tint at all.  The active dot is
            // distinguished from the inactive ones purely by size and the
            // opacity of its outline against the underlying glass shimmer.
            let dot = Circle()
                .fill(Color.clear)
                .frame(width: size, height: size)
                .overlay(
                    Circle().stroke(
                        .primary.opacity(isActive ? 0.9 : 0.4),
                        lineWidth: 1
                    )
                )
            // `glassEffect()` is unavailable on visionOS; fall back to the
            // outlined dot there.
            #if os(visionOS)
            dot
            #else
            dot.glassEffect()
            #endif
        } else {
            // Classic: solid tinted fill for active, hollow outlined for the
            // others.  `accentColor` overrides the environment tint.
            let tint = accentColor ?? Color.accentColor
            Circle()
                .fill(isActive ? tint : Color.clear)
                .frame(width: size, height: size)
                .overlay(
                    Circle().stroke(tint, lineWidth: isActive ? 0 : 1)
                )
        }
    }

    // MARK: - Swipe gesture

    #if !os(tvOS)
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let threshold: CGFloat = 50
                let dx = value.translation.width
                guard abs(dx) > threshold, !pages.isEmpty else { return }

                let newIndex: Int = dx < 0
                    ? min(currentIndex + 1, pages.count - 1)
                    : max(currentIndex - 1, 0)

                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    currentIndex = newIndex
                }
            }
    }
    #endif
}

// MARK: - Previews

#Preview("Overlay — Pills") {
    struct Room: Identifiable {
        let id = UUID()
        let name: String
        let count: Int
    }
    let rooms = [
        Room(name: "Bedrooms",  count: 3),
        Room(name: "Bathrooms", count: 2),
        Room(name: "Garage",    count: 1),
    ]
    return VStack {
        PaginatedPill(pages: rooms) { room in
            Pill(label: room.name, value: room.count)
        }
        Spacer()
    }
    .padding()
}

#Preview("Overlay — mixed content (icon, photo, status)") {
    // Each page has a totally different content type to stress the
    // generic ViewBuilder + full-bleed overlay layout.
    enum Pane: Identifiable {
        case icon, photo, status
        var id: String { "\(self)" }
    }
    return VStack {
        PaginatedPill(pages: [Pane.icon, .photo, .status]) { pane in
            switch pane {
            case .icon:
                ZStack {
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: "house.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            case .photo:
                AsyncImage(url: URL(string: "https://picsum.photos/seed/euryale/640/280")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6))

            case .status:
                VStack(spacing: 6) {
                    StatusPill(label: "Sync complete", status: .ok)
                    StatusPill(label: "1 item pending", status: .warning)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
            }
        }
        Spacer()
    }
    .padding()
}

#Preview("Stacked — classic, center dots") {
    struct Room: Identifiable { let id = UUID(); let name: String; let count: Int }
    let rooms = [
        Room(name: "Bedrooms",  count: 3),
        Room(name: "Bathrooms", count: 2),
        Room(name: "Garage",    count: 1),
    ]
    return VStack {
        PaginatedPill(
            pages: rooms,
            style: .stacked,
            indicatorAlignment: .center
        ) { room in
            Pill(label: room.name, value: room.count)
        }
        Spacer()
    }
    .padding()
}
