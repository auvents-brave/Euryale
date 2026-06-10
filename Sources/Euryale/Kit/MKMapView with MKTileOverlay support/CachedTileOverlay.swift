import MapKit

#if !os(watchOS)
	final class CachedTileOverlay: MKTileOverlay, @unchecked Sendable {

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
			maximumCacheAge: TimeInterval = 30 * 24 * 60 * 60
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

			let config = URLSessionConfiguration.default
			config.urlCache = nil
			config.requestCachePolicy = .reloadIgnoringLocalCacheData
			session = URLSession(configuration: config)

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

			// Check whether a fresh cached tile exists.
			if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
				let modDate = attributes[.modificationDate] as? Date,
				Date().timeIntervalSince(modDate) < maximumCacheAge
			{
				// Dispatch the blocking disk read off the calling thread.
				DispatchQueue.global(qos: .userInitiated).async {
					result(try? Data(contentsOf: fileURL), nil)
				}
				return
			}

			// Tile is absent or stale — fetch from network.
			session.dataTask(with: URLRequest(url: url(forTilePath: path))) { [weak self] data, response, error in
				guard let self else {
					result(nil, error)
					return
				}

				if let error {
					result(nil, error)
					return
				}
				guard let http = response as? HTTPURLResponse else {
					result(nil, URLError(.badServerResponse))
					return
				}
				guard http.statusCode == 200 else {
					result(nil, URLError(.badServerResponse))
					return
				}
				guard let data else {
					result(nil, URLError(.zeroByteResource))
					return
				}

				self.writeTileToCache(data: data, url: fileURL)
				result(data, nil)
			}.resume()
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
#endif
