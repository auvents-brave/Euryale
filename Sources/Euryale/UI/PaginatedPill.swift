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
///
/// This is the bare paginator (no pill background): content + indicator dots +
/// swipe, usable anywhere. For the rounded-pill chrome, wrap it in
/// ``PaginatedPill``.
public struct PaginatedView<Page: Identifiable, Content: View>: View {
	/// Layout strategy for the indicator dots relative to the page content.
	public enum Style: Sendable {
		/// Content fills the pill; the indicator row floats on top of the
		/// content at `indicatorAlignment`.  This is the default.
		case overlay
		/// Content sits above the indicator row in a vertical stack.  Only
		/// the horizontal component of `indicatorAlignment` is used.
		case stacked
	}

	@State private var internalIndex: Int = 0

	private let pages: [Page]
	private let style: Style
	private let indicatorAlignment: Alignment
	private let accentColor: Color?
	private let onSelect: (() -> Void)?
	/// When non-`nil`, the page index is owned by the wrapper (``PaginatedPill``)
	/// so its focus chrome can scale the whole pill; otherwise the view keeps its
	/// own `internalIndex`.
	private let externalIndex: Binding<Int>?
	/// Whether this view installs its own tvOS focus handling. ``PaginatedPill``
	/// sets this to `false` and installs focus on the outer (chromed) view.
	private let managesFocus: Bool
	@ContentBuilder private let content: (Page) -> Content

	/// The page index, routed to the wrapper's binding when embedded.
	private var currentIndex: Binding<Int> { externalIndex ?? $internalIndex }

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
	///   - onSelect: Invoked when the cell is selected — a *Select* press on
	///     tvOS (where the pill is focusable) or a tap elsewhere. When `nil`,
	///     selection is disabled. On tvOS, left/right paging is always wired
	///     regardless of this argument when there is more than one page.
	///   - content: A view builder producing the content for each page.
	public init(
		pages: [Page],
		style: Style = .overlay,
		indicatorAlignment: Alignment = .bottomTrailing,
		accentColor: Color? = nil,
		onSelect: (() -> Void)? = nil,
		@ContentBuilder content: @escaping (Page) -> Content
	) {
		self.pages = pages
		self.style = style
		self.indicatorAlignment = indicatorAlignment
		self.accentColor = accentColor
		self.onSelect = onSelect
		self.externalIndex = nil
		self.managesFocus = true
		self.content = content
	}

	/// Wrapper init: the page index is owned by ``PaginatedPill`` and tvOS focus
	/// is installed on the outer chromed view, not here.
	init(
		pages: [Page],
		style: Style,
		indicatorAlignment: Alignment,
		accentColor: Color?,
		index: Binding<Int>,
		@ContentBuilder content: @escaping (Page) -> Content
	) {
		self.pages = pages
		self.style = style
		self.indicatorAlignment = indicatorAlignment
		self.accentColor = accentColor
		self.onSelect = nil
		self.externalIndex = index
		self.managesFocus = false
		self.content = content
	}

	/// The content and behaviour of the view.
	public var body: some View {
		let paginator =
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
			.frame(maxWidth: .infinity, alignment: .leading)
			.contentShape(Rectangle())
			// Use `.simultaneousGesture` so the swipe coexists with the per-dot
			// Button taps.  On macOS, a plain `.gesture(...)` on the container
			// preempts pointer events from reaching the inner buttons.
			#if !os(tvOS)
				.simultaneousGesture(swipeGesture)
			#endif

		// tvOS: the whole pill is the single focus target. Select fires
		// `onSelect`; left/right page within the pill (wrapping). The indicator
		// dots are non-interactive on tvOS so they don't steal focus. When
		// embedded in ``PaginatedPill`` (`managesFocus == false`) the wrapper
		// installs focus on the outer, chromed view instead.
		return
			Group {
				if managesFocus {
					paginator.modifier(focusModifier)
				} else {
					paginator
				}
			}
			.accessibilityIdentifier("PaginatedView")
			.accessibilityElement(children: .contain)
			.accessibilityLabel(
				pages.isEmpty
					? "Empty"
					: "Page \(currentIndex.wrappedValue + 1) of \(pages.count)"
			)
	}

