import CoreLocation
import MapKit
import Testing

@testable import Euryale

#if !os(watchOS)

	@Test func `tile indices follow the web-mercator grid`() {
		// z1 splits the world in 2×2 tiles.
		#expect(MapChartSnapshot.tileX(-180, n: 2) == 0)
		#expect(MapChartSnapshot.tileX(0, n: 2) == 1)
		#expect(MapChartSnapshot.tileX(179.9, n: 2) == 1)
		// y grows southwards: the equator is the 2nd row's top edge.
		#expect(MapChartSnapshot.tileY(85, n: 2) == 0)
		#expect(MapChartSnapshot.tileY(-0.001, n: 2) == 1)
	}

	@Test func `tile corners invert the tile indices`() {
		let n = 1 << 10
		// Greenwich/equator sits exactly on the corner of tile (n/2, n/2).
		let corner = MapChartSnapshot.tileCorner(x: n / 2, y: n / 2, n: n)
		#expect(abs(corner.longitude) < 0.000001)
		#expect(abs(corner.latitude) < 0.000001)
		// A corner projected back to indices lands on the same tile.
		let monaco = CLLocationCoordinate2D(latitude: 43.73, longitude: 7.42)
		let x = MapChartSnapshot.tileX(monaco.longitude, n: n)
		let y = MapChartSnapshot.tileY(monaco.latitude, n: n)
		let northWest = MapChartSnapshot.tileCorner(x: x, y: y, n: n)
		#expect(MapChartSnapshot.tileX(northWest.longitude + 0.0001, n: n) == x)
		#expect(MapChartSnapshot.tileY(northWest.latitude - 0.0001, n: n) == y)
	}

	@Test func `the snapshot zoom is clamped to 2 through 17`() {
		let world = MKCoordinateRegion(
			center: .init(latitude: 0, longitude: 0),
			span: .init(latitudeDelta: 170, longitudeDelta: 360))
		#expect(MapChartSnapshot.zoom(for: world, width: 64) == 2)
		let pontoon = MKCoordinateRegion(
			center: .init(latitude: 43.73, longitude: 7.42),
			span: .init(latitudeDelta: 0.0001, longitudeDelta: 0.0001))
		#expect(MapChartSnapshot.zoom(for: pontoon, width: 1024) == 17)
	}

	@Test func `the mercator projector centres the region and keeps north up`() {
		let monaco = CLLocationCoordinate2D(latitude: 43.73, longitude: 7.42)
		let region = MKCoordinateRegion(
			center: monaco, span: .init(latitudeDelta: 0.5, longitudeDelta: 0.5))
		let size = CGSize(width: 400, height: 300)
		let project = MapChartSnapshot.mercatorProjector(region: region, size: size, zoom: 10)

		let centre = project(monaco)
		#expect(abs(centre.x - 200) < 0.001)
		#expect(abs(centre.y - 150) < 0.001)

		// North of the centre is higher on the canvas, east is to the right.
		let north = project(.init(latitude: 43.83, longitude: 7.42))
		#expect(north.y < centre.y)
		#expect(abs(north.x - centre.x) < 0.001)
		let east = project(.init(latitude: 43.73, longitude: 7.52))
		#expect(east.x > centre.x)
	}

#endif
