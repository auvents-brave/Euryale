public import CoreLocation
public import Stheno

// The tile arithmetic itself moved to Stheno, which the companion app reaches
// too and which carries no Apple frameworks — a download that asks for one set
// of tiles here and another there would be two features wearing one name.
// `TileIndex` and `OfflineTiles` are re-exported above, so hosts need no second
// import; what stays here is the bridge from CoreLocation's coordinate, which
// is the one Apple shape in the signature.

extension OfflineTiles {

	/// Every tile within `widthNM / 2` of the route, at each zoom in `zooms`.
	///
	/// - Parameters:
	///   - route: The passage, in order. Fewer than two points yields nothing.
	///   - widthNM: The corridor's full width, in nautical miles.
	///   - zooms: The zoom levels to cover.
	/// - Returns: The tiles to hold, with no duplicates.
	public static func tiles(
		along route: [CLLocationCoordinate2D], widthNM: Double, zooms: ClosedRange<Int>
	) -> Set<TileIndex> {
		tiles(along: route.map(Coordinate.init(_:)), widthNM: widthNM, zooms: zooms)
	}

	/// How many tiles that corridor holds — the figure the download sheet shows
	/// before anything is fetched.
	///
	/// - Parameters:
	///   - route: The passage, in order.
	///   - widthNM: The corridor's full width, in nautical miles.
	///   - zooms: The zoom levels to cover.
	/// - Returns: The number of distinct tiles.
	public static func tileCount(
		along route: [CLLocationCoordinate2D], widthNM: Double, zooms: ClosedRange<Int>
	) -> Int {
		tiles(along: route, widthNM: widthNM, zooms: zooms).count
	}
}

extension Coordinate {

	/// Takes a CoreLocation coordinate as Stheno's own.
	/// - Parameter coordinate: The CoreLocation value.
	fileprivate init(_ coordinate: CLLocationCoordinate2D) {
		self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
	}
}
