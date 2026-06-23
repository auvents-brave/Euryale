#if !os(watchOS)
	import MapKit
	import SwiftUI

	#if canImport(UIKit)
		import UIKit
	#elseif canImport(AppKit)
		import AppKit
	#endif

	// MARK: - MapDelegate

	/// `MKMapViewDelegate` for ``MapKitView``: renders the cached tile overlays
	/// and — added by `MapKitView+Markers` — the styled polylines (``MapTrack``)
	/// and image markers (``MapMarker``).
	class MapDelegate: PlatformDelegate, MKMapViewDelegate {

		/// Stroke style per polyline overlay, keyed by object identity, set by the
		/// markable representable when it adds the track overlays. The `isHalo`
		/// flag selects the wide translucent underlay vs the bright core line.
		var trackStyles: [ObjectIdentifier: (style: MapTrackStyle, isHalo: Bool)] = [:]

		/// Called with a tapped marker's id, set by the markable representable.
		var onSelect: ((AnyHashable) -> Void)?

		/// Called with the chart coordinate of a tap on open water (not on a
		/// marker), set by the markable representable. Used by route planning to
		/// pick start and end points. `nil` disables tap reporting.
		var onMapTap: ((CLLocationCoordinate2D) -> Void)?

		/// Called with the chart coordinate of a long-press (iOS / iPadOS) or a
		/// secondary (right) click (macOS) on open water — for raising a context
		/// menu at that point. `nil` disables it.
		var onMapLongPress: ((CLLocationCoordinate2D) -> Void)?

		/// The map this delegate drives, held weakly so a tap can be converted from
		/// a view point to a coordinate.
		weak var tappedMap: MKMapView?

		/// Converts a tap location to a chart coordinate and reports it.
		#if canImport(UIKit)
			@objc func handleMapTap(_ recognizer: UITapGestureRecognizer) {
				guard let onMapTap, let map = tappedMap, recognizer.state == .ended else { return }
				let point = recognizer.location(in: map)
				onMapTap(map.convert(point, toCoordinateFrom: map))
			}

			/// Reports the start point of a long-press as a chart coordinate.
			@objc func handleMapLongPress(_ recognizer: UILongPressGestureRecognizer) {
				guard let onMapLongPress, let map = tappedMap, recognizer.state == .began else { return }
				let point = recognizer.location(in: map)
				onMapLongPress(map.convert(point, toCoordinateFrom: map))
			}
		#elseif canImport(AppKit)
			@objc func handleMapTap(_ recognizer: NSClickGestureRecognizer) {
				guard let onMapTap, let map = tappedMap else { return }
				let point = recognizer.location(in: map)
				onMapTap(map.convert(point, toCoordinateFrom: map))
			}

			/// Reports a secondary (right) click as a chart coordinate.
			@objc func handleMapLongPress(_ recognizer: NSClickGestureRecognizer) {
				guard let onMapLongPress, let map = tappedMap else { return }
				let point = recognizer.location(in: map)
				onMapLongPress(map.convert(point, toCoordinateFrom: map))
			}
		#endif

		/// Called whenever the visible region changes (pan / zoom / **rotate**), set
		/// by the markable representable so it can keep directional markers aligned
		/// to the chart when the map is rotated.
		var onRegionChange: ((MKMapView) -> Void)?

		/// Called once the visible region settles after a gesture (not continuously
		/// during it), set by the markable representable to surface the on-screen
		/// bounds to the app — e.g. to draw a large dataset only where it shows.
		var onRegionSettled: ((MKMapView) -> Void)?

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
				let entry = trackStyles[ObjectIdentifier(polyline)]
			{
				let base = PlatformColor(entry.style.color)
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
			let view =
				mapView.dequeueReusableAnnotationView(withIdentifier: id)
				?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
			view.annotation = annotation
			view.canShowCallout = false
			view.image = marker.image
			view.centerOffset = marker.centerOffset
			return view
		}

		/// Notifies the representable of region changes so it can re-orient
		/// directional markers when the map is rotated.
		func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
			onRegionChange?(mapView)
		}

		/// Reports the settled visible region after a pan / zoom / rotate gesture
		/// ends, so the app can refilter what it draws without churning on every
		/// intermediate frame.
		func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
			onRegionSettled?(mapView)
		}

		/// Reports a tapped marker, then immediately deselects it so tapping the
		/// same marker again fires another selection.
		func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
			if let marker = view.annotation as? MarkerAnnotation {
				onSelect?(marker.key)
			}
			mapView.deselectAnnotation(view.annotation, animated: false)
		}
	}

	#if canImport(UIKit)
		// Lets the map-tap recognise alongside MapKit's own gestures, but not when
		// the touch lands on a marker (so tapping a marker selects it rather than
		// dropping a route point).
		extension MapDelegate: UIGestureRecognizerDelegate {
			public func gestureRecognizer(
				_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch
			) -> Bool {
				!(touch.view is MKAnnotationView) && !(touch.view?.superview is MKAnnotationView)
			}

			public func gestureRecognizer(
				_ gestureRecognizer: UIGestureRecognizer,
				shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
			) -> Bool {
				true
			}
		}
	#endif
#endif
