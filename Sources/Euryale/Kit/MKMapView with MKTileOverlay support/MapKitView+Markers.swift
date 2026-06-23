internal import CoreLocation
internal import CoreText
public import MapKit
public import Stheno
public import SwiftUI

#if canImport(UIKit)
	internal import UIKit
#elseif canImport(AppKit)
	internal import AppKit
#endif

// MARK: - MapPositionStyle

/// How a position marker is drawn on a ``MapKitView``. Common to any app using
/// the map; the colours are supplied by the caller.
public enum MapPositionStyle: Sendable {

	/// A filled dot with a white ring — a fixed position.
	case dot(Color)
	/// A dot with a small directional triangle (e.g. a moving position). The
	/// triangle uses `indicator`, which may differ from the `dot` colour, and
	/// points along the marker's direction.
	case heading(dot: Color, indicator: Color)
	/// A boat-hull silhouette oriented along the marker's direction, with a
	/// white outline for contrast. When no direction is known (e.g. stationary),
	/// the hull points north.
	case boatHull(Color)
	/// A coloured disc badge carrying a white SF Symbol glyph — for fixed,
	/// non-vessel objects such as aids to navigation, base stations, aircraft or
	/// chart marks. Always drawn upright (direction is ignored).
	case symbol(systemName: String, color: Color)
}

// MARK: - MapTrackStyle

/// Visual style for a ``MapTrack`` polyline.
public struct MapTrackStyle: Sendable {

	/// Base stroke colour.
	public var color: Color
	/// Width of the bright core line, in points.
	public var lineWidth: Double
	/// Width of the soft translucent halo drawn beneath the core, in points.
	/// Set to `lineWidth` or less to disable the glow.
	public var haloWidth: Double
	/// When `true`, the line fades from transparent at the first coordinate to
	/// opaque at the last (a gradient along the line's length).
	public var fadesAlongLength: Bool

	/// Creates a track style.
	public init(
		color: Color = .blue,
		lineWidth: Double = 4,
		haloWidth: Double = 12,
		fadesAlongLength: Bool = true
	) {
		self.color = color
		self.lineWidth = lineWidth
		self.haloWidth = haloWidth
		self.fadesAlongLength = fadesAlongLength
	}

	/// A blue line with a soft halo that fades along its length.
	public static var `default`: MapTrackStyle { .init() }
}

// MARK: - MapMarker

/// A position marker shown on a ``MapKitView``.
public struct MapMarker: Identifiable {

	public let id: AnyHashable
	/// Where the marker is anchored.
	public var coordinate: Coordinate
	/// Direction in degrees clockwise from north, used by ``MapPositionStyle/heading(dot:indicator:)``.
	public var direction: Double?
	/// How the marker is drawn.
	public var style: MapPositionStyle
	/// Optional label drawn just below the marker (e.g. a vessel name).
	public var title: String?
	/// Drawing opacity in `0...1`. Use values below `1` to fade stale markers.
	public var opacity: Double

	/// Creates a marker.
	/// - Parameters:
	///   - id: Stable identity so the marker animates in place across updates.
	///   - coordinate: Anchor coordinate.
	///   - direction: Heading in degrees, for directional styles.
	///   - style: How the marker is drawn.
	///   - title: Optional label drawn just below the marker.
	///   - opacity: Drawing opacity in `0...1` (values below `1` fade the marker).
	public init(
		id: AnyHashable = UUID(),
		coordinate: Coordinate,
		direction: Double? = nil,
		style: MapPositionStyle,
		title: String? = nil,
		opacity: Double = 1
	) {
		self.id = id
		self.coordinate = coordinate
		self.direction = direction
		self.style = style
		self.title = title
		self.opacity = opacity
	}
}

// MARK: - MapTrack

/// A styled polyline drawn on a ``MapKitView``.
public struct MapTrack: Identifiable {

	public let id: AnyHashable
	/// The polyline's coordinates, in draw order (first → last).
	public var coordinates: [Coordinate]
	/// How the line is stroked.
	public var style: MapTrackStyle

	/// Creates a track.
	public init(id: AnyHashable = UUID(), coordinates: [Coordinate], style: MapTrackStyle = .default) {
		self.id = id
		self.coordinates = coordinates
		self.style = style
	}
}

// MARK: - MapVisibleRegion

/// The map's currently visible region — centre plus latitude/longitude span,
/// reported by `onVisibleRegion(_:)`. Use ``contains(_:)`` to keep only the
/// objects on screen (e.g. when drawing a large library only where it shows).
public struct MapVisibleRegion: Equatable, Sendable {

	/// The region's centre coordinate.
	public var center: Coordinate
	/// Full height of the region, in degrees of latitude.
	public var latitudeDelta: Double
	/// Full width of the region, in degrees of longitude.
	public var longitudeDelta: Double

	/// Creates a visible region.
	public init(center: Coordinate, latitudeDelta: Double, longitudeDelta: Double) {
		self.center = center
		self.latitudeDelta = latitudeDelta
		self.longitudeDelta = longitudeDelta
	}

	/// Whether `coordinate` lies within the region (antimeridian wrap is not
	/// handled — fine for a regional chart).
	public func contains(_ coordinate: Coordinate) -> Bool {
		abs(coordinate.latitude - center.latitude) <= latitudeDelta / 2
			&& abs(coordinate.longitude - center.longitude) <= longitudeDelta / 2
	}
}

