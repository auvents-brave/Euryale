public import SwiftUI

/// Where a host's adaptive toolbar sits.
public enum AdaptiveToolbarPlacement: Sendable {
	/// Along the foot of the view — the floating command bar.
	case bottom
	/// With the host's other primary actions, trailing.
	case primary
}

extension View {

	/// Puts these actions in a toolbar that belongs to the system where there
	/// is one, and to us where there is not.
	///
	/// From OS 26 the system draws real Liquid Glass bars, and anything we paint
	/// beside one reads as an imitation of it — so from 26 the actions go into
	/// the host's own `toolbar`, and only before that into the floating capsule
	/// ``AdaptiveToolbar`` draws. Hosts therefore stop testing the system
	/// version themselves; this is the one place that knows.
	///
	/// - Important: On OS 26 the actions land in the host's toolbar, which needs
	///   a navigation container — a `NavigationStack`, or a `Tab`'s content.
	///   Without one there is nowhere for them to go and they will not appear.
	///
	/// - Parameters:
	///   - groups: The actions, in groups a divider separates.
	///   - placement: Where they sit.
	public func adaptiveToolbar(
		groups: [[ToolbarAction]],
		placement: AdaptiveToolbarPlacement = .bottom
	) -> some View {
		modifier(AdaptiveToolbarModifier(groups: groups, placement: placement))
	}

	/// Puts one ungrouped list of actions in that toolbar.
	/// - Parameters:
	///   - actions: The actions to show.
	///   - placement: Where they sit.
	public func adaptiveToolbar(
		_ actions: [ToolbarAction],
		placement: AdaptiveToolbarPlacement = .bottom
	) -> some View {
		adaptiveToolbar(groups: [actions], placement: placement)
	}
}

/// Chooses between the system's toolbar and ours, once, for every host.
private struct AdaptiveToolbarModifier: ViewModifier {

	let groups: [[ToolbarAction]]
	let placement: AdaptiveToolbarPlacement

	private var actions: [ToolbarAction] { groups.flatMap(\.self) }

	@ContentBuilder
	func body(content: Content) -> some View {
		if actions.isEmpty {
			content
		} else {
			#if os(watchOS)
				// No floating bar and no window toolbar: the watch's hosts place
				// their own single control.
				content
			#else
				if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) {
					content.toolbar { systemItems }
				} else {
					content.safeAreaInset(edge: .bottom) { capsule }
				}
			#endif
		}
	}

	#if !os(watchOS)
		@available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
		@ToolbarContentBuilder private var systemItems: some ToolbarContent {
			ToolbarItemGroup(placement: systemPlacement) {
				ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
					if index > 0 { Divider() }
					ForEach(group) { action in
						ToolbarActionButton(action)
					}
				}
			}
		}

		@available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
		private var systemPlacement: ToolbarItemPlacement {
			switch placement {
			case .bottom:
				#if os(macOS)
					.primaryAction  // macOS has no bottom bar
				#else
					.bottomBar
				#endif
			case .primary: .primaryAction
			}
		}

		/// The floating capsule, for the systems with no bar of their own.
		private var capsule: some View {
			AdaptiveToolbar(groups: groups)
				.padding(.horizontal)
				.padding(.bottom, 6)
				.frame(maxWidth: .infinity, alignment: .center)
		}
	#endif
}
