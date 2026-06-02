#if !os(watchOS)
    import MapKit
    import SwiftUI

    // MARK: - MapDelegate

    /// `MKMapViewDelegate` for ``MapKitView``: renders the cached tile overlays
    /// and — added by `MapKitView+Markers` — the styled polylines (``MapTrack``)
    /// and image markers (``MapMarker``).
    class MapDelegate: OSDelegate, MKMapViewDelegate {

        /// Stroke style per polyline overlay, keyed by object identity, set by the
        /// markable representable when it adds the track overlays. The `isHalo`
        /// flag selects the wide translucent underlay vs the bright core line.
        var trackStyles: [ObjectIdentifier: (style: MapTrackStyle, isHalo: Bool)] = [:]

        /// Provides a renderer for tile overlays and styled polylines.
        /// - Parameters:
        ///   - mapView: The `MKMapView` requesting the renderer.
        ///   - overlay: The overlay to render.
        /// - Returns: A tile renderer, a (gradient/plain) polyline renderer, or a
        ///   plain overlay renderer as a fallback.
        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            if let polyline = overlay as? MKPolyline,
               let entry = trackStyles[ObjectIdentifier(polyline)] {
                let base = OSColor(entry.style.color)
                if entry.isHalo {
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    renderer.strokeColor = base.withAlphaComponent(0.22)
                    renderer.lineWidth = entry.style.haloWidth
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                    return renderer
                }
                if entry.style.fadesAlongLength {
                    let renderer = MKGradientPolylineRenderer(polyline: polyline)
                    renderer.setColors(
                        [base.withAlphaComponent(0.0), base.withAlphaComponent(0.35), base],
                        locations: [0.0, 0.5, 1.0]
                    )
                    renderer.lineWidth = entry.style.lineWidth
                    renderer.lineCap = .round
                    return renderer
                }
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = base
                renderer.lineWidth = entry.style.lineWidth
                renderer.lineCap = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        /// Provides an image view for ``MapMarker`` annotations; returns `nil` for
        /// anything else so MapKit keeps its default (e.g. the user-location dot).
        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            guard let marker = annotation as? MarkerAnnotation else { return nil }
            let id = "MapKitView.marker"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.canShowCallout = false
            view.image = marker.image
            return view
        }
    }
#endif