// MARK: - MapKitView modifiers

extension MapKitView {

	/// Places position markers on the map, replacing any previously set.
	public func marking(_ markers: [MapMarker]) -> MapKitView {
		var copy = self
		copy.config.markers = markers
		return copy
	}

	/// Draws styled polylines on the map, replacing any previously set.
	public func tracking(_ tracks: [MapTrack]) -> MapKitView {
		var copy = self
		copy.config.tracks = tracks
		return copy
	}

	/// Filters which points of interest the map displays — on every platform,
	/// including the watchOS map.
	///
	/// - Parameter value: ``MapPointsOfInterest/all``, ``MapPointsOfInterest/none``,
	///   or ``MapPointsOfInterest/including(_:)`` naming the categories to keep.
	public func pointsOfInterest(_ value: MapPointsOfInterest) -> MapKitView {
		var copy = self
		copy.config.pointOfInterestFilter = value
		return copy
	}

	/// Draws a WMS tile layer beneath the map's tile overlays, or removes it when
	/// `source` is `nil`. Toggling is live. Has no effect on watchOS.
	///
	/// - Parameter source: The WMS underlay to show, or `nil` to remove it.
	public func wmsUnderlay(_ source: WMSTileSource?) -> MapKitView {
		var copy = self
		copy.config.wmsUnderlay = source
		return copy
	}

	/// Locks the map's orientation, using `course` (COG) for course-up and
	/// `heading` (HDG) for head-up. The user cannot rotate the map by gesture.
	public func orientation(_ orientation: MapOrientation, course: Double? = nil, heading: Double? = nil)
		-> MapKitView
	{
		var copy = self
		copy.config.orientation = orientation
		copy.config.courseDegrees = course
		copy.config.headingDegrees = heading
		return copy
	}

	/// Enables autoscroll: the camera keeps the boat a third up from the bottom,
	/// auto-zooms (to `destination` if set, otherwise five hours ahead at
	/// `speedKnots`), and locks scroll / zoom — 3D tilt stays allowed. Disable for
	/// free panning.
	public func autoScroll(_ enabled: Bool, speedKnots: Double? = nil, destination: Coordinate? = nil)
		-> MapKitView
	{
		var copy = self
		copy.config.autoscroll = enabled
		copy.config.speedKnots = speedKnots
		copy.config.destination = destination
		return copy
	}

	/// Centres the map on `coordinate` once — the first time it becomes
	/// available (initial positioning) — then recentres only when `recenterToken`
	/// changes. Between those the map is free to pan; the marker still updates in
	/// place. Drive `recenterToken` from a "recentre" button.
	public func centering(on coordinate: Coordinate?, recenterToken: AnyHashable = 0) -> MapKitView {
		var copy = self
		copy.config.centerCoordinate = coordinate
		copy.config.recenterToken = recenterToken
		return copy
	}

	/// Keeps the map continuously centred on `coordinate` as it changes (no free
	/// panning) — for compact, glanceable maps such as a menu-bar item.
	public func following(_ coordinate: Coordinate?, span: Double = 0.02) -> MapKitView {
		var copy = self
		copy.config.centerCoordinate = coordinate
		copy.config.continuousFollow = true
		copy.config.zoomSpan = span
		return copy
	}

	/// Enables or disables user interaction (scroll / zoom / rotate / pitch).
	/// Disable for a passive, glanceable map.
	public func interactive(_ enabled: Bool) -> MapKitView {
		var copy = self
		copy.config.isInteractive = enabled
		return copy
	}

	/// Reports the id of a tapped marker, so the caller can present details for
	/// it. Not available on watchOS.
	public func onMarkerSelected(_ handler: @escaping (AnyHashable) -> Void) -> MapKitView {
		var copy = self
		copy.config.onSelectMarker = handler
		return copy
	}

	/// Reports the map's visible region once it settles after a pan, zoom or
	/// rotate (not continuously during the gesture), so the caller can filter
	/// what it draws to the screen. No-op on watchOS.
	public func onVisibleRegion(_ handler: @escaping (MapVisibleRegion) -> Void) -> MapKitView {
		var copy = self
		copy.config.onRegionSettled = handler
		return copy
	}

	/// Reports the chart coordinate of a single tap on open water (a tap on a
	/// marker selects it instead, via `onMarkerSelected(_:)`). Lets the caller
	/// pick points on the map — e.g. the start and end of a planned route. No-op
	/// on watchOS.
	public func onMapTap(_ handler: @escaping (Coordinate) -> Void) -> MapKitView {
		var copy = self
		copy.config.onMapTap = handler
		return copy
	}

	/// Reports the chart coordinate of a long-press (iOS / iPadOS) or a secondary
	/// (right) click (macOS) on open water — for raising a context menu at that
	/// point. A press on a marker is ignored (it selects the marker). No-op on
	/// watchOS / tvOS.
	public func onMapLongPress(_ handler: @escaping (Coordinate) -> Void) -> MapKitView {
		var copy = self
		copy.config.onMapLongPress = handler
		return copy
	}
}

// MARK: - Marker drawing (MapKit platforms)

