public import MapKit
public import SwiftUI

// MARK: - PopupMapView

/// A SwiftUI button that opens an embedded ``MapKitView`` in a popover, with
/// an additional "Open in Maps" button to launch the system Maps app at the
/// same coordinate.
///
/// On watchOS the popover is replaced by a direct call to `MKMapItem.openInMaps`
/// (popovers are unavailable there).  On tvOS the "Open in Maps" button is
/// hidden (Maps app is not available on tvOS).
///
/// ```swift
/// PopupMapView(
///     region: MKCoordinateRegion(center: ..., span: ...),
///     title: "Apple Park",
///     annotationTitle: "Apple Park",
///     overlays: [(cacheDirectory: "osmcache",
///                 urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")]
/// )
/// ```
public struct PopupMapView: View {

	// MARK: Properties

	var region: MKCoordinateRegion
	var title: String?
	var annotationTitle: String?
	var overlays: [(cacheDirectory: String, urlTemplate: String)] = []

	// MARK: Init

	/// Creates a popup map presenter.
	///
	/// - Parameters:
	///   - region: The initial visible region of the embedded map.
	///   - title: Optional label used as the trigger button title on watchOS
	///     and as the `MKMapItem` name when opening in Maps.
	///   - annotationTitle: Optional annotation label shown on the embedded
	///     map and used as the `MKMapItem` name (falls back to `title`).
	///   - overlays: Optional cached XYZ/TMS tile overlays stacked on top of
	///     the Apple Maps base layer — see ``MapKitView``.
	public init(
		region: MKCoordinateRegion,
		title: String? = nil,
		annotationTitle: String? = nil,
		overlays: [(cacheDirectory: String, urlTemplate: String)] = []
	) {
		self.region = region
		self.title = title
		self.annotationTitle = annotationTitle
		self.overlays = overlays
	}

	// MARK: Body

	public var body: some View {
		#if os(watchOS)
			Button(title ?? annotationTitle ?? "Open in Maps") {
				mapItem(for: region.center, title: annotationTitle ?? title)
					.openInMaps(launchOptions: nil)
			}
			.accessibilityIdentifier("PopupMapView.button")
		#else
			HStack {
				PopupPresenter {
					Image(systemName: "map")
				} presentedContent: {
					ZStack(alignment: .bottomTrailing) {
						MapKitView(initialRegion: region, overlays: overlays)
							.frame(maxWidth: .infinity, maxHeight: .infinity)

						#if !os(tvOS)
							Button {
								_ = mapItem(for: region.center, title: annotationTitle ?? title)
									.openInMaps(launchOptions: nil)
							} label: {
								Label {
									Text("Open in Maps", bundle: .module)
								} icon: {
									Image(systemName: "map")
								}
							}
							.padding(.trailing, 20)
							.padding(.bottom, 20)
							.PreferredAvailableButtonStyle()
							.accessibilityIdentifier("PopupMapView.openInMaps")
						#endif
					}
				}
			}
			.accessibilityIdentifier("PopupMapView.button")
		#endif
	}

	// MARK: Helpers

	private func mapItem(for coordinate: CLLocationCoordinate2D, title: String?) -> MKMapItem {
		let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
		if let title, !title.isEmpty {
			item.name = title
		}
		return item
	}
}

// MARK: - Previews

#Preview("No title") {
	PopupMapView(
		region: MKCoordinateRegion(
			center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
			span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
		)
	)
}

#Preview("With title and annotation") {
	PopupMapView(
		region: MKCoordinateRegion(
			center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
			span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
		),
		title: "Apple Park",
		annotationTitle: "Apple Park"
	)
}

#Preview("In List") {
	List {
		PopupMapView(
			region: MKCoordinateRegion(
				center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
				span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
			),
			title: "San Francisco",
			annotationTitle: "SF",
			overlays: [
				(
					cacheDirectory: "opentopomapcache",
					urlTemplate: "https://a.tile.opentopomap.org/{z}/{x}/{y}.png"
				)
			]
		)
		PopupMapView(
			region: MKCoordinateRegion(
				center: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
				span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
			),
			title: "Los Angeles"
		)
	}
}
