import Foundation
import Stheno
import Testing

@testable import Euryale

#if !os(watchOS)

	/// Answers from the request URL alone, so the tests stay parallel-safe: a
	/// `notfound` path yields 404, an `offline` path fails with no connection,
	/// anything else a 200 PNG.
	private final class StubTileProtocol: URLProtocol {
		override class func canInit(with request: URLRequest) -> Bool { true }
		override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
		override func stopLoading() {}
		override func startLoading() {
			let path = request.url?.absoluteString ?? ""
			if path.contains("offline") {
				client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
				return
			}
			let status = path.contains("notfound") ? 404 : 200
			let response = HTTPURLResponse(
				url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
			client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			if status == 200 {
				client?.urlProtocol(
					self, didLoad: Data([0x89, 0x50, 0x4E, 0x47]) + Data(repeating: 0, count: 28))
			}
			client?.urlProtocolDidFinishLoading(self)
		}
	}

	@Suite("OfflineTileDownload")
	struct OfflineTileDownloadTests {

		private func stubbedSession() -> URLSession {
			let config = URLSessionConfiguration.ephemeral
			config.protocolClasses = [StubTileProtocol.self]
			return URLSession(configuration: config)
		}

		/// A layer in its own throwaway cache folder, removed when the test ends.
		private func scratchLayer(
			template: String = "https://example.com/t/{z}/{x}/{y}.png"
		) -> (OfflineTileLayer, TileCacheLocation) {
			let source = MapTileSource(
				cacheDirectory: "otd-test-\(UUID().uuidString)", urlTemplate: template)
			let layer = OfflineTileLayer(source)
			return (layer, layer.location)
		}

		private func tidy(_ location: TileCacheLocation) {
			try? FileManager.default.removeItem(at: location.baseURL)
		}

		private let three = [
			TileIndex(z: 10, x: 1, y: 2),
			TileIndex(z: 10, x: 1, y: 3),
			TileIndex(z: 10, x: 2, y: 2),
		]

		// MARK: Addressing

		@Test func `a slippy-map layer fills its template`() {
			let (layer, location) = scratchLayer()
			defer { tidy(location) }

			#expect(
				layer.url(for: TileIndex(z: 10, x: 3, y: 4))?.absoluteString
					== "https://example.com/t/10/3/4.png")
		}

		@Test func `a WMS layer asks for the tile's own bounding box`() {
			let source = WMSTileSource(
				cacheDirectory: "otd-wms", getMapBaseURL: "https://example.com/wms?LAYERS=x")
			let layer = OfflineTileLayer(source)
			let extent = "20037508.342789244"

			// z0/x0/y0 is the whole world: ±extent on both axes.
			#expect(
				layer.url(for: TileIndex(z: 0, x: 0, y: 0))?.absoluteString
					== "https://example.com/wms?LAYERS=x&BBOX=-\(extent),-\(extent),\(extent),\(extent)")
		}

		// MARK: What is already held

		@Test func `an empty cache holds nothing`() async {
			let (layer, location) = scratchLayer()
			defer { tidy(location) }
			let download = OfflineTileDownload(layer: layer, session: stubbedSession())

			#expect(await download.held(three) == 0)
		}

		@Test func `a tile counts as held only at every scale wanted`() async {
			let (layer, location) = scratchLayer()
			defer { tidy(location) }
			let download = OfflineTileDownload(
				layer: layer, scales: [1, 2], session: stubbedSession())

			// Only the 1× copy on disk: not held, because the Retina map would
			// still have to fetch it.
			let file = location.fileURL(for: three[0], scale: 1)
			try? FileManager.default.createDirectory(
				at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
			try? Data([0x89, 0x50, 0x4E, 0x47]).write(to: file)

			#expect(await download.held(three) == 0)
			#expect(location.holds(three[0], scale: 1))
			#expect(!location.holds(three[0], scale: 2))
		}

		// MARK: Downloading

		@Test func `every missing tile is fetched and then held`() async throws {
			let (layer, location) = scratchLayer()
			defer { tidy(location) }
			let download = OfflineTileDownload(layer: layer, session: stubbedSession())

			let result = try await download.download(three)

			#expect(result.fetched == 3)
			#expect(result.skipped == 0)
			#expect(result.failed == 0)
			#expect(result.total == 3)
			#expect(result.bytes > 0)
			#expect(result.fraction == 1)
			#expect(await download.held(three) == 3)
		}

		@Test func `one request serves both scales`() async throws {
			let (layer, location) = scratchLayer()
			defer { tidy(location) }
			let download = OfflineTileDownload(
				layer: layer, scales: [1, 2], session: stubbedSession())

			try await download.download([three[0]])

			// The servers return the same image whatever scale the map asked
			// for, so the second file costs disk but not a second request.
			#expect(location.holds(three[0], scale: 1))
			#expect(location.holds(three[0], scale: 2))
		}

		@Test func `a second run pays only for the gaps`() async throws {
			let (layer, location) = scratchLayer()
			defer { tidy(location) }
			let download = OfflineTileDownload(layer: layer, session: stubbedSession())

			try await download.download([three[0]])
			let again = try await download.download(three)

			#expect(again.skipped == 1)
			#expect(again.fetched == 2)
		}

		@Test func `a tile the server refuses is counted, not thrown`() async throws {
			let (layer, location) = scratchLayer(
				template: "https://example.com/notfound/{z}/{x}/{y}.png")
			defer { tidy(location) }
			let download = OfflineTileDownload(layer: layer, session: stubbedSession())

			let result = try await download.download(three)

			#expect(result.failed == 3)
			#expect(result.fetched == 0)
			// A passage prepared beside a flaky server still finishes.
			#expect(result.fraction == 1)
		}

		@Test func `a network that drops is counted too`() async throws {
			let (layer, location) = scratchLayer(
				template: "https://example.com/offline/{z}/{x}/{y}.png")
			defer { tidy(location) }
			let download = OfflineTileDownload(layer: layer, session: stubbedSession())

			#expect(try await download.download(three).failed == 3)
		}

		@Test func `progress is reported and never goes backwards`() async throws {
			let (layer, location) = scratchLayer()
			defer { tidy(location) }
			let download = OfflineTileDownload(layer: layer, session: stubbedSession())

			let seen = Reported()
			try await download.download(three) { progress in seen.add(progress.fraction) }

			let fractions = seen.values
			#expect(fractions.first == 0)
			#expect(fractions.last == 1)
			#expect(fractions == fractions.sorted())
		}

		@Test func `downloading nothing is already finished`() async throws {
			let (layer, location) = scratchLayer()
			defer { tidy(location) }
			let download = OfflineTileDownload(layer: layer, session: stubbedSession())

			let result = try await download.download([TileIndex]())

			#expect(result.total == 0)
			#expect(result.fraction == 1)
		}
	}

	/// Collects the progress fractions a run reports.
	private final class Reported: @unchecked Sendable {
		private let lock = NSLock()
		private var seen: [Double] = []

		func add(_ fraction: Double) {
			lock.lock()
			seen.append(fraction)
			lock.unlock()
		}

		var values: [Double] {
			lock.lock()
			defer { lock.unlock() }
			return seen
		}
	}

#endif
