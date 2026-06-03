public import SwiftUI
public import Stheno

internal import CoreLocation
internal import CoreText
internal import MapKit

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

// MARK: - MapKitView modifiers

public extension MapKitView {

    /// Places position markers on the map, replacing any previously set.
    func marking(_ markers: [MapMarker]) -> MapKitView {
        var copy = self
        copy.markers = markers
        return copy
    }

    /// Draws styled polylines on the map, replacing any previously set.
    func tracking(_ tracks: [MapTrack]) -> MapKitView {
        var copy = self
        copy.tracks = tracks
        return copy
    }

    /// Centres the map on `coordinate` once — the first time it becomes
    /// available (initial positioning) — then recentres only when `recenterToken`
    /// changes. Between those the map is free to pan; the marker still updates in
    /// place. Drive `recenterToken` from a "recentre" button.
    func centering(on coordinate: Coordinate?, recenterToken: AnyHashable = 0) -> MapKitView {
        var copy = self
        copy.centerCoordinate = coordinate
        copy.recenterToken = recenterToken
        return copy
    }

    /// Keeps the map continuously centred on `coordinate` as it changes (no free
    /// panning) — for compact, glanceable maps such as a menu-bar item.
    func following(_ coordinate: Coordinate?, span: Double = 0.02) -> MapKitView {
        var copy = self
        copy.centerCoordinate = coordinate
        copy.continuousFollow = true
        copy.zoomSpan = span
        return copy
    }

    /// Enables or disables user interaction (scroll / zoom / rotate / pitch).
    /// Disable for a passive, glanceable map.
    func interactive(_ enabled: Bool) -> MapKitView {
        var copy = self
        copy.isInteractive = enabled
        return copy
    }

    /// Reports the id of a tapped marker, so the caller can present details for
    /// it. Not available on watchOS.
    func onMarkerSelected(_ handler: @escaping (AnyHashable) -> Void) -> MapKitView {
        var copy = self
        copy.onSelectMarker = handler
        return copy
    }
}

// MARK: - Marker drawing (MapKit platforms)

