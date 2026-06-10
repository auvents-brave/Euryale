// Verifies that every public view ships with the expected
// `accessibilityIdentifier` modifier.  This guards against accidental removals
// or renames that would silently break downstream XCUITest automation built on
// these IDs.
//
// Uses ViewInspector (MIT, test-only dependency) to introspect the SwiftUI
// view tree without needing a host application.  We use
// `find(viewWithAccessibilityIdentifier:)` rather than walking the hierarchy
// manually — it locates the identifier anywhere under the root view, which is
// robust to internal refactors as long as the ID itself remains.

import CoreGraphics
import Foundation
import MapKit
import SwiftUI
import Testing
import ViewInspector

@testable import Euryale

@MainActor
@Suite("Public-view accessibilityIdentifier") struct AccessibilityIdentifiersTests {

	// MARK: - Kit/* views (UIView/NSView-backed)

	@Test func `MapKitView has expected identifier`() throws {
		_ = try MapKitView().inspect().find(viewWithAccessibilityIdentifier: "MapKitView.map")
	}

	#if os(iOS) || os(macOS)
		@Test func `PDFKitView has expected identifier`() throws {
			let tmp = FileManager.default.temporaryDirectory
				.appendingPathComponent("euryale-test-\(UUID().uuidString).pdf")
			try makeMinimalPDFData().write(to: tmp)
			defer { try? FileManager.default.removeItem(at: tmp) }

			let pdf = try #require(PDFKitView(url: tmp))
			_ = try pdf.inspect().find(viewWithAccessibilityIdentifier: "PDFKitView.pdfView")
		}
	#endif

	@Test func `WebKitView from URL has expected identifier`() throws {
		let v = WebKitView(url: URL(string: "https://example.com")!)
		_ = try v.inspect().find(viewWithAccessibilityIdentifier: "WebKitView.webView")
	}

	#if canImport(WebKit)
		@Test func `WebKitView from string has expected identifier`() throws {
			let v = WebKitView(string: "https://example.com")
			_ = try v.inspect().find(viewWithAccessibilityIdentifier: "WebKitView.webView")
		}
	#endif

	#if !os(watchOS)
		@Test func `TextKitView has expected identifier`() throws {
			_ = try TextKitView().inspect().find(viewWithAccessibilityIdentifier: "TextKitView.textView")
		}
	#endif

	@Test func `HtmlView has expected identifier`() throws {
		let v = HtmlView(forHTML: "Hello <b>World</b>")
		_ = try v.inspect().find(viewWithAccessibilityIdentifier: "HtmlView")
	}

	@Test func `StatusPill has expected identifier`() throws {
		let v = StatusPill(label: "All Good", status: .ok)
		_ = try v.inspect().find(viewWithAccessibilityIdentifier: "StatusPill")
	}

	@Test func `PaginatedPill has expected identifier`() throws {
		struct P: Identifiable {
			let id = UUID()
			let n: Int
		}
		let v = PaginatedPill(pages: [P(n: 1), P(n: 2), P(n: 3)]) { p in
			Text("\(p.n)")
		}
		_ = try v.inspect().find(viewWithAccessibilityIdentifier: "PaginatedPill")
	}

	#if !os(watchOS)
		@Test func `MetalKitView has expected identifier`() throws {
			let v = MetalKitView(source: "")
			_ = try v.inspect().find(viewWithAccessibilityIdentifier: "MetalKitView.mtkView")
		}
	#endif

	// MARK: - UI/* views (pure SwiftUI)

	@Test func `Pill has expected identifier`() throws {
		let v = Pill(label: "Bedrooms", value: 3)
		_ = try v.inspect().find(viewWithAccessibilityIdentifier: "Pill")
	}

	@Test func `PillsView has expected identifier`() throws {
		let v = PillsView(items: [("Home", 1)])
		_ = try v.inspect().find(viewWithAccessibilityIdentifier: "PillsView")
	}

	@Test func `BouncingView has expected identifier`() throws {
		let v = BouncingView { Text("x") }
		_ = try v.inspect().find(viewWithAccessibilityIdentifier: "BouncingView")
	}

	@Test func `PopupMapView has expected identifier`() throws {
		let v = PopupMapView(
			region: MKCoordinateRegion(
				center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
				span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
			))
		_ = try v.inspect().find(viewWithAccessibilityIdentifier: "PopupMapView.button")
	}

	@Test func `PopupWebView has expected identifier`() throws {
		let v = PopupWebView(url: URL(string: "https://example.com")!)
		_ = try v.inspect().find(viewWithAccessibilityIdentifier: "PopupWebView.button")
	}

	#if os(tvOS)
		@Test func `Slider has expected identifier`() throws {
			@State var value = 0.5
			let v = Slider(value: $value, in: 0...1, step: 0.1)
			_ = try v.inspect().find(viewWithAccessibilityIdentifier: "Slider.track")
		}
	#endif
}

#if os(iOS) || os(macOS)
	/// Returns a one-page blank PDF as raw `Data`, using Core Graphics
	/// (cross-platform, no UIKit / AppKit dependency).
	private func makeMinimalPDFData() -> Data {
		let page = CGRect(x: 0, y: 0, width: 612, height: 792)
		var box = page
		let data = NSMutableData()
		guard let consumer = CGDataConsumer(data: data),
			let ctx = CGContext(consumer: consumer, mediaBox: &box, nil)
		else { return Data() }
		ctx.beginPDFPage(nil)
		ctx.endPDFPage()
		ctx.closePDF()
		return data as Data
	}
#endif
