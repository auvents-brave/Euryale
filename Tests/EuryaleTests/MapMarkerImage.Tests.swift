import Foundation
import SwiftUI
import Testing

@testable import Euryale

#if !os(watchOS)

	/// Every ``MapPositionStyle`` should render into the 52×52 glyph box, with the
	/// canvas anchored on the coordinate (zero offset) when there is no title.
	@Test(
		"every position style renders an untitled 52×52 glyph",
		arguments: [
			MapPositionStyle.dot(.red),
			.heading(dot: .blue, indicator: .white),
			.boatHull(.orange),
			.symbol(systemName: "house.fill", color: .green),
			.shape(.pin, .purple),
			.shape(.square, .yellow),
			.shape(.circle, .cyan),
		])
	func untitledMarker(style: MapPositionStyle) {
		let (image, offset) = MapMarkerImage.make(style: style, direction: 45, title: nil, opacity: 1)
		#expect(image.size == CGSize(width: 52, height: 52))
		#expect(offset == .zero)
	}

	@Test func `a titled marker grows the canvas and re-anchors the glyph`() {
		let (image, offset) = MapMarkerImage.make(
			style: .dot(.red), direction: nil, title: "Santa Maria", opacity: 1)
		#expect(image.size.height > 52)
		#expect(image.size.width >= 52)
		// The glyph — not the canvas centre — stays on the coordinate.
		#expect(offset.y > 0)
	}

	#if canImport(UIKit)
		@Test func `the mark shapes draw distinct bitmaps`() throws {
			func png(_ shape: MapMarkerShape) throws -> Data {
				let (image, _) = MapMarkerImage.make(
					style: .shape(shape, .red), direction: nil, title: nil, opacity: 1)
				return try #require(image.pngData())
			}
			let pin = try png(.pin)
			let square = try png(.square)
			let circle = try png(.circle)
			#expect(pin != square)
			#expect(pin != circle)
			#expect(square != circle)
		}

		@Test func `a shape circle matches the plain dot`() throws {
			let (dot, _) = MapMarkerImage.make(
				style: .dot(.red), direction: nil, title: nil, opacity: 1)
			let (circle, _) = MapMarkerImage.make(
				style: .shape(.circle, .red), direction: nil, title: nil, opacity: 1)
			let dotData = try #require(dot.pngData())
			let circleData = try #require(circle.pngData())
			#expect(dotData == circleData)
		}
	#endif

	@Test func `MapTrackStyle is value-equatable field by field`() {
		let base = MapTrackStyle(color: .blue, lineWidth: 4, haloWidth: 12, fadesAlongLength: true)
		#expect(base == MapTrackStyle())
		#expect(base != MapTrackStyle(color: .red))
		#expect(base != MapTrackStyle(lineWidth: 2))
		#expect(base != MapTrackStyle(haloWidth: 4))
		#expect(base != MapTrackStyle(fadesAlongLength: false))
	}

#endif
