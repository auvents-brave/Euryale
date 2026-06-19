import MapKit

#if !os(watchOS)
	class CachedTileOverlay: MKTileOverlay, @unchecked Sendable {

		// MARK: Properties

		// URLSession that bypasses URLCache — we manage our own disk cache.
		let session: URLSession

		// Maximum age before a cached tile is considered stale and re-fetched.
		let maximumCacheAge: TimeInterval

		// Resolved once at init time; never recomputed per tile.
		private let cacheBaseURL: URL

		// MARK: Init

		/// - Parameters:
		///   - directory:        Sub-folder name inside the cache location.
		///   - urlTemplate:      Tile URL template passed to MKTileOverlay.
		///   - appGroup:         Optional App Group identifier (e.g. "group.com.acme.maps").
		///                       When provided, tiles are stored in the shared App Group container
		///                       so that two apps in the same group share the same tile cache.
		///                       Both apps must declare the identifier in their entitlements.
		///                       Falls back to the user's own Caches directory when nil.
		///   - maximumCacheAge:  Seconds before a cached tile is considered stale. Default: 30 days.
		init(
			directory: String = "tilescache",
			urlTemplate: String?,
			appGroup: String? = nil,
			maximumCacheAge: TimeInterval = 30 * 24 * 60 * 60,
			session: URLSession? = nil
		) {
			self.maximumCacheAge = maximumCacheAge

			// Resolve the cache root once.
			// App Group path:  <group-container>/Library/Caches/<directory>
			// Fallback path:   ~/Library/Caches/<directory>  (per-app, sandboxed)
			if let appGroup,
				let groupContainer = FileManager.default.containerURL(
					forSecurityApplicationGroupIdentifier: appGroup)
			{
				cacheBaseURL =
					groupContainer
					.appendingPathComponent("Library/Caches/\(directory)", isDirectory: true)
			} else {
				let cachesRoot =
					(try? FileManager.default.url(
						for: .cachesDirectory,
						in: .userDomainMask,
						appropriateFor: nil,
						create: true
					)) ?? FileManager.default.temporaryDirectory
				cacheBaseURL =
					cachesRoot
					.appendingPathComponent(directory, isDirectory: true)
			}

			// A caller (the tests) may inject a session; otherwise build one that
			// bypasses URLCache so the on-disk cache here is the only cache.
			if let session {
				self.session = session
			} else {
				let config = URLSessionConfiguration.default
				config.urlCache = nil
				config.requestCachePolicy = .reloadIgnoringLocalCacheData
				self.session = URLSession(configuration: config)
			}

			super.init(urlTemplate: urlTemplate)
			minimumZ = 9
			canReplaceMapContent = false
		}

		// MARK: Methods

		override func loadTile(
			at path: MKTileOverlayPath,
			result: @Sendable @escaping (Data?, (any Error)?) -> Void
		) {
			let fileURL = tileFileURL(for: path)

			// Serve a fresh cached tile, but only when it is a real image. A WMS
			// server can answer 200 with an XML `ServiceException`; such a body
			// must never be shown — nor kept — as a tile, so a cached entry that
			// is not an image is treated as a miss and re-fetched (self-healing a
			// cache poisoned while a layer was misconfigured).
			if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
				let modDate = attributes[.modificationDate] as? Date,
				Date().timeIntervalSince(modDate) < maximumCacheAge
			{
				DispatchQueue.global(qos: .userInitiated).async { [weak self] in
					if let data = try? Data(contentsOf: fileURL), Self.looksLikeImage(data) {
						result(data, nil)
					} else {
						self?.fetchTile(at: path, cachedAt: fileURL, result: result)
					}
				}
				return
			}

			// Tile is absent or stale — fetch from network.
			fetchTile(at: path, cachedAt: fileURL, result: result)
		}

		/// Fetches the tile from the network, caching and returning it only when
		/// the response body is a real image.
		private func fetchTile(
			at path: MKTileOverlayPath,
			cachedAt fileURL: URL,
			result: @Sendable @escaping (Data?, (any Error)?) -> Void
		) {
			session.dataTask(with: URLRequest(url: url(forTilePath: path))) { [weak self] data, response, error in
				guard let self else {
					result(nil, error)
					return
				}
				if let error {
					result(nil, error)
					return
				}
				guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
					result(nil, URLError(.badServerResponse))
					return
				}
				// Reject non-image bodies (e.g. a WMS `ServiceException`) so they
				// are neither displayed nor written to the cache.
				guard let data, Self.looksLikeImage(data) else {
					result(nil, URLError(.cannotDecodeContentData))
					return
				}
				self.writeTileToCache(data: data, url: fileURL)
				result(data, nil)
			}.resume()
		}

		/// Whether `data` begins with a known raster-image signature (PNG, JPEG,
		/// GIF or RIFF/WebP) — used to reject WMS error documents and the like.
		static func looksLikeImage(_ data: Data) -> Bool {
			guard data.count >= 4 else { return false }
			let b = [UInt8](data.prefix(4))
			return (b[0] == 0x89 && b[1] == 0x50)  // PNG
				|| (b[0] == 0xFF && b[1] == 0xD8)  // JPEG
				|| (b[0] == 0x47 && b[1] == 0x49)  // GIF
				|| (b[0] == 0x52 && b[1] == 0x49)  // RIFF / WebP
		}

		// MARK: Private helpers

		private func tileFileURL(for path: MKTileOverlayPath) -> URL {
			cacheBaseURL
				.appendingPathComponent(
					"\(path.contentScaleFactor)/\(path.z)/\(path.x)",
					isDirectory: true
				)
				.appendingPathComponent("\(path.y).png")
		}

		private func writeTileToCache(data: Data, url: URL) {
			do {
				try FileManager.default.createDirectory(
					at: url.deletingLastPathComponent(),
					withIntermediateDirectories: true)
				try data.write(to: url, options: .atomic)
			} catch {
				// Best-effort: a write failure just means the tile won't be cached
				// this time; the map will still display correctly.
			}
		}
	}

	/// A ``CachedTileOverlay`` that fetches WMS `GetMap` tiles, computing each
	/// tile's bounding box in Web Mercator (EPSG:3857 / EPSG:900913 — the grid
	/// MapKit itself tiles on) from the slippy-map `z/x/y` path. The disk cache
	/// and staleness handling are inherited unchanged.
	final class WMSTileOverlay: CachedTileOverlay, @unchecked Sendable {

		/// The full WMS `GetMap` URL minus the trailing `&BBOX=` value.
		private let getMapBaseURL: String

		/// Half-width of the Web Mercator square, in metres.
		private static let webMercatorExtent = 20_037_508.342_789_244

		init(
			directory: String,
			getMapBaseURL: String,
			appGroup: String? = nil,
			maximumCacheAge: TimeInterval = 30 * 24 * 60 * 60
		) {
			self.getMapBaseURL = getMapBaseURL
			super.init(
				directory: directory, urlTemplate: nil, appGroup: appGroup,
				maximumCacheAge: maximumCacheAge)
		}

		override func url(forTilePath path: MKTileOverlayPath) -> URL {
			let tiles = pow(2.0, Double(path.z))
			let size = 2 * Self.webMercatorExtent / tiles
			let minX = -Self.webMercatorExtent + Double(path.x) * size
			let maxX = minX + size
			let maxY = Self.webMercatorExtent - Double(path.y) * size
			let minY = maxY - size
			// WMS 1.1.1 with SRS=EPSG:900913 expects BBOX as minX,minY,maxX,maxY.
			let bbox = "\(minX),\(minY),\(maxX),\(maxY)"
			return URL(string: getMapBaseURL + "&BBOX=" + bbox) ?? URL(string: "about:blank")!
		}
	}
#endif
