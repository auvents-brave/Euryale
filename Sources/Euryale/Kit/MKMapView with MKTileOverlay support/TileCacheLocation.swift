public import Foundation
public import Stheno

/// Where one layer's tiles sit on disk, and the URL each is fetched from.
///
/// Both the overlay that reads tiles and the prefetch that writes them ahead of
/// a passage go through this, so a tile cannot be filed under one path and
/// looked for under another.
public struct TileCacheLocation: Sendable {

	/// Half-width of the Web Mercator square, in metres.
	static let webMercatorExtent = 20_037_508.342_789_244

	/// The folder holding this layer's tiles.
	public let baseURL: URL

	/// Resolves the folder for a layer.
	///
	/// - Parameters:
	///   - directory: The cache sub-folder name for the layer.
	///   - appGroup: An App Group whose shared container to use, so the cache
	///     survives a reinstall and is shared with the group's other apps;
	///     `nil` uses this app's own Caches.
	public init(directory: String, appGroup: String? = nil) {
		if let appGroup,
			let container = FileManager.default.containerURL(
				forSecurityApplicationGroupIdentifier: appGroup)
		{
			baseURL = container.appendingPathComponent(
				"Library/Caches/\(directory)", isDirectory: true)
		} else {
			let caches =
				(try? FileManager.default.url(
					for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
				?? FileManager.default.temporaryDirectory
			baseURL = caches.appendingPathComponent(directory, isDirectory: true)
		}
	}

	/// The file one tile is cached in.
	///
	/// - Parameters:
	///   - tile: Which tile.
	///   - scale: The content scale the map asked for — a Retina display asks
	///     for 2, and files the result apart from the 1× copy.
	public func fileURL(for tile: TileIndex, scale: Int) -> URL {
		baseURL
			.appendingPathComponent("\(scale)/\(tile.z)/\(tile.x)", isDirectory: true)
			.appendingPathComponent("\(tile.y).png")
	}

	/// Whether that tile is already held.
	public func holds(_ tile: TileIndex, scale: Int) -> Bool {
		FileManager.default.fileExists(atPath: fileURL(for: tile, scale: scale).path)
	}

	/// The slippy-map URL for a tile, filling a `{z}/{x}/{y}` template.
	public static func url(template: String, for tile: TileIndex) -> URL? {
		URL(
			string:
				template
				.replacingOccurrences(of: "{z}", with: "\(tile.z)")
				.replacingOccurrences(of: "{x}", with: "\(tile.x)")
				.replacingOccurrences(of: "{y}", with: "\(tile.y)"))
	}

	/// The WMS `GetMap` URL for a tile, whose bounding box is the tile's own in
	/// Web Mercator — the grid MapKit itself tiles on.
	///
	/// - Parameters:
	///   - getMapBaseURL: The `GetMap` URL without its trailing `&BBOX=` value.
	///   - tile: Which tile.
	public static func wmsURL(getMapBaseURL: String, for tile: TileIndex) -> URL? {
		let size = 2 * webMercatorExtent / pow(2.0, Double(tile.z))
		let minX = -webMercatorExtent + Double(tile.x) * size
		let maxY = webMercatorExtent - Double(tile.y) * size
		// WMS 1.1.1 with SRS=EPSG:900913 expects BBOX as minX,minY,maxX,maxY.
		let bbox = "\(minX),\(maxY - size),\(minX + size),\(maxY)"
		return URL(string: getMapBaseURL + "&BBOX=" + bbox)
	}
}
