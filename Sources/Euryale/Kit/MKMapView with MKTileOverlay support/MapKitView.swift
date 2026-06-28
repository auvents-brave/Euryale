public import MapKit
internal import Stheno
public import SwiftUI

/// Which points of interest a ``MapKitView`` displays.
///
/// A cross-platform selection that maps to `MKPointOfInterestFilter` on the
/// UIKit/AppKit map and to `PointOfInterestCategories` on the watchOS SwiftUI
/// map, so callers express intent once. See ``MapKitView/pointsOfInterest(_:)``.
public enum MapPointsOfInterest: Sendable, Equatable {
	/// Show the map's full set of points of interest.
	case all
	/// Hide every point of interest.
	case none
	/// Show only the given categories.
	case including([MKPointOfInterestCategory])

	/// The UIKit/AppKit map filter, or `nil` for the default (all).
	var mkFilter: MKPointOfInterestFilter? {
		switch self {
		case .all: nil
		case .none: .excludingAll
		case .including(let categories): MKPointOfInterestFilter(including: categories)
		}
	}

	#if os(watchOS)
		// `PointOfInterestCategories` comes from the `_MapKit_SwiftUI` cross-import
		// overlay, which command-line `swift build` (CodeQL / SonarCloud) does not
		// load — only the watchOS map consumes it, so it is gated to that platform.
		/// The SwiftUI-map representation, used by the watchOS map.
		@available(watchOS 10, *)
		var categories: PointOfInterestCategories {
			switch self {
			case .all: .all
			case .none: .excludingAll
			case .including(let categories): .including(categories)
			}
		}
	#endif
}

/// How a ``MapKitView`` is oriented — which direction points up. The map's
/// rotation is locked to this; the user cannot rotate it by gesture.
public enum MapOrientation: Sendable, Equatable {
	/// North at the top (the default).
	case northUp
	/// The boat's compass heading at the top.
	case headUp
	/// The boat's course over ground at the top.
	case courseUp
}

/// A WMS tile source for a ``MapKitView`` underlay layer.
///
/// Tiles are fetched per `z/x/y` as WMS `GetMap` requests — the bounding box is
/// computed in Web Mercator — and disk-cached like any other overlay. Not shown
/// on the watchOS map. See ``MapKitView/wmsUnderlay(_:)``.
public struct WMSTileSource: Sendable, Equatable {
	/// The cache sub-folder name for this source's tiles.
	public let cacheDirectory: String
	/// The full WMS `GetMap` URL, percent-encoded, **without** the trailing
	/// `&BBOX=` value (the overlay appends one per tile).
	public let getMapBaseURL: String

	/// Creates a WMS tile source.
	/// - Parameters:
	///   - cacheDirectory: The cache sub-folder for the fetched tiles.
	///   - getMapBaseURL: The WMS `GetMap` URL without the trailing `&BBOX=` value.
	public init(cacheDirectory: String, getMapBaseURL: String) {
		self.cacheDirectory = cacheDirectory
		self.getMapBaseURL = getMapBaseURL
	}
}

/// A plain XYZ ("slippy map") tile source used as the map's **base** layer,
/// replacing Apple's base map where its tiles cover — e.g. OpenStreetMap.
///
/// Unlike ``WMSTileSource`` (a transparent underlay) this is opaque and drawn at
/// the very bottom with `canReplaceMapContent`, so Apple's own base is hidden.
/// Tiles are disk-cached like any other overlay. Not shown on the watchOS map.
/// See ``MapKitView/baseTileSource(_:)``.
///
/// - Important: When pointing this at a community tile server such as
///   `tile.openstreetmap.org`, honour that server's tile-usage policy and show
///   the required attribution — those tiles are not licensed for heavy app use.
public struct MapTileSource: Sendable, Equatable {
	/// The cache sub-folder name for this source's tiles.
	public let cacheDirectory: String
	/// The slippy-map URL template, with `{z}`/`{x}`/`{y}` placeholders.
	public let urlTemplate: String
	/// An optional App Group whose shared container caches the tiles.
	public let appGroup: String?

	/// Creates a base tile source.
	/// - Parameters:
	///   - cacheDirectory: The cache sub-folder for the fetched tiles.
	///   - urlTemplate: The `{z}/{x}/{y}` tile URL template.
	///   - appGroup: An optional App Group identifier for a shared tile cache.
	public init(cacheDirectory: String, urlTemplate: String, appGroup: String? = nil) {
		self.cacheDirectory = cacheDirectory
		self.urlTemplate = urlTemplate
		self.appGroup = appGroup
	}
}