	/// The tvOS focus / selection wiring installed when this view manages its
	/// own focus (standalone use, not embedded in ``PaginatedPill``).
	private var focusModifier: PillFocusModifier {
		#if os(tvOS)
			PillFocusModifier(
				onSelect: onSelect,
				onMove: pages.count > 1 ? { page(in: $0) } : nil
			)
		#else
			PillFocusModifier(onSelect: onSelect)
		#endif
	}

	// MARK: Layouts

	@ContentBuilder
	private var overlayLayout: some View {
		pageStack
			.frame(maxWidth: .infinity, alignment: .leading)
			.overlay(alignment: indicatorAlignment) {
				// Inset the dots from the content edge so they sit *on* the content
				// (and stay clear of rounded corners) rather than flush to the rim.
				indicatorRow
					.padding(10)
			}
	}

	@ContentBuilder
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
		case .leading: return .leading
		case .trailing: return .trailing
		default: return .center
		}
	}

	// MARK: Page content (cross-fade)

	@ContentBuilder
	private var pageStack: some View {
		ZStack(alignment: .leading) {
			ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
				content(page)
					.opacity(index == currentIndex.wrappedValue ? 1 : 0)
					.accessibilityHidden(index != currentIndex.wrappedValue)
			}
		}
		.animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentIndex.wrappedValue)
	}

	// MARK: Page navigation

	#if os(tvOS)
		/// Steps one page in `direction`, wrapping around at the ends. Used by the
		/// tvOS Siri Remote left/right move commands.
		private func page(in direction: MoveCommandDirection) {
			guard pages.count > 1 else { return }
			withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
				switch direction {
				case .left:
					currentIndex.wrappedValue = (currentIndex.wrappedValue - 1 + pages.count) % pages.count
				case .right:
					currentIndex.wrappedValue = (currentIndex.wrappedValue + 1) % pages.count
				default:
					break
				}
			}
		}
	#endif

	// MARK: Indicator dots

	@ContentBuilder
	private var indicatorRow: some View {
		HStack(spacing: PillMetrics.indicatorSpacing) {
			ForEach(pages.indices, id: \.self) { index in
				indicatorButton(for: index)
			}
		}
	}

	@ContentBuilder
	private func indicatorButton(for index: Int) -> some View {
		#if os(tvOS)
			// Non-interactive on tvOS: a focusable Button here would steal focus
			// from the pill cell, breaking the left/right paging. The dots are
			// driven by the Siri Remote move commands instead.
			indicatorShape(isActive: index == currentIndex.wrappedValue)
				.accessibilityHidden(true)
		#else
			Button {
				withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
					currentIndex.wrappedValue = index
				}
			} label: {
				indicatorShape(isActive: index == currentIndex.wrappedValue)
			}
			.buttonStyle(.plain)
			.accessibilityLabel("Go to page \(index + 1)")
			.accessibilityAddTraits(index == currentIndex.wrappedValue ? [.isSelected] : [])
		#endif
	}

	@ContentBuilder
	private func indicatorShape(isActive: Bool) -> some View {
		let size: CGFloat = isActive ? PillMetrics.indicatorActiveSize : PillMetrics.indicatorInactiveSize

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

	// MARK: Swipe gesture

	#if !os(tvOS)
		private var swipeGesture: some Gesture {
			DragGesture(minimumDistance: 20)
				.onEnded { value in
					let threshold: CGFloat = 50
					let dx = value.translation.width
					guard abs(dx) > threshold, !pages.isEmpty else { return }

					let newIndex: Int =
						dx < 0
						? min(currentIndex.wrappedValue + 1, pages.count - 1)
						: max(currentIndex.wrappedValue - 1, 0)

					withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
						currentIndex.wrappedValue = newIndex
					}
				}
		}
	#endif
}

