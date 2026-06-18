import Foundation
import MapKit
import Testing

@testable import Euryale

@Test func `MapPointsOfInterest maps to an MKMapView filter`() {
	#expect(MapPointsOfInterest.all.mkFilter == nil)
	#expect(MapPointsOfInterest.none.mkFilter != nil)
	#expect(MapPointsOfInterest.including([.marina, .beach]).mkFilter != nil)
}

@Test func `WMSTileSource is value-equatable`() {
	let a = WMSTileSource(cacheDirectory: "gebco", getMapBaseURL: "https://example.com/wms?LAYERS=x")
	let b = WMSTileSource(cacheDirectory: "gebco", getMapBaseURL: "https://example.com/wms?LAYERS=x")
	let c = WMSTileSource(cacheDirectory: "other", getMapBaseURL: "https://example.com/wms?LAYERS=x")
	#expect(a == b)
	#expect(a != c)
}

#if !os(watchOS)
	@Test func `WMSTileOverlay computes the Web Mercator bounding box per tile`() {
		let overlay = WMSTileOverlay(
			directory: "gebco", getMapBaseURL: "https://example.com/wms?LAYERS=x")
		let extent = "20037508.342789244"

		// z0/x0/y0 covers the whole world: ±extent on both axes.
		let world = overlay.url(forTilePath: MKTileOverlayPath(x: 0, y: 0, z: 0, contentScaleFactor: 1))
		#expect(
			world.absoluteString
				== "https://example.com/wms?LAYERS=x&BBOX=-\(extent),-\(extent),\(extent),\(extent)")

		// z1/x1/y0 is the north-east quadrant: x and y run 0 → +extent.
		let quadrant = overlay.url(forTilePath: MKTileOverlayPath(x: 1, y: 0, z: 1, contentScaleFactor: 1))
		#expect(quadrant.absoluteString == "https://example.com/wms?LAYERS=x&BBOX=0.0,0.0,\(extent),\(extent)")
	}

	@Test func `CachedTileOverlay recognises image data and rejects error documents`() {
		#expect(CachedTileOverlay.looksLikeImage(Data([0x89, 0x50, 0x4E, 0x47])))  // PNG
		#expect(CachedTileOverlay.looksLikeImage(Data([0xFF, 0xD8, 0xFF, 0xE0])))  // JPEG
		#expect(CachedTileOverlay.looksLikeImage(Data([0x47, 0x49, 0x46, 0x38])))  // GIF
		#expect(!CachedTileOverlay.looksLikeImage(Data("<?xml version".utf8)))  // WMS exception
		#expect(!CachedTileOverlay.looksLikeImage(Data()))  // empty
	}

	/// A `URLProtocol` stub that answers from the request URL alone (stateless, so
	/// the tests stay parallel-safe): an `error` path yields a 200 with a WMS-style
	/// XML body, a `notfound` path yields 404, anything else a 200 PNG.
	private final class StubURLProtocol: URLProtocol {
		override class func canInit(with request: URLRequest) -> Bool { true }
		override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
		override func stopLoading() {}
		override func startLoading() {
			let path = request.url?.absoluteString ?? ""
			let status = path.contains("notfound") ? 404 : 200
			let response = HTTPURLResponse(
				url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
			client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			if status == 200 {
				let body =
					path.contains("error")
					? Data("<?xml version=\"1.0\"?><ServiceException/>".utf8)
					: Data([0x89, 0x50, 0x4E, 0x47]) + Data(repeating: 0, count: 16)  // PNG signature
				client?.urlProtocol(self, didLoad: body)
			}
			client?.urlProtocolDidFinishLoading(self)
		}
	}

	private func stubbedOverlay(template: String) -> CachedTileOverlay {
		let config = URLSessionConfiguration.ephemeral
		config.protocolClasses = [StubURLProtocol.self]
		return CachedTileOverlay(
			directory: "cto-test-\(UUID().uuidString)", urlTemplate: template,
			session: URLSession(configuration: config))
	}

	private func loadTile(_ overlay: CachedTileOverlay, z: Int = 10) async -> Data? {
		await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
			overlay.loadTile(at: MKTileOverlayPath(x: 0, y: 0, z: z, contentScaleFactor: 1)) { data, _ in
				continuation.resume(returning: data)
			}
		}
	}

	@Test func `A 200 image response is returned, then served from the cache`() async {
		let overlay = stubbedOverlay(template: "https://example.com/img/{z}/{x}/{y}.png")
		#expect(await loadTile(overlay) != nil)  // network fetch
		#expect(await loadTile(overlay) != nil)  // on-disk cache hit
	}

	@Test func `A 200 non-image response (WMS exception) is rejected`() async {
		let overlay = stubbedOverlay(template: "https://example.com/error/{z}/{x}/{y}.png")
		#expect(await loadTile(overlay) == nil)
	}

	@Test func `A non-200 response is rejected`() async {
		let overlay = stubbedOverlay(template: "https://example.com/notfound/{z}/{x}/{y}.png")
		#expect(await loadTile(overlay) == nil)
	}
#endif