/// The values a ``MapKitView`` carries from its view modifiers. Held by both
/// platform variants of the view (and its representable) so the field list is
/// declared once instead of repeated per platform.
struct MapViewConfiguration {
	/// The cached tile overlays (cache dir + URL template) added once when the map
	/// is first made — NOT on every SwiftUI update. Set by the initialisers.
	var tileOverlays: [(cacheDirectory: String, urlTemplate: String)] = []
	/// The region the map is centred on when first made (see `init(initialRegion:)`).
	var initialRegion: MKCoordinateRegion?
	/// Position markers to draw (see `marking(_:)`).
	var markers: [MapMarker] = []
	/// Styled polylines to draw (see `tracking(_:)`).
	var tracks: [MapTrack] = []
	/// The coordinate for initial centring / recentring (see `centering(on:recenterToken:)`).
	var centerCoordinate: Coordinate?
	/// Changing this token recentres the map on ``centerCoordinate``.
	var recenterToken: AnyHashable = 0
	/// When `true`, the map stays continuously centred on ``centerCoordinate`` (see `following(_:)`).
	var continuousFollow = false
	/// Whether the user can interact with the map (see `interactive(_:)`).
	var isInteractive = true
	/// Latitude/longitude span used when (re)centring (see `following(_:span:)`).
	var zoomSpan: Double = 0.02
	/// Called with a marker's id when it is tapped. See `onMarkerSelected(_:)`.
	var onSelectMarker: ((AnyHashable) -> Void)?
	/// Called when the visible region settles after a gesture. See `onVisibleRegion(_:)`.
	var onRegionSettled: ((MapVisibleRegion) -> Void)?
	/// Called with the chart coordinate of a tap on open water. See `onMapTap(_:)`.
	var onMapTap: ((Coordinate) -> Void)?
	/// Called with the chart coordinate of a long-press / right-click on open
	/// water — for a context menu. See `onMapLongPress(_:)`.
	var onMapLongPress: ((Coordinate) -> Void)?
	/// Which points of interest the map shows. See `pointsOfInterest(_:)`.
	var pointOfInterestFilter: MapPointsOfInterest = .all
	/// An optional WMS underlay drawn beneath the tile overlays. See `wmsUnderlay(_:)`.
	var wmsUnderlay: WMSTileSource?
	/// An optional slippy-map base layer (e.g. OpenStreetMap) replacing Apple's
	/// base map; `nil` keeps Apple Maps. See `baseTileSource(_:)`.
	var baseTileSource: MapTileSource?
	/// Which way is up — the map's rotation is locked to this. See `orientation(_:course:heading:)`.
	var orientation: MapOrientation = .northUp
	/// Course over ground (degrees), driving course-up and the autoscroll offset.
	var courseDegrees: Double?
	/// Compass heading (degrees), driving head-up.
	var headingDegrees: Double?
	/// When `true`, the camera follows the boat, auto-zooms and locks scroll/zoom. See `autoScroll(_:speedKnots:destination:)`.
	var autoscroll = false
	/// Speed over ground (knots), for the speed-based autoscroll zoom.
	var speedKnots: Double?
	/// The active destination / next waypoint, for the autoscroll zoom.
	var destination: Coordinate?
}

