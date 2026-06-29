public import SwiftUI

// MARK: - RowAction

/// One action offered on a list row. ``EntityList`` and the standalone
/// ``SwiftUICore/View/rowActions(_:)`` modifier render each action as **both** a
/// trailing `swipeActions` button (iOS / iPadOS / visionOS) **and** a
/// `contextMenu` item (macOS right-click, iPad long-press) — so a row's
/// delete / favourite / rename affordances are declared once and behave
/// uniformly on every platform.
public struct RowAction: Identifiable {
	/// Stable identifier; defaults to ``systemImage``.
	public let id: String
	let title: Text
	let systemImage: String
	let role: ButtonRole?
	/// Whether a full trailing swipe performs this (iOS). At most one action
	/// should set it — usually the destructive one.
	let isDefaultSwipe: Bool
	let action: @MainActor () -> Void

	/// Creates a row action.
	/// - Parameters:
	///   - id: Stable identifier; defaults to `systemImage`.
	///   - title: Button label (wrap a localised `String` in `Text`).
	///   - systemImage: SF Symbol for the swipe button and menu row.
	///   - role: Optional role, e.g. `.destructive` (shown in red).
	///   - isDefaultSwipe: Whether a full trailing swipe triggers it (iOS).
	///   - action: Work performed when chosen.
	public init(
		id: String? = nil,
		title: Text,
		systemImage: String,
		role: ButtonRole? = nil,
		isDefaultSwipe: Bool = false,
		action: @escaping @MainActor () -> Void
	) {
		self.id = id ?? systemImage
		self.title = title
		self.systemImage = systemImage
		self.role = role
		self.isDefaultSwipe = isDefaultSwipe
		self.action = action
	}

	/// The overwhelmingly common case: a destructive **Delete**.
	public static func delete(_ action: @escaping @MainActor () -> Void) -> RowAction {
		RowAction(
			id: "delete",
			title: Text("Delete", bundle: .module),
			systemImage: "trash",
			role: .destructive,
			isDefaultSwipe: true,
			action: action
		)
	}
}

// MARK: - rowActions modifier

extension View {
	/// Attaches a uniform set of row actions: a `contextMenu` everywhere, plus a
	/// trailing `swipeActions` group where the platform supports it (not macOS /
	/// tvOS, which have no swipe-to-delete). Use inside any `List` row — with or
	/// without ``EntityList`` — so swipe and context menus are declared once.
	@ViewBuilder
	public func rowActions(_ actions: [RowAction]) -> some View {
		if actions.isEmpty {
			self
		} else {
			#if os(watchOS)
				let menu = self
			#else
				let menu = contextMenu {
					ForEach(actions) { action in
						rowActionButton(action)
					}
				}
			#endif
			#if os(macOS) || os(tvOS)
				menu
			#else
				// `allowsFullSwipe: false` on purpose: with a full-swipe destructive
				// action the system shows the action *twice* while dragging (the
				// button plus the expanding red fill), which read as two Delete
				// buttons. Explicit buttons only — one per action, in declared order.
				menu.swipeActions(edge: .trailing, allowsFullSwipe: false) {
					ForEach(actions) { action in
						rowActionButton(action)
					}
				}
			#endif
		}
	}
}

/// One row-action button, shared by the context menu and the swipe group.
/// macOS context menus don't tint a `.destructive` role, so the destructive
/// item is coloured red here — so every list shows a red Delete, not just iOS.
@MainActor @ViewBuilder
private func rowActionButton(_ action: RowAction) -> some View {
	let button = Button(role: action.role, action: action.action) {
		Label {
			action.title
		} icon: {
			Image(systemName: action.systemImage)
		}
	}
	#if os(macOS)
		if action.role == .destructive {
			button.foregroundStyle(.red)
		} else {
			button
		}
	#else
		button
	#endif
}

// MARK: - EntityList

/// A generic, cross-platform `List` that unifies selection, per-row actions
/// (swipe + context menu) and optional scroll-to-selection — replacing the
/// hand-rolled list code across the app.
///
/// The caller supplies the items, a row builder and, per item, a list of
/// ``RowAction``s. Navigation is *not* the component's concern: put a
/// `NavigationLink` in the row, or keep a `.navigationDestination` on the
/// container — selection and navigation stay orthogonal.
///
/// ```swift
/// EntityList(voyages, selection: $selected) { voyage in
///     NavigationLink { Detail(voyage) } label: { VoyageRow(voyage: voyage) }
/// } actions: { voyage in
///     [ .delete { delete(voyage) } ]
/// }
/// ```
public struct EntityList<Item: Identifiable, SelectionValue: Hashable, Row: View>: View {

	private let items: [Item]
	private let selection: Binding<SelectionValue?>?
	/// Maps an item to its `.tag` / scroll `.id` value. `nil` when the list does
	/// not drive `List(selection:)`.
	private let tag: ((Item) -> SelectionValue)?
	private let scrollsToSelection: Bool
	private let row: (Item) -> Row
	private let actions: (Item) -> [RowAction]

	/// The one designated initialiser every public entry point funnels through.
	private init(
		items: [Item],
		selection: Binding<SelectionValue?>?,
		tag: ((Item) -> SelectionValue)?,
		scrollsToSelection: Bool,
		row: @escaping (Item) -> Row,
		actions: @escaping (Item) -> [RowAction]
	) {
		self.items = items
		self.selection = selection
		self.tag = tag
		self.scrollsToSelection = scrollsToSelection
		self.row = row
		self.actions = actions
	}