// MARK: - PaginatedPill

/// A ``PaginatedView`` wrapped in the rounded ``Pill`` background.
public struct PaginatedPill<Page: Identifiable, Content: View>: View {
	/// Layout strategy for the indicator dots — see ``PaginatedView/Style``.
	public typealias Style = PaginatedView<Page, Content>.Style

	private let pages: [Page]
	private let style: Style
	private let indicatorAlignment: Alignment
	private let accentColor: Color?
	private let onSelect: (() -> Void)?
	@ContentBuilder private let content: (Page) -> Content

	/// The page index lives here (not in the embedded ``PaginatedView``) so the
	/// tvOS focus chrome can scale the whole chromed pill, background included,
	/// while still driving the inner pager's current page.
	@State private var index = 0

	/// Creates a paginated pill.
	/// See ``PaginatedView/init(pages:style:indicatorAlignment:accentColor:onSelect:content:)``.
	public init(
		pages: [Page],
		style: Style = .overlay,
		indicatorAlignment: Alignment = .bottomTrailing,
		accentColor: Color? = nil,
		onSelect: (() -> Void)? = nil,
		@ContentBuilder content: @escaping (Page) -> Content
	) {
		self.pages = pages
		self.style = style
		self.indicatorAlignment = indicatorAlignment
		self.accentColor = accentColor
		self.onSelect = onSelect
		self.content = content
	}

	/// The content and behaviour of the view.
	public var body: some View {
		PaginatedView(
			pages: pages,
			style: style,
			indicatorAlignment: indicatorAlignment,
			accentColor: accentColor,
			index: $index,
			content: content
		)
		.padding(PillMetrics.contentPadding)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color.secondary.opacity(0.1))
		.clipShape(RoundedRectangle(cornerRadius: PillMetrics.cornerRadius, style: .continuous))
		// Install tvOS focus on the outer, chromed pill so the focus lift scales
		// the whole pill. Select fires `onSelect`; left/right page (wrapping).
		#if os(tvOS)
			.modifier(
				PillFocusModifier(
					onSelect: onSelect,
					onMove: pages.count > 1 ? { step($0) } : nil
				)
			)
		#else
			.modifier(PillFocusModifier(onSelect: onSelect))
		#endif
		.accessibilityIdentifier("PaginatedPill")
	}

	#if os(tvOS)
		/// Steps one page in `direction`, wrapping at the ends — the tvOS Siri
		/// Remote left/right handler for the chromed pill.
		private func step(_ direction: MoveCommandDirection) {
			guard pages.count > 1 else { return }
			withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
				switch direction {
				case .left:
					index = (index - 1 + pages.count) % pages.count
				case .right:
					index = (index + 1) % pages.count
				default:
					break
				}
			}
		}
	#endif
}

// MARK: - Previews

/// Sample data shared by the room previews.
private struct Room: Identifiable {
	let id = UUID()
	let name: String
	let count: Int
}

private let sampleRooms = [
	Room(name: "Bedrooms", count: 3),
	Room(name: "Bathrooms", count: 2),
	Room(name: "Garage", count: 1),
]

#Preview("Overlay — Pills") {
	VStack {
		PaginatedPill(pages: sampleRooms) { room in
			Pill(label: room.name, value: room.count)
		}
		Spacer()
	}
	.padding()
}

/// Preview host: each page has a totally different content type to stress the
/// generic ViewBuilder + full-bleed overlay layout.
private struct MixedContentPreview: View {
	enum Pane: Identifiable {
		case icon, photo, status
		var id: String { "\(self)" }
	}

	var body: some View {
		VStack {
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
}

#Preview("Overlay — mixed content (icon, photo, status)") {
	MixedContentPreview()
}

#Preview("Stacked — classic, center dots") {
	VStack {
		PaginatedPill(
			pages: sampleRooms,
			style: .stacked,
			indicatorAlignment: .center
		) { room in
			Pill(label: room.name, value: room.count)
		}
		Spacer()
	}
	.padding()
}