#if os(watchOS)
	// MARK: - MapViewModel

	@Observable class MapViewModel {

		// MARK: Properties

		var position: MapCameraPosition
		var span: MKCoordinateSpan

		// MARK: Init

		init(initialRegion: MKCoordinateRegion) {
			position = MapCameraPosition.region(initialRegion)
			span = initialRegion.span
		}

		// MARK: Public API

		/// Recentres the camera on the given region.
		/// - Parameter newRegion: The region to display.
		public func setRegion(_ newRegion: MKCoordinateRegion) {
			position = MapCameraPosition.region(newRegion)
			span = newRegion.span
		}
	}

	// MARK: - MapKitView

	/// A SwiftUI view that wraps an MKMapView and supports multiple cached tile overlays.
	public struct MapKitView: View {

		// MARK: State

		@State var viewModel: MapViewModel

		/// Everything this view carries from its modifiers.
		var config = MapViewConfiguration()

		/// Whether the one-shot initial centring has already happened.
		@State private var didInitialCenter = false

		// MARK: Init

		/// Creates a map view without any tile overlays.
		public init() {
			self.init(overlays: [])
		}

		/// Creates a map view with a single tile overlay.
		///
		/// - Parameters:
		///   - cacheDirectory: The directory to cache map tiles.
		///   - urlTemplate: The URL template string for the tile overlay.
		public init(cacheDirectory: String, urlTemplate: String) {
			self.init(overlays: [(cacheDirectory: cacheDirectory, urlTemplate: urlTemplate)])
		}

		/// Creates a map view with multiple tile overlays.
		///
		/// - Parameter overlays: An array of tuples, each pairing a cache directory with a URL template.
		public init(overlays: [(cacheDirectory: String, urlTemplate: String)]) {
			let region = MKCoordinateRegion(
				center: CLLocationCoordinate2D(
					latitude: 20,
					longitude: 0
				),
				span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
			)
			viewModel = MapViewModel(initialRegion: region)
		}

		/// Creates a map view with an initial region and optional tile overlays.
		///
		/// - Parameters:
		///   - initialRegion: The starting region for the map.
		///   - overlays: Overlay specifications; ignored on watchOS but kept for API parity.
		public init(initialRegion: MKCoordinateRegion, overlays: [(cacheDirectory: String, urlTemplate: String)] = []) {
			// overlays are ignored on watchOS for now; kept for API parity
			let region = initialRegion
			viewModel = MapViewModel(initialRegion: region)
		}

		// MARK: Public API

		/// Centres the map on the given region.
		public func setRegion(_ newRegion: MKCoordinateRegion) {
			viewModel.setRegion(newRegion)
		}

		// MARK: Body

		public var body: some View {
			if #available(watchOS 12, *) {
				Map(position: $viewModel.position, interactionModes: config.isInteractive ? .all : []) {
					markerAndTrackContent
				}
				.mapStyle(.standard(pointsOfInterest: config.pointOfInterestFilter.categories))
				.ignoresSafeArea()
				.accessibilityIdentifier("MapKitView.map")
				// Initial centring, or continuous follow when requested.
				.onChange(of: config.centerCoordinate, initial: true) { _, newValue in
					guard let newValue else { return }
					if config.continuousFollow {
						viewModel.setRegion(
							MKCoordinateRegion(
								center: CLLocationCoordinate2D(newValue),
								span: MKCoordinateSpan(latitudeDelta: config.zoomSpan, longitudeDelta: config.zoomSpan)
							))
						didInitialCenter = true
					} else if !didInitialCenter {
						viewModel.setRegion(
							MKCoordinateRegion(
								center: CLLocationCoordinate2D(newValue),
								span: MKCoordinateSpan(latitudeDelta: config.zoomSpan, longitudeDelta: config.zoomSpan)
							))
						didInitialCenter = true
					}
				}
				// Explicit recentre request (keeps the current zoom).
				.onChange(of: config.recenterToken) { _, _ in
					guard let centerCoordinate = config.centerCoordinate else { return }
					viewModel.setRegion(
						MKCoordinateRegion(
							center: CLLocationCoordinate2D(centerCoordinate),
							span: viewModel.span
						))
				}
			} else {
				Text("Not supported", bundle: .module)
					.accessibilityIdentifier("MapKitView.map")
			}
		}
	}
#else
	// MARK: - MapKitView

	/// A SwiftUI view that wraps an MKMapView and supports multiple cached tile overlays.
	public struct MapKitView: View {

		// MARK: Properties

		/// Everything this view carries from its modifiers and initialisers. The
		/// `MKMapView` itself is owned by the persistent coordinator (created once),
		/// NOT here — this struct is re-created on every SwiftUI update, so holding
		/// the map (and its overlays) here would re-allocate it dozens of times a
		/// second and stop the chart from ever settling.
		var config = MapViewConfiguration()

		// MARK: Init

		/// Creates a MapKitView instance without any tile overlays.
		public init() {
			self.init(overlays: [])
		}

		/// Creates a MapKitView instance with a single tile overlay specified by cache directory and URL template.
		///
		/// - Parameters:
		///   - cacheDirectory: The directory to cache map tiles.
		///   - urlTemplate: The URL template string for the tile overlay.
		public init(cacheDirectory: String, urlTemplate: String) {
			self.init(overlays: [(cacheDirectory: cacheDirectory, urlTemplate: urlTemplate)])
		}

		/// Creates a MapKitView instance with multiple tile overlays.
		///
		/// - Parameter overlays: An array of tuples where each contains a cache directory and URL template.
		public init(overlays: [(cacheDirectory: String, urlTemplate: String)]) {
			config.tileOverlays = overlays
		}

		/// Creates a MapKitView with an initial region and optional tile overlays.
		/// - Parameters:
		///   - initialRegion: The starting region for the map.
		///   - overlays: An array of overlay specifications (cache directory and URL template).
		public init(initialRegion: MKCoordinateRegion, overlays: [(cacheDirectory: String, urlTemplate: String)] = []) {
			config.tileOverlays = overlays
			config.initialRegion = initialRegion
		}

		// MARK: Public API

		/// Centres the map on the given region when it is first made.
		///
		/// A modifier (the map is created once by the coordinator, so this records
		/// the region in the configuration rather than mutating a live map view).
		@discardableResult
		public func setRegion(_ region: MKCoordinateRegion) -> MapKitView {
			var copy = self
			copy.config.initialRegion = region
			return copy
		}

		// MARK: Body

		/// The SwiftUI view that wraps the MKMapView (with its tile overlays) and
		/// applies the markers, tracks and follow target.
		public var body: some View {
			MarkableMapRepresentable(config: config)
				.ignoresSafeArea()
				.accessibilityIdentifier("MapKitView.map")
		}
	}
