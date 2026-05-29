#if !os(watchOS)
    import MapKit

    /// MKMapViewDelegate implementation for rendering MKTileOverlay objects.
    /// Use this delegate to customise map overlay rendering in a cross-platform manner.
    class MapDelegate: OSDelegate, MKMapViewDelegate {
        /// Provides a renderer for MKTileOverlay overlays. Asserts overlay is MKTileOverlay.
        /// - Parameters:
        ///   - mapView: The MKMapView requesting the renderer.
        ///   - overlay: The overlay to render. Must be an MKTileOverlay.
        /// - Returns: A renderer for MKTileOverlay overlays.
        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            assert(overlay is MKTileOverlay)
            return MKTileOverlayRenderer(overlay: overlay)
        }
    }
#endif
