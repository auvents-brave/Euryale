public import SwiftUI

// MARK: - PopupPresenter

/// A SwiftUI presenter that shows arbitrary content in a popover (regular size
/// class) or a sheet (compact / tvOS / watchOS), driven by a tap on a custom
/// `trigger` view.
///
/// Use it to build inline expand-able UI such as the map button in
/// ``PopupMapView`` and the link button in ``PopupWebView``.
///
/// ```swift
/// PopupPresenter {
///     Image(systemName: "info.circle")
/// } presentedContent: {
///     DetailView()
/// }
/// ```
public struct PopupPresenter<Trigger: View, PresentedContent: View>: View {

	// MARK: Properties

	#if os(iOS)
		@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	#endif

	@State private var isPresented = false

	private let regularWidth: CGFloat
	private let regularHeight: CGFloat
	private let trigger: () -> Trigger
	private let presentedContent: () -> PresentedContent

	// MARK: Init

	/// Creates a popup presenter.
	///
	/// - Parameters:
	///   - regularWidth: Width used when the presented content is constrained
	///     (popover on iPadOS / macOS, sheet on visionOS).  Defaults to 720 on
	///     visionOS and 400 elsewhere.
	///   - regularHeight: Height used in the same constrained contexts.
	///     Defaults to 900 on visionOS and 500 elsewhere.
	///   - trigger: A view builder for the tappable trigger view.
	///   - presentedContent: A view builder for the popup body.
	public init(
		regularWidth: CGFloat? = nil,
		regularHeight: CGFloat? = nil,
		@ViewBuilder trigger: @escaping () -> Trigger,
		@ViewBuilder presentedContent: @escaping () -> PresentedContent
	) {
		self.regularWidth = regularWidth ?? Self.defaultRegularWidth
		self.regularHeight = regularHeight ?? Self.defaultRegularHeight
		self.trigger = trigger
		self.presentedContent = presentedContent
	}

	// MARK: Body

	/// The content and behaviour of the view.
	public var body: some View {
		Button {
			isPresented = true
		} label: {
			trigger()
				#if os(tvOS)
					.padding(.horizontal, 20)
					.padding(.vertical, 12)
					.contentShape(Rectangle())
				#endif
		}
		#if os(tvOS)
			.buttonStyle(.card)
			.focusable(true)
		#endif
		.popupPresentation(isPresented: $isPresented) {
			presentedContent()
				.frame(
					width: usesConstrainedSize ? regularWidth : nil,
					height: usesConstrainedSize ? regularHeight : nil
				)
		}
	}

	// MARK: Helpers

	private var usesConstrainedSize: Bool {
		#if os(iOS)
			horizontalSizeClass != .compact
		#else
			true
		#endif
	}

	private static var defaultRegularWidth: CGFloat {
		#if os(visionOS)
			720
		#else
			400
		#endif
	}

	private static var defaultRegularHeight: CGFloat {
		#if os(visionOS)
			900
		#else
			500
		#endif
	}
}

// MARK: - Popup presentation modifier

extension View {

	/// Presents `content` as a popover on a pointer device (iPadOS, macOS,
	/// visionOS) and a half-height, drag-dismissable sheet when the width is
	/// compact (iPhone); a plain sheet on tvOS and watchOS, which have no popover.
	///
	/// This is the presentation ``PopupPresenter`` uses; expose it directly for
	/// callers whose trigger is not a SwiftUI view — e.g. a tap on a map
	/// annotation — and so drive the same behaviour from an `item` binding.
	///
	/// - Parameters:
	///   - isPresented: Drives whether the popup is shown.
	///   - backgroundInteraction: When `true`, the compact sheet lets the content
	///     behind it stay interactive (so a map under the sheet still pans).
	///   - content: The popup body.
	public func popupPresentation<PopupContent: View>(
		isPresented: Binding<Bool>,
		backgroundInteraction: Bool = false,
		@ViewBuilder content: @escaping () -> PopupContent
	) -> some View {
		#if os(tvOS) || os(watchOS)
			sheet(isPresented: isPresented) { content() }
		#else
			popover(isPresented: isPresented) {
				popupAdapted(content(), backgroundInteraction: backgroundInteraction)
			}
		#endif
	}

	/// The `item`-driven companion to ``popupPresentation(isPresented:backgroundInteraction:content:)``,
	/// for a popup opened by selecting a value rather than tapping a trigger view.
	///
	/// - Parameter anchorPoint: Where, within the source view, the popover's arrow
	///   points (a unit point, `nil` to anchor to the view's bounds). Use it to point
	///   the popover at the selected element — e.g. a tapped map annotation — rather
	///   than the whole view. Ignored by the compact sheet.
	public func popupPresentation<Item: Identifiable, PopupContent: View>(
		item: Binding<Item?>,
		anchorPoint: UnitPoint? = nil,
		backgroundInteraction: Bool = false,
		@ViewBuilder content: @escaping (Item) -> PopupContent
	) -> some View {
		#if os(tvOS) || os(watchOS)
			sheet(item: item) { content($0) }
		#else
			popover(item: item, attachmentAnchor: anchorPoint.map { .point($0) } ?? .rect(.bounds)) { value in
				popupAdapted(content(value), backgroundInteraction: backgroundInteraction)
			}
		#endif
	}
}

/// Applies the compact-width sheet behaviour shared by both popup entry points.
/// Internal (not private) so it can be unit-tested directly.
@ViewBuilder
func popupAdapted(_ content: some View, backgroundInteraction: Bool) -> some View {
	#if os(iOS)
		content
			.presentationCompactAdaptation(.sheet)
			.presentationDetents([.medium, .large])
			.presentationDragIndicator(.visible)
			.presentationBackgroundInteraction(backgroundInteraction ? .enabled(upThrough: .medium) : .automatic)
	#else
		content
	#endif
}

// MARK: - Previews

#if DEBUG
	#Preview("PopupPresenter") {
		PopupPresenter {
			Label("Details", systemImage: "info.circle")
		} presentedContent: {
			VStack(spacing: 12) {
				Image(systemName: "sailboat").font(.largeTitle)
				Text(verbatim: "Popover on a pointer device, sheet when compact.")
					.multilineTextAlignment(.center)
			}
			.padding()
		}
		.padding()
	}
#endif
