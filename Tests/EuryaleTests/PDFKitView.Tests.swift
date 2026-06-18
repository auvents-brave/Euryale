import Foundation
import Testing

@testable import Euryale

#if os(iOS) || os(macOS) || os(visionOS)
	@MainActor
	@Suite("PDFKitView") struct PDFKitViewTests {
		/// A minimal but valid single-page PDF, accepted by `PDFDocument(data:)`.
		private static let validPDF = Data(
			base64Encoded:
				"JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCAyMDAgMjAwXSA+PgplbmRvYmoKeHJlZgowIDQKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwNTggMDAwMDAgbiAKMDAwMDAwMDExNSAwMDAwMCBuIAp0cmFpbGVyCjw8IC9TaXplIDQgL1Jvb3QgMSAwIFIgPj4Kc3RhcnR4cmVmCjE4NgolJUVPRg=="
		)!

		@Test func `init returns nil for non-existent file`() async throws {
			let badURL = URL(fileURLWithPath: "/nonexistent/missing.pdf")
			let v = PDFKitView(url: badURL)
			#expect(v == nil)
		}

		@Test func `init returns nil for non-PDF data`() async throws {
			// Write a tiny non-PDF file in temp, point the view at it.
			let tmp = FileManager.default.temporaryDirectory
				.appendingPathComponent("not-a-pdf-\(UUID().uuidString).txt")
			try "this is not a pdf".data(using: .utf8)!.write(to: tmp)
			defer { try? FileManager.default.removeItem(at: tmp) }

			let v = PDFKitView(url: tmp)
			#expect(v == nil)
		}

		@Test func `init from data decodes a valid PDF`() async throws {
			#expect(PDFKitView(data: Self.validPDF) != nil)
		}

		@Test func `init from data returns nil for non-PDF bytes`() async throws {
			#expect(PDFKitView(data: Data("this is not a pdf".utf8)) == nil)
		}
	}
#endif
