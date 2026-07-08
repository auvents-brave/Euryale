public import MapKit
import SwiftUI

#if canImport(UIKit)
	internal import UIKit
#elseif canImport(AppKit)
	internal import AppKit
#endif

#if !os(watchOS)

	/// Renders a static chart image from the same ingredients as a live
	/// ``MapKitView``: the base layer (a tile source, or Apple's map when `nil`),
	/// overlay tile layers, tracks stroked halo + core like the live renderer,
	/// and the very same marker bitmaps. Tiles are read through the live map's
	/// disk cache, so a thumbnail costs no network for regions already browsed.
	///
	/// Use it wherever a real map view would be too heavy — e.g. thumbnails in
	/// a scrolling grid — and the result must still look like the app's chart.
	public enum MapChartSnapshot {

		/// The layer stack to draw beneath the tracks and markers — the same
		/// values handed to ``MapKitView``'s `baseTileSource` and overlay layers.
		public struct Layers: Sendable {
			/// The base layer, or `nil` for Apple's own map.
			public var baseTileSource: MapTileSource?
			/// Tile layers composited above the base (e.g. seamarks).
			public var overlays: [MapTileSource]

			/// Creates a layer stack.
			public init(baseTileSource: MapTileSource? = nil, overlays: [MapTileSource] = []) {
				self.baseTileSource = baseTileSource
				self.overlays = overlays
			}
		}

		/// Renders the chart snapshot.
		/// - Parameters:
		///   - region: The region to frame.
		///   - size: The output size, in points.
		///   - layers: The base and overlay tile layers.
		///   - tracks: Polylines, drawn with the live map's halo + core stroke.
		///   - markers: Markers, drawn with the live map's bitmap renderer.
		/// - Returns: The composed image, or `nil` when no base could be produced.
		@MainActor
		public static func render(
			region: MKCoordinateRegion,
			size: CGSize,
			layers: Layers,
			tracks: [MapTrack] = [],
			markers: [MapMarker] = []
		) async -> PlatformImage? {
			// 1. The base bitmap plus a projector from coordinates to view points.
			var placements: [(image: PlatformImage, rect: CGRect)] = []
			let project: (CLLocationCoordinate2D) -> CGPoint
			let zoom = Self.zoom(for: region, width: size.width)

			if let source = layers.baseTileSource {
				project = mercatorProjector(region: region, size: size, zoom: zoom)
				let tiles = await tilePlacements(source: source, region: region, zoom: zoom, project: project)
				guard tiles.isEmpty == false else { return nil }
				placements += tiles
			} else {
				let options = MKMapSnapshotter.Options()
				options.region = region
				options.size = size
				guard let snapshot = try? await MKMapSnapshotter(options: options).start() else {
					return nil
				}
				placements.append((snapshot.image, CGRect(origin: .zero, size: size)))
				project = { snapshot.point(for: $0) }
			}

			// 2. Overlay tile layers, aligned by projecting each tile's corners —
			//    correct over both base kinds (Apple's snapshot or our own tiles).
			for source in layers.overlays {
				placements += await tilePlacements(
					source: source, region: region, zoom: zoom, project: project)
			}

			// 3. Compose: layers, then tracks (halo + core), then marker bitmaps.
			return compose(size: size, placements: placements, tracks: tracks, markers: markers, project: project)
		}

		// MARK: - Composition

		private static func compose(
			size: CGSize,
			placements: [(image: PlatformImage, rect: CGRect)],
			tracks: [MapTrack],
			markers: [MapMarker],
			project: (CLLocationCoordinate2D) -> CGPoint
		) -> PlatformImage {
			render(size: size) { ctx in
				for placement in placements {
					draw(placement.image, in: placement.rect, ctx: ctx)
				}
				for track in tracks where track.coordinates.count >= 2 {
					let points = track.coordinates.map { project(CLLocationCoordinate2D($0)) }
					// The live renderer's stroke: a soft halo beneath a solid core.
					stroke(
						points, ctx: ctx,
						color: PlatformColor(track.style.color).withAlphaComponent(0.22),
						width: track.style.haloWidth)
					stroke(
						points, ctx: ctx,
						color: PlatformColor(track.style.color),
						width: track.style.lineWidth)
				}
				for marker in markers {
					let rendered = MapMarkerImage.make(
						style: marker.style, direction: marker.direction,
						title: marker.title, opacity: marker.opacity)
					let point = project(CLLocationCoordinate2D(marker.coordinate))
					let imageSize = rendered.image.size
					let rect = CGRect(
						x: point.x - imageSize.width / 2 + rendered.centerOffset.x,
						y: point.y - imageSize.height / 2 + rendered.centerOffset.y,
						width: imageSize.width, height: imageSize.height)
					draw(rendered.image, in: rect, ctx: ctx)
				}
			}
		}

		private static func stroke(
			_ points: [CGPoint], ctx: CGContext, color: PlatformColor, width: CGFloat
		) {
			guard let first = points.first else { return }
			ctx.setStrokeColor(color.cgColor)
			ctx.setLineWidth(width)
			ctx.setLineCap(.round)
			ctx.setLineJoin(.round)
			ctx.beginPath()
			ctx.move(to: first)
			for point in points.dropFirst() { ctx.addLine(to: point) }
			ctx.strokePath()
		}

		// MARK: - Tiles

		/// The images and frames of the tiles covering `region` at `zoom`, capped
		/// at 32 tiles per layer as a safety net (a thumbnail needs far fewer).
		@MainActor
		private static func tilePlacements(
			source: MapTileSource,
			region: MKCoordinateRegion,
			zoom: Int,
			project: (CLLocationCoordinate2D) -> CGPoint
		) async -> [(image: PlatformImage, rect: CGRect)] {
			let overlay = CachedTileOverlay(
				directory: source.cacheDirectory,
				urlTemplate: source.urlTemplate,
				appGroup: source.appGroup,
				minimumZ: 1
			)
			let n = 1 << zoom
			let minLon = region.center.longitude - region.span.longitudeDelta / 2
			let maxLon = region.center.longitude + region.span.longitudeDelta / 2
			let minLat = region.center.latitude - region.span.latitudeDelta / 2
			let maxLat = region.center.latitude + region.span.latitudeDelta / 2
			let x0 = max(0, tileX(minLon, n: n))
			let x1 = min(n - 1, tileX(maxLon, n: n))
			let y0 = max(0, tileY(maxLat, n: n))
			let y1 = min(n - 1, tileY(minLat, n: n))
			guard x0 <= x1, y0 <= y1, (x1 - x0 + 1) * (y1 - y0 + 1) <= 32 else { return [] }

			var placements: [(image: PlatformImage, rect: CGRect)] = []
			for x in x0...x1 {
				for y in y0...y1 {
					let path = MKTileOverlayPath(x: x, y: y, z: zoom, contentScaleFactor: 1)
					guard let data = await tileData(overlay, path),
						let image = PlatformImage(data: data)
					else { continue }
					let northWest = project(tileCorner(x: x, y: y, n: n))
					let southEast = project(tileCorner(x: x + 1, y: y + 1, n: n))
					placements.append(
						(
							image,
							CGRect(
								x: northWest.x, y: northWest.y,
								width: southEast.x - northWest.x, height: southEast.y - northWest.y
							)
						))
				}
			}
			return placements
		}

		private static func tileData(_ overlay: CachedTileOverlay, _ path: MKTileOverlayPath) async
			-> Data?
		{
			await withCheckedContinuation { continuation in
				overlay.loadTile(at: path) { data, _ in continuation.resume(returning: data) }
			}
		}

		// MARK: - Web-mercator maths

		/// A zoom whose tile resolution roughly matches the requested pixel size.
		private static func zoom(for region: MKCoordinateRegion, width: CGFloat) -> Int {
			let ideal = log2(360.0 / max(region.span.longitudeDelta, 0.0001) * Double(width) / 256.0)
			return min(17, max(2, Int(ideal.rounded())))
		}

		private static func tileX(_ longitude: Double, n: Int) -> Int {
			Int(floor((longitude + 180) / 360 * Double(n)))
		}

		private static func tileY(_ latitude: Double, n: Int) -> Int {
			let radians = latitude * .pi / 180
			let y = (1 - log(tan(radians) + 1 / cos(radians)) / .pi) / 2
			return Int(floor(y * Double(n)))
		}

		private static func tileCorner(x: Int, y: Int, n: Int) -> CLLocationCoordinate2D {
			let longitude = Double(x) / Double(n) * 360 - 180
			let latitude = atan(sinh(.pi * (1 - 2 * Double(y) / Double(n)))) * 180 / .pi
			return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
		}

		/// Maps coordinates to view points for a tile-based base: the world's
		/// mercator pixel grid at `zoom`, recentred on the region's centre.
		private static func mercatorProjector(
			region: MKCoordinateRegion, size: CGSize, zoom: Int
		) -> (CLLocationCoordinate2D) -> CGPoint {
			let world = Double(256 * (1 << zoom))
			func worldPoint(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
				let x = (coordinate.longitude + 180) / 360 * world
				let radians = coordinate.latitude * .pi / 180
				let y = (1 - log(tan(radians) + 1 / cos(radians)) / .pi) / 2 * world
				return CGPoint(x: x, y: y)
			}
			let centre = worldPoint(region.center)
			return { coordinate in
				let point = worldPoint(coordinate)
				return CGPoint(
					x: point.x - centre.x + size.width / 2,
					y: point.y - centre.y + size.height / 2
				)
			}
		}

		// MARK: - Drawing helpers

		/// Draws a platform image into the y-down context, flipping locally.
		private static func draw(_ image: PlatformImage, in rect: CGRect, ctx: CGContext) {
			guard rect.width > 0, rect.height > 0, let cg = cgImage(image) else { return }
			ctx.saveGState()
			ctx.translateBy(x: rect.minX, y: rect.maxY)
			ctx.scaleBy(x: 1, y: -1)
			ctx.draw(cg, in: CGRect(origin: .zero, size: rect.size))
			ctx.restoreGState()
		}

		private static func cgImage(_ image: PlatformImage) -> CGImage? {
			#if canImport(UIKit)
				return image.cgImage
					?? UIGraphicsImageRenderer(size: image.size).image { _ in image.draw(at: .zero) }.cgImage
			#else
				return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
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

#endif