#endif

// MARK: - Previews

/// Preview showing a plain MapKitView without any overlays.
@available(watchOS 12, *)
#Preview("Plain") {
	MapKitView()
}

/// Preview showing a MapKitView with OpenStreetMap tile overlay.
@available(watchOS 12, *)
#Preview("OpenStreetMap") {
	let v = MapKitView(
		cacheDirectory: "openstreetmapcache", urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
	v.setRegion(
		MKCoordinateRegion(
			center: CLLocationCoordinate2D(latitude: 43.7384, longitude: 7.4246),
			span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
	return v
}

/// Preview showing a MapKitView with OpenTopoMap tile overlay.
@available(watchOS 12, *)
#Preview("OpenTopoMap") {
	let v = MapKitView(
		cacheDirectory: "opentopomapcache", urlTemplate: "https://a.tile.opentopomap.org/{z}/{x}/{y}.png")
	v.setRegion(
		MKCoordinateRegion(
			center: CLLocationCoordinate2D(latitude: 44.9224, longitude: 6.3608),
			span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
	return v
}

/// Preview showing a MapKitView with IGN (France) WMTS tile overlay.
/// See: https://geoservices.ign.fr/services-web-essentiels
@available(watchOS 12, *)
#Preview("IGN (France)") {
	let v = MapKitView(
		cacheDirectory: "igncache",
		urlTemplate:
			"https://data.geopf.fr/wmts?layer=GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2&style=normal&tilematrixset=PM&Service=WMTS&Request=GetTile&Version=1.0.0&Format=image%2Fpng&TileMatrix={z}&TileCol={x}&TileRow={y})"
	)
	v.setRegion(
		MKCoordinateRegion(
			center: CLLocationCoordinate2D(latitude: 44.9224, longitude: 6.3608),
			span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
	return v
}

/// Preview showing a MapKitView with Carte de Cassini (France XVIII) WMTS tile overlay.
@available(watchOS 12, *)
#Preview("Carte de Cassini (France XVIII)") {
	let v = MapKitView(
		cacheDirectory: "cassinicache",
		urlTemplate:
			"https://data.geopf.fr/wmts?layer=BNF-IGNF_GEOGRAPHICALGRIDSYSTEMS.CASSINI&style=normal&tilematrixset=PM&Service=WMTS&Request=GetTile&Version=1.0.0&Format=image%2Fpng&TileMatrix={z}&TileCol={x}&TileRow={y})"
	)
	v.setRegion(
		MKCoordinateRegion(
			center: CLLocationCoordinate2D(latitude: 45.0050, longitude: 6.5180),
			span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
	return v
}

/// Preview showing a MapKitView with OpenSeaMap tile overlay.
@available(watchOS 12, *)
#Preview("OpenSeaMap") {
	let v = MapKitView(
		cacheDirectory: "openseamapcache", urlTemplate: "https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png")
	v.setRegion(
		MKCoordinateRegion(
			center: CLLocationCoordinate2D(latitude: 43.6956, longitude: 7.2906),
			span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
	return v
}

/// Preview showing a MapKitView with two stacked overlays:
/// OpenStreetMap as the opaque base, OpenSeaMap as the transparent nautical layer
/// (lights, buoys, beacons, harbours).  Classic free nautical chart combination.
@available(watchOS 12, *)
#Preview("OSM + OpenSeaMap") {
	let v = MapKitView(overlays: [
		(cacheDirectory: "openstreetmapcache", urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
		(cacheDirectory: "openseamapcache", urlTemplate: "https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png"),
	])
	v.setRegion(
		MKCoordinateRegion(
			center: CLLocationCoordinate2D(latitude: 43.6956, longitude: 7.2906),
			span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
		))
	return v
}
