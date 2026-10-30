public import Foundation
public import Stheno

/// A layer the offline download can fill: where its tiles are cached, and how
/// each tile's URL is built.
public struct OfflineTileLayer: Sendable {

	/// How a layer addresses its tiles.
	public enum Addressing: Sendable {
		/// A slippy-map template with `{z}`/`{x}`/`{y}` placeholders.
		case xyz(template: String)
		/// A WMS `GetMap` URL without its trailing `&BBOX=` value.
		case wms(getMapBaseURL: String)
	}

	let location: TileCacheLocation
	let addressing: Addressing

	/// A layer from a base or overlay tile source.
	public init(_ source: MapTileSource) {
		location = TileCacheLocation(
			directory: source.cacheDirectory, appGroup: source.appGroup)
		addressing = .xyz(template: source.urlTemplate)
	}

	/// A layer from a WMS underlay, such as the seabed.
	/// - Parameters:
	///   - source: The WMS source.
	///   - appGroup: An App Group whose shared container caches the tiles.
	public init(_ source: WMSTileSource, appGroup: String? = nil) {
		location = TileCacheLocation(directory: source.cacheDirectory, appGroup: appGroup)
		addressing = .wms(getMapBaseURL: source.getMapBaseURL)
	}

	/// The URL one tile is fetched from.
	public func url(for tile: TileIndex) -> URL? {
		switch addressing {
		case .xyz(let template):
			TileCacheLocation.url(template: template, for: tile)
		case .wms(let base):
			TileCacheLocation.wmsURL(getMapBaseURL: base, for: tile)
		}
	}
}

/// Fills the tile cache ahead of a passage, so the chart still draws once the
/// network is astern.
///
/// Tiles already held are skipped, which is what makes a second run over the
/// same route cheap — it pays only for the gaps. Requests go out a few at a
/// time: these are community tile servers, and a prefetch is the one moment an
/// app could hammer them.
public actor OfflineTileDownload {

	/// How a download is getting on.
	public struct Progress: Sendable, Equatable {
		/// Tiles fetched so far in this run.
		public let fetched: Int
		/// Tiles that were already held, and so never asked for.
		public let skipped: Int
		/// Tiles that could not be fetched.
		public let failed: Int
		/// How many there are in all.
		public let total: Int
		/// Bytes written so far.
		public let bytes: Int

		/// How far along, from 0 to 1.
		public var fraction: Double {
			total == 0 ? 1 : Double(fetched + skipped + failed) / Double(total)
		}
	}

	private let layer: OfflineTileLayer
	private let scales: [Int]
	private let session: URLSession
	private let maximumConcurrent: Int

	/// Creates a download for one layer.
	///
	/// - Parameters:
	///   - layer: Which layer to fill.
	///   - scales: The content scales to hold. A Retina display asks the map for
	///     2× tiles and a plain one for 1×; the same bytes serve both, so
	///     holding each costs a second file but not a second request.
	///   - maximumConcurrent: How many requests may be in flight.
	///   - userAgent: Identifies the app to the tile server, which community
	///     servers require.
	///   - session: A session to use instead of the default one — the tests
	///     pass a stubbed one.
	public init(
		layer: OfflineTileLayer,
		scales: [Int] = [1, 2],
		maximumConcurrent: Int = 4,
		userAgent: String? = nil,
		session: URLSession? = nil
	) {
		self.layer = layer
		self.scales = scales.isEmpty ? [1] : scales
		self.maximumConcurrent = max(1, maximumConcurrent)
		if let session {
			self.session = session
		} else {
			let config = URLSessionConfiguration.default
			config.urlCache = nil
			config.requestCachePolicy = .reloadIgnoringLocalCacheData
			config.httpMaximumConnectionsPerHost = max(1, maximumConcurrent)
			if let userAgent { config.httpAdditionalHeaders = ["User-Agent": userAgent] }
			self.session = URLSession(configuration: config)
		}
	}

	/// How many of those tiles are already on disk, at every scale wanted.
	///
	/// The download sheet shows this beside the total, so a second run over a
	/// route reads as "mostly held" rather than as the whole bill again.
	public func held(_ tiles: some Collection<TileIndex>) -> Int {
		tiles.reduce(0) { count, tile in
			count + (scales.allSatisfy { layer.location.holds(tile, scale: $0) } ? 1 : 0)
		}
	}

	/// Fetches every tile not already held.
	///
	/// - Parameters:
	///   - tiles: The tiles to hold.
	///   - onProgress: Called as the run advances, on the download's own actor.
	/// - Returns: How the run ended.
	/// - Throws: `CancellationError` if the task is cancelled; a tile that
	///   fails is counted, not thrown.
	@discardableResult
	public func download(
		_ tiles: some Collection<TileIndex>,
		onProgress: (@Sendable (Progress) -> Void)? = nil
	) async throws -> Progress {
		let all = Array(tiles)
		var fetched = 0
		var skipped = 0
		var failed = 0
		var bytes = 0

		func report() {
			onProgress?(
				Progress(
					fetched: fetched, skipped: skipped, failed: failed, total: all.count,
					bytes: bytes))
		}
		report()

		var next = 0
		try await withThrowingTaskGroup(of: (Int, Bool).self) { group in
			func start() {
				guard next < all.count else { return }
				let tile = all[next]
				next += 1
				group.addTask { [self] in await fetch(tile) }
			}
			for _ in 0..<min(maximumConcurrent, all.count) { start() }

			while let (written, wasFetched) = try await group.next() {
				try Task.checkCancellation()
				if wasFetched {
					fetched += 1
					bytes += written
				} else if written < 0 {
					failed += 1
				} else {
					skipped += 1
				}
				report()
				start()
			}
		}
		return Progress(
			fetched: fetched, skipped: skipped, failed: failed, total: all.count, bytes: bytes)
	}

	/// Fetches one tile unless it is already held at every scale.
	///
	/// - Returns: The bytes written and whether anything was fetched; a
	///   negative byte count marks a failure.
	private func fetch(_ tile: TileIndex) async -> (Int, Bool) {
		let missing = scales.filter { !layer.location.holds(tile, scale: $0) }
		guard !missing.isEmpty else { return (0, false) }
		guard let url = layer.url(for: tile) else { return (-1, false) }

		do {
			let (data, response) = try await session.data(from: url)
			if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
				return (-1, false)
			}
			guard !data.isEmpty else { return (-1, false) }
			// One request serves every scale: the servers return the same image
			// whatever the map asked for, so the other files are free.
			for scale in missing {
				write(data, to: layer.location.fileURL(for: tile, scale: scale))
			}
			return (data.count * missing.count, true)
		} catch {
			return (-1, false)
		}
	}

	private func write(_ data: Data, to url: URL) {
		do {
			try FileManager.default.createDirectory(
				at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
			try data.write(to: url, options: .atomic)
		} catch {
			// Best-effort, as in the overlay: a tile that fails to write is
			// simply fetched again when the chart needs it.
		}
	}
}