#if !os(watchOS)

    /// A movable image annotation backing a ``MapMarker``. `coordinate` is
    /// `@objc dynamic` so MapKit animates the marker when the position updates.
    final class MarkerAnnotation: NSObject, MKAnnotation {
        @objc dynamic var coordinate: CLLocationCoordinate2D
        var image: OSImage
        /// Shifts the view so the glyph (not the labelled image's centre) anchors
        /// on the coordinate.
        var centerOffset: CGPoint
        let key: AnyHashable

        init(key: AnyHashable, coordinate: CLLocationCoordinate2D, image: OSImage, centerOffset: CGPoint) {
            self.key = key
            self.coordinate = coordinate
            self.image = image
            self.centerOffset = centerOffset
        }
    }

    enum MapMarkerImage {

        private static let glyphBox: CGFloat = 52
        private static var titleFont: OSFont { .systemFont(ofSize: 11, weight: .semibold) }

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
        ) -> (image: OSImage, centerOffset: CGPoint) {
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
                case let .dot(color):
                    drawDot(ctx, centre: centre, color: color)
                case let .heading(dot, indicator):
                    if let direction {
                        drawTriangle(ctx, centre: centre, direction: direction, color: indicator)
                    }
                    drawDot(ctx, centre: centre, color: dot)
                case let .boatHull(color):
                    // Stationary / no heading → point north.
                    drawHull(ctx, centre: centre, direction: direction ?? 0, color: color)
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
            ctx.setShadow(offset: .zero, blur: 2.5, color: OSColor.black.withAlphaComponent(0.9).cgColor)
            ctx.setFillColor(OSColor.white.cgColor)
            ctx.textMatrix = .identity
            ctx.translateBy(x: (width - lineWidth) / 2, y: topY + titleFont.ascender)
            ctx.scaleBy(x: 1, y: -1)
            ctx.textPosition = .zero
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }

        private static func drawDot(_ ctx: CGContext, centre: CGPoint, color: Color) {
            let radius: CGFloat = 7
            ctx.setFillColor(OSColor.white.cgColor)
            ctx.fillEllipse(in: CGRect(
                x: centre.x - radius - 2, y: centre.y - radius - 2,
                width: (radius + 2) * 2, height: (radius + 2) * 2
            ))
            ctx.setFillColor(OSColor(color).cgColor)
            ctx.fillEllipse(in: CGRect(
                x: centre.x - radius, y: centre.y - radius,
                width: radius * 2, height: radius * 2
            ))
        }

        private static func drawTriangle(_ ctx: CGContext, centre: CGPoint, direction: Double, color: Color) {
            ctx.saveGState()
            ctx.translateBy(x: centre.x, y: centre.y)
            ctx.rotate(by: CGFloat(direction) * .pi / 180)
            ctx.setFillColor(OSColor(color).cgColor)
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
            ctx.setStrokeColor(OSColor.white.cgColor)
            ctx.strokePath()
            ctx.addPath(hull)
            ctx.setFillColor(OSColor(color).cgColor)
            ctx.fillPath()
            ctx.restoreGState()
        }

        #if canImport(UIKit)
            private static func render(size: CGSize, _ draw: (CGContext) -> Void) -> OSImage {
                UIGraphicsImageRenderer(size: size).image { ctx in draw(ctx.cgContext) }
            }
        #elseif canImport(AppKit)
            private static func render(size: CGSize, _ draw: (CGContext) -> Void) -> OSImage {
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
            let markers: [MapMarker]
            let tracks: [MapTrack]
            let centerCoordinate: Coordinate?
            let recenterToken: AnyHashable
            let continuousFollow: Bool
            let isInteractive: Bool
            let zoomSpan: Double
            let onSelectMarker: ((AnyHashable) -> Void)?

            func makeCoordinator() -> MarkableMapState { MarkableMapState() }
            func makeNSView(context: Context) -> MKMapView {
                // The coordinator (which SwiftUI keeps alive) owns the delegate;
                // `MKMapView.delegate` is weak, so the transient view's own
                // delegate would otherwise be deallocated and custom rendering
                // (vessel marker, tile overlays) would stop.
                map.delegate = context.coordinator.mapDelegate
                return map
            }
            func updateNSView(_ map: MKMapView, context: Context) {
                map.isScrollEnabled = isInteractive
                map.isZoomEnabled = isInteractive
                map.isRotateEnabled = isInteractive
                map.isPitchEnabled = isInteractive
                context.coordinator.mapDelegate.onSelect = onSelectMarker
                context.coordinator.apply(
                    markers: markers, tracks: tracks,
                    centerCoordinate: centerCoordinate, recenterToken: recenterToken,
                    continuousFollow: continuousFollow, zoomSpan: zoomSpan, on: map
                )
            }
        }
    #else
        struct MarkableMapRepresentable: UIViewRepresentable {
            let map: MKMapView
            let markers: [MapMarker]
            let tracks: [MapTrack]
            let centerCoordinate: Coordinate?
            let recenterToken: AnyHashable
            let continuousFollow: Bool
            let isInteractive: Bool
            let zoomSpan: Double
            let onSelectMarker: ((AnyHashable) -> Void)?

            func makeCoordinator() -> MarkableMapState { MarkableMapState() }
            func makeUIView(context: Context) -> MKMapView {
                // The coordinator (which SwiftUI keeps alive) owns the delegate;
                // `MKMapView.delegate` is weak, so the transient view's own
                // delegate would otherwise be deallocated and custom rendering
                // (vessel marker, tile overlays) would stop.
                map.delegate = context.coordinator.mapDelegate
                return map
            }
            func updateUIView(_ map: MKMapView, context: Context) {
                map.isScrollEnabled = isInteractive
                map.isZoomEnabled = isInteractive
                #if !os(tvOS)
                    // Rotation and pitch gestures don't exist on tvOS.
                    map.isRotateEnabled = isInteractive
                    map.isPitchEnabled = isInteractive
                #endif
                context.coordinator.mapDelegate.onSelect = onSelectMarker
                context.coordinator.apply(
                    markers: markers, tracks: tracks,
                    centerCoordinate: centerCoordinate, recenterToken: recenterToken,
                    continuousFollow: continuousFollow, zoomSpan: zoomSpan, on: map
                )
            }
        }
    #endif

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

        func apply(
            markers: [MapMarker],
            tracks: [MapTrack],
            centerCoordinate: Coordinate?,
            recenterToken: AnyHashable,
            continuousFollow: Bool,
            zoomSpan: Double,
            on map: MKMapView
        ) {
            // Centre FIRST, so a marker added below lands inside the visible
            // region and MapKit creates its annotation view immediately. (When
            // the marker is added off-screen and the camera never moves again,
            // its view is never created — which hid the vessel dot.)
            if let centerCoordinate {
                let centre = CLLocationCoordinate2D(centerCoordinate)
                let initialRegion = MKCoordinateRegion(
                    center: centre, span: MKCoordinateSpan(latitudeDelta: zoomSpan, longitudeDelta: zoomSpan)
                )
                if continuousFollow {
                    // Stay centred at a fixed zoom on every update. Re-applying the
                    // full region (not just the centre) makes it robust to the
                    // first update landing before the view has a non-zero size
                    // (e.g. inside an AppKit menu), which would otherwise drop the
                    // zoom and leave the map fully zoomed out.
                    map.setRegion(initialRegion, animated: didInitialCenter)
                    didInitialCenter = true
                } else if !didInitialCenter {
                    // First fix: position the camera once, with a sensible zoom.
                    map.setRegion(initialRegion, animated: false)
                    didInitialCenter = true
                    lastRecenterToken = recenterToken
                } else if recenterToken != lastRecenterToken {
                    // Explicit "recentre" request: keep the user's zoom.
                    map.setCenter(centre, animated: true)
                    lastRecenterToken = recenterToken
                }
                // Otherwise leave the camera alone so the user can pan freely.
            }

            applyTracks(tracks, on: map)
            applyMarkers(markers, on: map)
        }

        private func applyMarkers(_ markers: [MapMarker], on map: MKMapView) {
            var seen = Set<AnyHashable>()
            for marker in markers {
                seen.insert(marker.id)
                let rendered = MapMarkerImage.make(
                    style: marker.style, direction: marker.direction,
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
                let halo = MKPolyline(coordinates: &coords, count: coords.count)
                let core = MKPolyline(coordinates: &coords, count: coords.count)
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
            ForEach(tracks) { track in
                if track.coordinates.count >= 2 {
                    MapPolyline(coordinates: track.coordinates.map(CLLocationCoordinate2D.init))
                        .stroke(track.style.color, lineWidth: track.style.lineWidth)
                }
            }
            ForEach(markers) { marker in
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
            case let .dot(color):
                dot(color)
            case let .heading(dotColor, indicator):
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
            case let .boatHull(color):
                HullShape()
                    .fill(color)
                    .overlay(HullShape().stroke(.white, lineWidth: 2))
                    .frame(width: 20, height: 30)
                    .rotationEffect(.degrees(direction ?? 0))
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
        let v = MapKitView(cacheDirectory: "openseamapcache", urlTemplate: "https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png")
        v.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 43.6956, longitude: 7.2906), span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
        return v.marking([
            MapMarker(coordinate: Coordinate(latitude: 43.6956, longitude: 7.2906), style: .dot(.blue)),
        ])
    }

    @available(watchOS 12, *)
    #Preview("Marker — heading + track") {
        let v = MapKitView(cacheDirectory: "openseamapcache", urlTemplate: "https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png")
        v.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 43.6956, longitude: 7.2906), span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
        let track = (0 ..< 12).map { i in
            Coordinate(latitude: 43.690 + Double(i) * 0.0009, longitude: 7.285 + Double(i) * 0.0007)
        }
        return v
            .tracking([MapTrack(coordinates: track, style: .default)])
            .marking([
                MapMarker(
                    coordinate: track.last!,
                    direction: 40,
                    style: .heading(dot: .blue, indicator: .white)
                ),
            ])
            .centering(on: track.last!)
    }
#endif
