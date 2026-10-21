import CoreLocation
import Testing

@testable import Euryale

// The corridor the offline download walks along a route, and the count the
// download sheet shows before fetching anything.
@Suite("OfflineTiles")
struct OfflineTilesTests {

	/// Monaco to La Maddalena, the passage the simulator sails — about 200 NM.
	private let passage = [
		CLLocationCoordinate2D(latitude: 43.73, longitude: 7.42),
		CLLocationCoordinate2D(latitude: 42.50, longitude: 8.60),
		CLLocationCoordinate2D(latitude: 41.19, longitude: 9.40),
	]

	// MARK: The tile grid

	@Test func `a tile is the whole world at zoom nothing`() {
		// One tile covers the Mercator square, so its ground width at the
		// equator is the Earth's circumference.
		#expect(OfflineTiles.tileWidthNM(z: 0, latitude: 0) == 21600)
		// And each zoom halves it.
		#expect(OfflineTiles.tileWidthNM(z: 1, latitude: 0) == 10800)
		#expect(OfflineTiles.tileWidthNM(z: 10, latitude: 0) == 21.09375)  // 21600 / 2^10
	}

	@Test func `tiles shrink towards the poles`() {
		// Mercator keeps the tile grid square, so the ground it covers narrows
		// with the latitude's cosine — a 60° tile is half an equatorial one.
		let equator = OfflineTiles.tileWidthNM(z: 10, latitude: 0)
		let sixty = OfflineTiles.tileWidthNM(z: 10, latitude: 60)
		#expect(abs(sixty - equator / 2) < 0.001)
	}

	@Test func `the origin is the top left of the square`() {
		let (x, y) = OfflineTiles.tilePoint(
			CLLocationCoordinate2D(latitude: 85.051_128, longitude: -180), z: 4)
		#expect(abs(x) < 0.001)
		#expect(abs(y) < 0.001)
	}

	@Test func `the middle of the world is the middle of the square`() {
		let (x, y) = OfflineTiles.tilePoint(
			CLLocationCoordinate2D(latitude: 0, longitude: 0), z: 4)
		#expect(abs(x - 8) < 0.001)
		#expect(abs(y - 8) < 0.001)
	}

	// MARK: The corridor

	@Test func `a route needs two points and a width to hold anything`() {
		let single = [passage[0]]
		#expect(OfflineTiles.tiles(along: single, widthNM: 20, zooms: 6...12).isEmpty)
		#expect(OfflineTiles.tiles(along: [], widthNM: 20, zooms: 6...12).isEmpty)
		#expect(OfflineTiles.tiles(along: passage, widthNM: 0, zooms: 6...12).isEmpty)
	}

	@Test func `every tile asked for is at a zoom that was asked for`() {
		let tiles = OfflineTiles.tiles(along: passage, widthNM: 20, zooms: 8...11)

		#expect(!tiles.isEmpty)
		#expect(tiles.allSatisfy { (8...11).contains($0.z) })
		// Every zoom contributes, and the deeper ones contribute more.
		let byZoom = Dictionary(grouping: tiles, by: \.z).mapValues(\.count)
		#expect(byZoom.keys.sorted() == [8, 9, 10, 11])
		#expect(byZoom[11]! > byZoom[8]!)
	}

	@Test func `no tile falls outside the grid`() {
		let tiles = OfflineTiles.tiles(along: passage, widthNM: 40, zooms: 6...10)

		#expect(tiles.allSatisfy { $0.x >= 0 && $0.y >= 0 })
		#expect(tiles.allSatisfy { $0.x < 1 << $0.z && $0.y < 1 << $0.z })
	}

	@Test func `the route's own tiles are always in the corridor`() {
		// Whatever the sampling does between them, the tiles the waypoints
		// themselves fall in must be covered.
		let z = 12
		let tiles = OfflineTiles.tiles(along: passage, widthNM: 5, zooms: z...z)

		for waypoint in passage {
			let point = OfflineTiles.tilePoint(waypoint, z: z)
			let index = TileIndex(z: z, x: Int(point.x), y: Int(point.y))
			#expect(tiles.contains(index), "waypoint \(waypoint) is not covered")
		}
	}

	@Test func `the corridor has no gaps along a long leg`() {
		// A single 200 NM leg sampled too coarsely would leave holes. Walk it
		// and check every tile the track itself crosses was taken.
		let z = 11
		let leg = [passage[0], passage[2]]
		let tiles = OfflineTiles.tiles(along: leg, widthNM: 5, zooms: z...z)

		for step in 0...400 {
			let along = Double(step) / 400
			let here = CLLocationCoordinate2D(
				latitude: leg[0].latitude + (leg[1].latitude - leg[0].latitude) * along,
				longitude: leg[0].longitude + (leg[1].longitude - leg[0].longitude) * along)
			let point = OfflineTiles.tilePoint(here, z: z)
			#expect(tiles.contains(TileIndex(z: z, x: Int(point.x), y: Int(point.y))))
		}
	}

	@Test func `a wider corridor holds more, a deeper zoom holds far more`() {
		let narrow = OfflineTiles.tileCount(along: passage, widthNM: 10, zooms: 6...12)
		let wide = OfflineTiles.tileCount(along: passage, widthNM: 40, zooms: 6...12)
		#expect(wide > narrow)

		// Each zoom quarters the tile, so a level deeper costs roughly four
		// times as much — the reason the detail slider is the one that matters.
		let to12 = OfflineTiles.tileCount(along: passage, widthNM: 20, zooms: 12...12)
		let to14 = OfflineTiles.tileCount(along: passage, widthNM: 20, zooms: 14...14)
		#expect(to14 > to12 * 8)
	}

	@Test func `the corridor is far cheaper than the box around the passage`() {
		// The claim the whole feature rests on. The box spanning this passage,
		// at the same zooms, against the 20 NM corridor through it.
		let zooms = 6...14
		let corridor = OfflineTiles.tileCount(along: passage, widthNM: 20, zooms: zooms)

		var box = 0
		for z in zooms {
			let topLeft = OfflineTiles.tilePoint(
				CLLocationCoordinate2D(latitude: 43.73, longitude: 7.42), z: z)
			let bottomRight = OfflineTiles.tilePoint(
				CLLocationCoordinate2D(latitude: 41.19, longitude: 9.40), z: z)
			box +=
				(Int(bottomRight.x) - Int(topLeft.x) + 1) * (Int(bottomRight.y) - Int(topLeft.y) + 1)
		}

		#expect(corridor < box / 2, "corridor \(corridor) against box \(box)")
	}
}