#if !os(watchOS)

	/// A movable image annotation backing a ``MapMarker``. `coordinate` is
	/// `@objc dynamic` so MapKit animates the marker when the position updates.
	final class MarkerAnnotation: NSObject, MKAnnotation {
		@objc dynamic var coordinate: CLLocationCoordinate2D
		var image: PlatformImage
		/// Shifts the view so the glyph (not the labelled image's centre) anchors
		/// on the coordinate.
		var centerOffset: CGPoint
		let key: AnyHashable

		init(key: AnyHashable, coordinate: CLLocationCoordinate2D, image: PlatformImage, centerOffset: CGPoint) {
			self.key = key
			self.coordinate = coordinate
			self.image = image
			self.centerOffset = centerOffset
		}
	}

	enum MapMarkerImage {

		private static let glyphBox: CGFloat = 52
		private static var titleFont: PlatformFont { .systemFont(ofSize: 11, weight: .semibold) }

		/// Renders a marker bitmap for the given style, direction, optional title
		/// and opacity, in a UIKit-like top-left, y-down space on every platform.
		///
		/// The glyph (dot/triangle/hull) is drawn in a 52×52 box; when a title is
		/// present it sits just below, in a wider/taller canvas. The returned
		/// `centerOffset` shifts the annotation so the glyph — not the canvas
		/// centre — stays anchored on the coordinate.
		static func make(
			style: MapPositionStyle,
			direction: Double?,
			title: String?,
			opacity: Double
		) -> (image: PlatformImage, centerOffset: CGPoint) {
			var line: CTLine?
			var lineWidth: CGFloat = 0
			if let title, title.isEmpty == false {
				let attributes: [NSAttributedString.Key: Any] = [
					.font: titleFont,
					NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
				]
				let ctLine = CTLineCreateWithAttributedString(
					NSAttributedString(string: title, attributes: attributes)
				)
				line = ctLine
				lineWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
			}
			let gap: CGFloat = 1
			let nameHeight = line == nil ? 0 : ceil(titleFont.ascender - titleFont.descender) + gap
			let width = max(glyphBox, ceil(lineWidth) + 10)
			let size = CGSize(width: width, height: glyphBox + nameHeight)
			let image = render(size: size) { ctx in
				ctx.setAlpha(CGFloat(opacity))
				let centre = CGPoint(x: width / 2, y: glyphBox / 2)
				switch style {
				case .dot(let color):
					drawDot(ctx, centre: centre, color: color)
				case .heading(let dot, let indicator):
					if let direction {
						drawTriangle(ctx, centre: centre, direction: direction, color: indicator)
					}
					drawDot(ctx, centre: centre, color: dot)
				case .boatHull(let color):
					// Stationary / no heading → point north.
					drawHull(ctx, centre: centre, direction: direction ?? 0, color: color)
				case .symbol(let systemName, let color):
					drawSymbolBadge(ctx, centre: centre, systemName: systemName, color: color)
				}
				if let line {
					// Sit the label a touch closer to the hull (the glyph occupies
					// only the upper part of its box, leaving a gap below it).
					drawTitle(ctx, line: line, lineWidth: lineWidth, width: width, topY: glyphBox - 7)
				}
			}
			return (image, CGPoint(x: 0, y: nameHeight / 2))
		}

		/// Draws the title line, centred horizontally below the glyph, with a soft
		/// dark halo so it stays legible over the chart. The context is y-down, so
		/// we flip locally for upright glyphs.
		private static func drawTitle(
			_ ctx: CGContext, line: CTLine, lineWidth: CGFloat, width: CGFloat, topY: CGFloat
		) {
			ctx.saveGState()
			ctx.setShadow(offset: .zero, blur: 2.5, color: PlatformColor.black.withAlphaComponent(0.9).cgColor)
			ctx.setFillColor(PlatformColor.white.cgColor)
			ctx.textMatrix = .identity
			ctx.translateBy(x: (width - lineWidth) / 2, y: topY + titleFont.ascender)
			ctx.scaleBy(x: 1, y: -1)
			ctx.textPosition = .zero
			CTLineDraw(line, ctx)
			ctx.restoreGState()
		}

		private static func drawDot(_ ctx: CGContext, centre: CGPoint, color: Color) {
			let radius: CGFloat = 7
			ctx.setFillColor(PlatformColor.white.cgColor)
			ctx.fillEllipse(
				in: CGRect(
					x: centre.x - radius - 2, y: centre.y - radius - 2,
					width: (radius + 2) * 2, height: (radius + 2) * 2
				))
			ctx.setFillColor(PlatformColor(color).cgColor)
			ctx.fillEllipse(
				in: CGRect(
					x: centre.x - radius, y: centre.y - radius,
					width: radius * 2, height: radius * 2
				))
		}

		private static func drawTriangle(_ ctx: CGContext, centre: CGPoint, direction: Double, color: Color) {
			ctx.saveGState()
			ctx.translateBy(x: centre.x, y: centre.y)
			ctx.rotate(by: CGFloat(direction) * .pi / 180)
			ctx.setFillColor(PlatformColor(color).cgColor)
			// Offset outwards from the dot's white ring (radius ~9) so the arrow
			// sits just clear of the circle.
			let triangle = CGMutablePath()
			triangle.move(to: CGPoint(x: 0, y: -23))
			triangle.addLine(to: CGPoint(x: -6.5, y: -13))
			triangle.addLine(to: CGPoint(x: 6.5, y: -13))
			triangle.closeSubpath()
			ctx.addPath(triangle)
			ctx.fillPath()
			ctx.restoreGState()
		}

		private static func drawHull(_ ctx: CGContext, centre: CGPoint, direction: Double, color: Color) {
			ctx.saveGState()
			ctx.translateBy(x: centre.x, y: centre.y)
			ctx.rotate(by: CGFloat(direction) * .pi / 180)
			// Hull pointing up (bow at top): pointed bow, flat transom.
			let hull = CGMutablePath()
			hull.move(to: CGPoint(x: 0, y: -16))
			hull.addQuadCurve(to: CGPoint(x: -5, y: 14), control: CGPoint(x: -9, y: 0))
			hull.addLine(to: CGPoint(x: 5, y: 14))
			hull.addQuadCurve(to: CGPoint(x: 0, y: -16), control: CGPoint(x: 9, y: 0))
			hull.closeSubpath()
			// White outline first, then the coloured fill on top.
			ctx.addPath(hull)
			ctx.setLineWidth(3)
			ctx.setLineJoin(.round)
			ctx.setStrokeColor(PlatformColor.white.cgColor)
			ctx.strokePath()
			ctx.addPath(hull)
			ctx.setFillColor(PlatformColor(color).cgColor)
			ctx.fillPath()
			ctx.restoreGState()
		}

		/// A coloured disc with a white ring carrying a white SF Symbol glyph — the
		/// fixed-object counterpart to the boat hull. Drawn upright (no rotation).
		private static func drawSymbolBadge(
			_ ctx: CGContext, centre: CGPoint, systemName: String, color: Color
		) {
			let radius: CGFloat = 11
			ctx.setFillColor(PlatformColor.white.cgColor)
			ctx.fillEllipse(
				in: CGRect(
					x: centre.x - radius - 2, y: centre.y - radius - 2,
					width: (radius + 2) * 2, height: (radius + 2) * 2))
			ctx.setFillColor(PlatformColor(color).cgColor)
			ctx.fillEllipse(
				in: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
			guard let glyph = symbolImage(systemName, pointSize: 13) else { return }
			let side: CGFloat = 15
			let aspect = CGFloat(glyph.height) / CGFloat(max(glyph.width, 1))
			let w = side
			let h = side * aspect
			let rect = CGRect(x: centre.x - w / 2, y: centre.y - h / 2, width: w, height: h)
			// The render context is y-down on both platforms, so flip locally to
			// draw the (y-up) symbol bitmap upright.
			ctx.saveGState()
			ctx.translateBy(x: rect.minX, y: rect.maxY)
			ctx.scaleBy(x: 1, y: -1)
			ctx.draw(glyph, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
			ctx.restoreGState()
		}

		/// Rasterises an SF Symbol, tinted white, to a `CGImage` for compositing on
		/// the coloured badge. Returns `nil` when the symbol name is unknown.
		private static func symbolImage(_ name: String, pointSize: CGFloat) -> CGImage? {
			#if canImport(UIKit)
				let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .black)
				guard let base = UIImage(systemName: name)?.applyingSymbolConfiguration(config) else { return nil }
				let tinted = base.withTintColor(.white, renderingMode: .alwaysOriginal)
				return UIGraphicsImageRenderer(size: tinted.size).image { _ in tinted.draw(at: .zero) }.cgImage
			#elseif canImport(AppKit)
				let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .black)
				guard
					let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
						.withSymbolConfiguration(config)
				else { return nil }
				let size = base.size
				let tinted = NSImage(size: size)
				tinted.lockFocus()
				base.draw(at: .zero, from: CGRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1)
				PlatformColor.white.set()
				CGRect(origin: .zero, size: size).fill(using: .sourceAtop)
				tinted.unlockFocus()
				return tinted.cgImage(forProposedRect: nil, context: nil, hints: nil)
			#else
				return nil
			#endif
		}

		#if canImport(UIKit)
			private static func render(size: CGSize, _ draw: (CGContext) -> Void) -> PlatformImage {
				UIGraphicsImageRenderer(size: size).image { ctx in draw(ctx.cgContext) }
			}
		#elseif canImport(AppKit)
			private static func render(size: CGSize, _ draw: (CGContext) -> Void) -> PlatformImage {
				let image = NSImage(size: size)
				image.lockFocus()
				if let ctx = NSGraphicsContext.current?.cgContext {
					ctx.translateBy(x: 0, y: size.height)
					ctx.scaleBy(x: 1, y: -1)
					draw(ctx)
				}
				image.unlockFocus()
				return image
			}
		#endif
	}

	// MARK: - MarkableMapRepresentable

	/// Renders ``MapKitView``'s markers, tracks and follow target onto the
	/// view's existing `MKMapView` (which already carries the tile overlays).
	#if os(macOS)
		struct MarkableMapRepresentable: NSViewRepresentable {
			let map: MKMapView
			let config: MapViewConfiguration

			func makeCoordinator() -> MarkableMapState { MarkableMapState() }
			func makeNSView(context: Context) -> MKMapView {
				installMap(map, coordinator: context.coordinator)
			}
			func updateNSView(_ map: MKMapView, context: Context) {
				updateMap(map, coordinator: context.coordinator)
			}
		}
	#else
		struct MarkableMapRepresentable: UIViewRepresentable {
			let map: MKMapView
			let config: MapViewConfiguration

			func makeCoordinator() -> MarkableMapState { MarkableMapState() }
			func makeUIView(context: Context) -> MKMapView {
				installMap(map, coordinator: context.coordinator)
			}
			func updateUIView(_ map: MKMapView, context: Context) {
				updateMap(map, coordinator: context.coordinator)
			}
		}
	#endif

	/// The platform-agnostic body of the two ``MarkableMapRepresentable`` variants,
	/// so the field list and update logic are written once.
	extension MarkableMapRepresentable {
		/// Wires the shared delegate and tap recogniser when the view is made. The
		/// coordinator (which SwiftUI keeps alive) owns the delegate; `MKMapView`'s
		/// `delegate` is weak, so the transient view's own delegate would otherwise be
		/// deallocated and custom rendering (vessel marker, tile overlays) would stop.
		func installMap(_ map: MKMapView, coordinator: MarkableMapState) -> MKMapView {
			map.delegate = coordinator.mapDelegate
			coordinator.installMapTapIfNeeded(on: map)
			return map
		}

		/// Applies the current configuration to the map on every SwiftUI update.
		func updateMap(_ map: MKMapView, coordinator: MarkableMapState) {
			// Rotation is locked to the orientation setting; pan/zoom are locked in
			// autoscroll; 3D tilt stays allowed in both modes.
			map.isScrollEnabled = config.isInteractive && !config.autoscroll
			map.isZoomEnabled = config.isInteractive && !config.autoscroll
			#if !os(tvOS)
				// Rotation and pitch gestures don't exist on tvOS.
				map.isRotateEnabled = false
				map.isPitchEnabled = config.isInteractive
			#endif
			map.pointOfInterestFilter = config.pointOfInterestFilter.mkFilter
			coordinator.applyWMSUnderlay(config.wmsUnderlay, on: map)
			coordinator.mapDelegate.onSelect = config.onSelectMarker
			coordinator.bindRegionSettled(config.onRegionSettled)
			coordinator.bindMapTap(config.onMapTap)
			coordinator.bindMapLongPress(config.onMapLongPress)
			coordinator.applyCamera(
				center: config.centerCoordinate, recenterToken: config.recenterToken,
				continuousFollow: config.continuousFollow, autoscroll: config.autoscroll,
				orientation: config.orientation, course: config.courseDegrees, heading: config.headingDegrees,
				speedKnots: config.speedKnots, destination: config.destination, zoomSpan: config.zoomSpan, on: map)
			coordinator.apply(markers: config.markers, tracks: config.tracks, on: map)
		}
	}

	/// Diff state for ``MarkableMapRepresentable``: tracks which annotations and
	/// overlays are currently on the map so updates animate in place.
	@MainActor
	final class MarkableMapState {
		/// Owned here so it outlives the transient `MapKitView`/representable and
		/// keeps serving the map's (weak) delegate for the view's whole lifetime.
		let mapDelegate = MapDelegate()
		private var didInitialCenter = false
		private var lastRecenterToken: AnyHashable?
		private var annotations: [AnyHashable: MarkerAnnotation] = [:]
		private var overlays: [AnyHashable: (halo: MKPolyline, core: MKPolyline)] = [:]
		private var pointCounts: [AnyHashable: Int] = [:]
		/// The most recently applied markers, kept so directional glyphs can be
		/// re-rendered against a new map rotation without a SwiftUI update.
		private var lastMarkers: [MapMarker] = []
		/// The map rotation (degrees) the marker images were last rendered for.
		private var renderedHeading: Double = 0
		/// Whether the rotation-tracking callback has been installed.
		private var observingRegion = false
		/// Whether the tap recogniser has been attached to the map.
		private var didInstallMapTap = false
		/// The WMS underlay currently applied, kept to detect changes.
		private var wmsUnderlaySource: WMSTileSource?
		/// The live WMS underlay overlay, so it can be removed or replaced.
		private var wmsUnderlayOverlay: MKTileOverlay?

		/// Attaches a single tap recogniser to the map (once), routed to the
		/// delegate which converts the point and forwards a coordinate.
		func installMapTapIfNeeded(on map: MKMapView) {
			guard !didInstallMapTap else { return }
			didInstallMapTap = true
			mapDelegate.tappedMap = map
			#if canImport(UIKit)
				let recognizer = UITapGestureRecognizer(
					target: mapDelegate, action: #selector(MapDelegate.handleMapTap(_:)))
				recognizer.delegate = mapDelegate
				// Never swallow the touch — MapKit keeps its own pan/selection handling,
				// and the delegate simply ignores taps when no handler is bound.
				recognizer.cancelsTouchesInView = false
				map.addGestureRecognizer(recognizer)
				// A long-press (held finger) for the context menu, alongside the tap.
				let longPress = UILongPressGestureRecognizer(
					target: mapDelegate, action: #selector(MapDelegate.handleMapLongPress(_:)))
				longPress.delegate = mapDelegate
				longPress.cancelsTouchesInView = false
				map.addGestureRecognizer(longPress)
			#elseif canImport(AppKit)
				let recognizer = NSClickGestureRecognizer(
					target: mapDelegate, action: #selector(MapDelegate.handleMapTap(_:)))
				map.addGestureRecognizer(recognizer)
				// A secondary (right) click for the context menu.
				let rightClick = NSClickGestureRecognizer(
					target: mapDelegate, action: #selector(MapDelegate.handleMapLongPress(_:)))
				rightClick.buttonMask = 0x2
				map.addGestureRecognizer(rightClick)
			#endif
		}

		/// Installs (or clears) the public map-tap callback, wrapping the delegate's
		/// CoreLocation coordinate as a Stheno ``Coordinate``.
		func bindMapTap(_ handler: ((Coordinate) -> Void)?) {
			guard let handler else {
				mapDelegate.onMapTap = nil
				return
			}
			mapDelegate.onMapTap = { coordinate in
				handler(Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
			}
		}

		/// Installs (or clears) the public map-long-press callback, wrapping the
		/// delegate's CoreLocation coordinate as a Stheno ``Coordinate``.
		func bindMapLongPress(_ handler: ((Coordinate) -> Void)?) {
			guard let handler else {
				mapDelegate.onMapLongPress = nil
				return
			}
			mapDelegate.onMapLongPress = { coordinate in
				handler(Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
			}
		}

		/// Installs (or clears) the public "region settled" callback, translating the
		/// map's `MKCoordinateRegion` into a ``MapVisibleRegion`` for the caller.
		func bindRegionSettled(_ handler: ((MapVisibleRegion) -> Void)?) {
			guard let handler else {
				mapDelegate.onRegionSettled = nil
				return
			}
			mapDelegate.onRegionSettled = { map in
				let region = map.region
				handler(
					MapVisibleRegion(
						center: Coordinate(
							latitude: region.center.latitude, longitude: region.center.longitude),
						latitudeDelta: region.span.latitudeDelta,
						longitudeDelta: region.span.longitudeDelta))
			}
		}

		/// Adds, removes or replaces the WMS underlay to match `source`, drawing it
		/// beneath the tile overlays (and the markers/tracks). Idempotent: a repeat
		/// call with the same source does nothing.
		func applyWMSUnderlay(_ source: WMSTileSource?, on map: MKMapView) {
			guard source != wmsUnderlaySource else { return }
			wmsUnderlaySource = source
			if let existing = wmsUnderlayOverlay {
				map.removeOverlay(existing)
				wmsUnderlayOverlay = nil
			}
			if let source {
				let overlay = WMSTileOverlay(
					directory: source.cacheDirectory, getMapBaseURL: source.getMapBaseURL)
				wmsUnderlayOverlay = overlay
				map.addOverlay(overlay, level: .aboveRoads)
			}
		}

		func apply(markers: [MapMarker], tracks: [MapTrack], on map: MKMapView) {
			// Install the rotation observer once, so directional markers stay
			// aligned to the chart when the map rotates (course-up, head-up).
			if !observingRegion {
				observingRegion = true
				mapDelegate.onRegionChange = { [weak self] map in self?.headingDidChange(on: map) }
			}
			applyTracks(tracks, on: map)
			applyMarkers(markers, on: map)
		}

		// MARK: Camera — orientation, follow and autoscroll

		/// Boat sits a third up from the bottom in autoscroll, so the look-at point
		/// is ahead of it by this fraction of the forward-visible distance.
		private static let lookAheadFraction = 0.25
		/// Maps a forward-visible ground distance to an `MKMapCamera` distance —
		/// tune on device (it depends on MapKit's field of view and the view size).
		private static let zoomDistanceFactor = 2.2
		/// Smallest forward-visible distance, so the view never collapses when stopped.
		private static let minForwardMetres = 600.0

		/// Drives the camera: the orientation heading always, plus continuous-follow
		/// or autoscroll centring/zoom. In plain pan mode it only (re)centres on
		/// demand, leaving the user's pan and zoom alone.
		func applyCamera(
			center: Coordinate?, recenterToken: AnyHashable,
			continuousFollow: Bool, autoscroll: Bool,
			orientation: MapOrientation, course: Double?, heading: Double?,
			speedKnots: Double?, destination: Coordinate?,
			zoomSpan: Double, on map: MKMapView
		) {
			guard let center else { return }
			let boat = CLLocationCoordinate2D(center)
			let target = Self.resolveHeading(
				orientation, course: course, heading: heading, fallback: map.camera.heading)

			if autoscroll {
				let forward = Self.autoscrollForward(
					boat: boat, destination: destination, speedKnots: speedKnots,
					current: map.camera.centerCoordinateDistance / Self.zoomDistanceFactor)
				let bearing = course ?? heading ?? target
				let lookAt = Self.project(boat, bearing: bearing, metres: forward * Self.lookAheadFraction)
				// Keep the user's 3D tilt (pitch); lock everything else.
				let camera = MKMapCamera(
					lookingAtCenter: lookAt, fromDistance: forward * Self.zoomDistanceFactor,
					pitch: map.camera.pitch, heading: target)
				map.setCamera(camera, animated: didInitialCenter)
				didInitialCenter = true
				return
			}

			let recentre: Bool
			if continuousFollow {
				recentre = true
			} else if !didInitialCenter {
				recentre = true
				lastRecenterToken = recenterToken
			} else if recenterToken != lastRecenterToken {
				recentre = true
				lastRecenterToken = recenterToken
			} else {
				recentre = false
			}
			guard recentre || abs(map.camera.heading - target) > 0.5 else { return }

			let lookAt = recentre ? boat : map.camera.centerCoordinate
			let distance =
				(continuousFollow || !didInitialCenter)
				? Self.cameraDistance(forSpan: zoomSpan)
				: map.camera.centerCoordinateDistance
			let camera = MKMapCamera(
				lookingAtCenter: lookAt, fromDistance: distance, pitch: map.camera.pitch, heading: target)
			map.setCamera(camera, animated: didInitialCenter)
			didInitialCenter = true
		}

		private static func resolveHeading(
			_ orientation: MapOrientation, course: Double?, heading: Double?, fallback: Double
		) -> Double {
			switch orientation {
			case .northUp: return 0
			case .headUp: return heading ?? course ?? fallback
			case .courseUp: return course ?? heading ?? fallback
			}
		}

		private static func autoscrollForward(
			boat: CLLocationCoordinate2D, destination: Coordinate?, speedKnots: Double?, current: Double
		) -> Double {
			if let destination {
				let metres = CLLocation(latitude: boat.latitude, longitude: boat.longitude)
					.distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
				return max(minForwardMetres, metres * 1.15)  // a little past the waypoint
			}
			if let speedKnots, speedKnots > 0.3 {
				return max(minForwardMetres, speedKnots * 1852.0 * 5.0)  // five hours ahead
			}
			return max(minForwardMetres, current)
		}

		private static func cameraDistance(forSpan span: Double) -> Double {
			max(minForwardMetres, span * 111_320.0 * zoomDistanceFactor)
		}

		/// The point `metres` ahead of `coord` along `bearing` (great-circle).
		private static func project(
			_ coord: CLLocationCoordinate2D, bearing: Double, metres: Double
		) -> CLLocationCoordinate2D {
			let angular = metres / 6_371_000.0
			let theta = bearing * .pi / 180
			let phi1 = coord.latitude * .pi / 180
			let lambda1 = coord.longitude * .pi / 180
			let phi2 = asin(sin(phi1) * cos(angular) + cos(phi1) * sin(angular) * cos(theta))
			let lambda2 = lambda1 + atan2(sin(theta) * sin(angular) * cos(phi1), cos(angular) - sin(phi1) * sin(phi2))
			return CLLocationCoordinate2D(latitude: phi2 * 180 / .pi, longitude: lambda2 * 180 / .pi)
		}

		/// Re-renders the directional markers when the map's rotation changes, so a
		/// boat hull keeps pointing along its true heading on the chart instead of
		/// staying fixed to the screen. Gated on a meaningful heading delta so pans
		/// and zooms (which also change the visible region) don't re-render.
		private func headingDidChange(on map: MKMapView) {
			let heading = map.camera.heading
			guard abs(heading - renderedHeading) > 0.25 else { return }
			applyMarkers(lastMarkers, on: map)
		}

		private func applyMarkers(_ markers: [MapMarker], on map: MKMapView) {
			lastMarkers = markers
			// Counter-rotate directional glyphs by the map's rotation so they stay
			// aligned to true north on the chart; the label stays upright because
			// it is drawn separately from the rotated glyph.
			let heading = map.camera.heading
			renderedHeading = heading
			var seen = Set<AnyHashable>()
			for marker in markers {
				seen.insert(marker.id)
				let glyphDirection: Double?
				switch marker.style {
				case .boatHull: glyphDirection = (marker.direction ?? 0) - heading
				default: glyphDirection = marker.direction.map { $0 - heading }
				}
				let rendered = MapMarkerImage.make(
					style: marker.style, direction: glyphDirection,
					title: marker.title, opacity: marker.opacity
				)
				let coordinate = CLLocationCoordinate2D(marker.coordinate)
				if let existing = annotations[marker.id] {
					existing.coordinate = coordinate
					existing.image = rendered.image
					existing.centerOffset = rendered.centerOffset
					if let view = map.view(for: existing) {
						view.image = rendered.image
						view.centerOffset = rendered.centerOffset
					}
				} else {
					let annotation = MarkerAnnotation(
						key: marker.id, coordinate: coordinate,
						image: rendered.image, centerOffset: rendered.centerOffset
					)
					annotations[marker.id] = annotation
					map.addAnnotation(annotation)
				}
			}
			for (key, annotation) in annotations where !seen.contains(key) {
				map.removeAnnotation(annotation)
				annotations[key] = nil
			}
		}

		private func applyTracks(_ tracks: [MapTrack], on map: MKMapView) {
			let delegate = map.delegate as? MapDelegate
			var seen = Set<AnyHashable>()
			for track in tracks {
				seen.insert(track.id)
				if pointCounts[track.id] == track.coordinates.count { continue }
				removeTrack(track.id, on: map)
				guard track.coordinates.count >= 2 else { continue }

				var coords = track.coordinates.map(CLLocationCoordinate2D.init)
				// Geodesic so a leg follows the great circle (matching the router's
				// great-circle distances) rather than a straight line in the map's
				// projection.
				let halo = MKGeodesicPolyline(coordinates: &coords, count: coords.count)
				let core = MKGeodesicPolyline(coordinates: &coords, count: coords.count)
				delegate?.trackStyles[ObjectIdentifier(halo)] = (track.style, true)
				delegate?.trackStyles[ObjectIdentifier(core)] = (track.style, false)
				overlays[track.id] = (halo, core)
				pointCounts[track.id] = track.coordinates.count
				map.addOverlay(halo, level: .aboveLabels)
				map.addOverlay(core, level: .aboveLabels)
			}
			for key in overlays.keys where !seen.contains(key) {
				removeTrack(key, on: map)
			}
		}

		private func removeTrack(_ id: AnyHashable, on map: MKMapView) {
			guard let pair = overlays[id] else { return }
			let delegate = map.delegate as? MapDelegate
			map.removeOverlay(pair.halo)
			map.removeOverlay(pair.core)
			delegate?.trackStyles[ObjectIdentifier(pair.halo)] = nil
			delegate?.trackStyles[ObjectIdentifier(pair.core)] = nil
			overlays[id] = nil
			pointCounts[id] = nil
		}
	}

#else

	// MARK: - Marker content (watchOS)

	extension MapKitView {
		/// SwiftUI map content for the markers and tracks, used inside the
		/// watchOS `Map`.
		@MapContentBuilder
		var markerAndTrackContent: some MapContent {
			ForEach(config.tracks) { track in
				if track.coordinates.count >= 2 {
					MapPolyline(coordinates: track.coordinates.map(CLLocationCoordinate2D.init))
						.stroke(track.style.color, lineWidth: track.style.lineWidth)
				}
			}
			ForEach(config.markers) { marker in
				Annotation(marker.title ?? "", coordinate: CLLocationCoordinate2D(marker.coordinate)) {
					MarkerShape(style: marker.style, direction: marker.direction)
						.opacity(marker.opacity)
				}
			}
		}
	}

	/// SwiftUI rendering of a ``MapPositionStyle`` for watchOS.
	struct MarkerShape: View {
		let style: MapPositionStyle
		let direction: Double?

		var body: some View {
			switch style {
			case .dot(let color):
				dot(color)
			case .heading(let dotColor, let indicator):
				ZStack {
					if let direction {
						DirectionTriangle()
							.fill(indicator)
							.frame(width: 12, height: 10)
							.offset(y: -16)
							.rotationEffect(.degrees(direction))
					}
					dot(dotColor)
				}
			case .boatHull(let color):
				HullShape()
					.fill(color)
					.overlay(HullShape().stroke(.white, lineWidth: 2))
					.frame(width: 20, height: 30)
					.rotationEffect(.degrees(direction ?? 0))
			case .symbol(let systemName, let color):
				Image(systemName: systemName)
					.font(.system(size: 11, weight: .black))
					.foregroundStyle(.white)
					.padding(5)
					.background(Circle().fill(color))
					.overlay(Circle().stroke(.white, lineWidth: 2))
			}
		}

		private func dot(_ color: Color) -> some View {
			Circle()
				.fill(color)
				.frame(width: 16, height: 16)
				.overlay(Circle().stroke(.white, lineWidth: 2))
		}
	}

	private struct DirectionTriangle: Shape {
		func path(in rect: CGRect) -> Path {
			var path = Path()
			path.move(to: CGPoint(x: rect.midX, y: rect.minY))
			path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
			path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
			path.closeSubpath()
			return path
		}
	}

	/// A boat-hull silhouette: pointed bow at the top, flat transom at the
	/// bottom, widest amidships.
	private struct HullShape: Shape {
		func path(in r: CGRect) -> Path {
			var p = Path()
			p.move(to: CGPoint(x: r.midX, y: r.minY))
			p.addQuadCurve(
				to: CGPoint(x: r.minX + r.width * 0.28, y: r.maxY),
				control: CGPoint(x: r.minX, y: r.midY)
			)
			p.addLine(to: CGPoint(x: r.minX + r.width * 0.72, y: r.maxY))
			p.addQuadCurve(
				to: CGPoint(x: r.midX, y: r.minY),
				control: CGPoint(x: r.maxX, y: r.midY)
			)
			p.closeSubpath()
			return p
		}
	}

#endif

// MARK: - Previews

#if DEBUG
	@available(watchOS 12, *)
	#Preview("Marker — dot") {
		let v = MapKitView(
			cacheDirectory: "openseamapcache", urlTemplate: "https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png")
		v.setRegion(
			MKCoordinateRegion(
				center: CLLocationCoordinate2D(latitude: 43.6956, longitude: 7.2906),
				span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
		return v.marking([
			MapMarker(coordinate: Coordinate(latitude: 43.6956, longitude: 7.2906), style: .dot(.blue))
		])
	}

	@available(watchOS 12, *)
	#Preview("Marker — heading + track") {
		let v = MapKitView(
			cacheDirectory: "openseamapcache", urlTemplate: "https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png")
		v.setRegion(
			MKCoordinateRegion(
				center: CLLocationCoordinate2D(latitude: 43.6956, longitude: 7.2906),
				span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
		let track = (0..<12).map { i in
			Coordinate(latitude: 43.690 + Double(i) * 0.0009, longitude: 7.285 + Double(i) * 0.0007)
		}
		return
			v
			.tracking([MapTrack(coordinates: track, style: .default)])
			.marking([
				MapMarker(
					coordinate: track.last!,
					direction: 40,
					style: .heading(dot: .blue, indicator: .white)
				)
			])
			.centering(on: track.last!)
	}
#endif