	/// A list whose rows feed `List(selection:)`.
	/// - Parameters:
	///   - items: The rows' data.
	///   - selection: Binding to the highlighted row's value.
	///   - tag: The selection value for an item (its `.tag` and scroll `.id`).
	///   - scrollsToSelection: Whether to scroll the selected row into view (e.g.
	///     for a Spotlight deep-link), via a `ScrollViewReader`.
	///   - row: The row's content.
	///   - actions: The row's actions (swipe + context menu).
	public init(
		_ items: [Item],
		selection: Binding<SelectionValue?>,
		tag: @escaping (Item) -> SelectionValue,
		scrollsToSelection: Bool = false,
		@ViewBuilder row: @escaping (Item) -> Row,
		actions: @escaping (Item) -> [RowAction] = { _ in [] }
	) {
		self.init(
			items: items, selection: selection, tag: tag,
			scrollsToSelection: scrollsToSelection, row: row, actions: actions
		)
	}

	/// The content and behaviour of the view.
	public var body: some View {
		if scrollsToSelection, let selection {
			ScrollViewReader { proxy in
				list
					.onChange(of: selection.wrappedValue) { _, value in
						guard let value else { return }
						withAnimation { proxy.scrollTo(value, anchor: .center) }
					}
			}
		} else {
			list
		}
	}

	@ViewBuilder
	private var list: some View {
		Group {
			if let selection {
				List(selection: selection) { rows }
			} else {
				List { rows }
			}
		}
		#if os(iOS)
			.listStyle(.plain)
		#endif
	}

	private var rows: some View {
		ForEach(items) { item in
			taggedRow(item)
		}
	}

	@ViewBuilder
	private func taggedRow(_ item: Item) -> some View {
		let content = row(item).rowActions(actions(item))
		if let tag {
			// The row's id matches its tag so `ScrollViewReader.scrollTo(tag)`
			// finds it; the tag value is 1:1 with the item, so identity is stable.
			content.tag(tag(item)).id(tag(item))
		} else {
			content
		}
	}
}

extension EntityList where SelectionValue == Item.ID {
	/// A selecting list keyed by the items' own `id`.
	public init(
		_ items: [Item],
		selection: Binding<Item.ID?>,
		scrollsToSelection: Bool = false,
		@ViewBuilder row: @escaping (Item) -> Row,
		actions: @escaping (Item) -> [RowAction] = { _ in [] }
	) {
		self.init(
			items, selection: selection, tag: { $0.id },
			scrollsToSelection: scrollsToSelection, row: row, actions: actions
		)
	}
}

extension EntityList where SelectionValue == Never {
	/// A list that does not drive `List(selection:)` — for callers that manage
	/// their own highlight (e.g. a tap that sets an "active" id) but still want
	/// uniform row actions.
	public init(
		_ items: [Item],
		@ViewBuilder row: @escaping (Item) -> Row,
		actions: @escaping (Item) -> [RowAction] = { _ in [] }
	) {
		self.init(
			items: items, selection: nil, tag: nil, scrollsToSelection: false,
			row: row, actions: actions
		)
	}
}

// MARK: - ListControlBar

/// A small `+` / `−` bar shown beneath an editable list (add an item, remove the
/// selected one). Kept separate from ``EntityList`` because it sits *below* the
/// list and its `add` control is caller-specific (a button, a menu or a link).
public struct ListControlBar<Add: View>: View {
	private let canRemove: Bool
	private let remove: () -> Void
	private let add: () -> Add

	/// Creates a control bar.
	/// - Parameters:
	///   - canRemove: Whether the `−` button is enabled (something is selected).
	///   - remove: Removes the current selection.
	///   - add: The leading `+` control (button, menu or link).
	public init(
		canRemove: Bool,
		remove: @escaping () -> Void,
		@ViewBuilder add: @escaping () -> Add
	) {
		self.canRemove = canRemove
		self.remove = remove
		self.add = add
	}

	/// The content and behaviour of the view.
	public var body: some View {
		HStack(spacing: 0) {
			// The borderless style must sit on each control, not the `HStack`: on a
			// `NavigationLink` add-button it suppresses the Form-row chevron and the
			// greedy width that would otherwise push the `−` to the trailing edge.
			add()
				.buttonStyle(.borderless)
			Divider().frame(height: 16)
			Button(action: remove) {
				Image(systemName: "minus")
					.frame(width: 28, height: 20)
			}
			.buttonStyle(.borderless)
			.disabled(!canRemove)
			Spacer()
		}
		.font(.body)
	}
}

// MARK: - Previews

#if DEBUG
	// `internal` (not `private`) so the snapshot test target can render it and
	// exercise this preview's view code; it stays inside `#if DEBUG`.
	struct EntityListPreview: View {
		private struct Port: Identifiable {
			let id: Int
			let name: String
		}

		@State private var ports = [
			Port(id: 1, name: "Monaco"),
			Port(id: 2, name: "Ajaccio"),
			Port(id: 3, name: "La Maddalena"),
		]
		@State private var selection: Int?

		var body: some View {
			VStack(spacing: 0) {
				EntityList(ports, selection: $selection, scrollsToSelection: true) { port in
					Text(port.name)
				} actions: { port in
					[
						RowAction(title: Text(verbatim: "Pin"), systemImage: "pin") {},
						.delete { ports.removeAll { $0.id == port.id } },
					]
				}
				ListControlBar(
					canRemove: selection != nil,
					remove: {
						ports.removeAll { $0.id == selection }
						selection = nil
					}
				) {
					Button {
						ports.append(Port(id: (ports.map(\.id).max() ?? 0) + 1, name: "New port"))
					} label: {
						Image(systemName: "plus")
					}
				}
				.padding(.horizontal)
			}
		}
	}

	#Preview("EntityList — selection, actions, control bar") {
		EntityListPreview()
	}
#endif
