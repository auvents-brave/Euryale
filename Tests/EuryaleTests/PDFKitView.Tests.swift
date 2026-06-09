import Foundation
import Testing

@testable import Euryale

#if os(iOS) || os(macOS)
  @MainActor
  @Suite("PDFKitView") struct PDFKitViewTests {
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
  }
#endif
