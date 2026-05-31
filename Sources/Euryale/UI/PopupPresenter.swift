public import SwiftUI

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

// MARK: - PopupPresenter

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

    // MARK: Init

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
		.modifier(
			PopupPresentationModifier(
				isPresented: $isPresented,
				popupContent: popupBody
			)
		)
	}

	// MARK: Helpers

	@ViewBuilder
	private var popupBody: some View {
		presentedContent()
			.frame(
				width: usesConstrainedSize ? regularWidth : nil,
				height: usesConstrainedSize ? regularHeight : nil
			)
#if os(iOS)
			.presentationCompactAdaptation(.sheet)
			.presentationDetents([.medium, .large])
			.presentationDragIndicator(.visible)
#endif
	}

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

// MARK: - PopupPresentationModifier

private struct PopupPresentationModifier<PopupContent: View>: ViewModifier {
	@Binding var isPresented: Bool
	let popupContent: PopupContent

	func body(content: Content) -> some View {
#if os(tvOS) || os(watchOS)
		content.sheet(isPresented: $isPresented) {
			popupContent
		}
#else
		content.popover(isPresented: $isPresented) {
			popupContent
		}
#endif
	}
}
