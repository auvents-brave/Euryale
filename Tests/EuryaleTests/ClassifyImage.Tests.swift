import Foundation
import Testing

@testable import Euryale

@Suite("ClassifyImage")
struct ClassifyImageTests {
  #if !os(watchOS)
    #if targetEnvironment(simulator)
      // Skip this test on any Simulator; ML classification isn’t supported here.
      // CSU exception: Failed to create espresso context.
    #else
        @Test func `Classifies a local test asset image`() async throws {
            let url = try #require(testImageURL(named: "TestImage", ext: "jpeg"))
            let results = try await classifyImage(url: url)
            #expect(!results.isEmpty, "Expected at least one classification for the test image.")

            let keywords = ["sailboat", "ocean", "beach"]
            let missingKeywords = keywords.filter { keyword in
                !results.keys.contains { key in
                    key.lowercased().contains(keyword.lowercased())
                }
            }
            #expect(missingKeywords.isEmpty, "Expected classifications to include each of: \(keywords). Missing: \(missingKeywords). Got: \(results.keys.sorted())")
        }
    #endif
  #endif

    @Test func `Loads CGImage from local test asset"`() async throws {
        let url = try #require(testImageURL(named: "TestImage", ext: "jpeg"))
        let cgImage = try await loadCGImage(from: url)
        #expect(cgImage.width > 0 && cgImage.height > 0)
    }
}

private class ResourceLocator {}

private func testImageURL(named name: String, ext: String) -> URL? {
  // Try the test bundle (Xcode) via a class token.
  if let url = Bundle(for: ResourceLocator.self).url(forResource: name, withExtension: ext) {
    return url
  }
  // Try any loaded bundle (Xcode/SwiftPM)
  for bundle in Bundle.allBundles {
    if let url = bundle.url(forResource: name, withExtension: ext) {
      return url
    }
  }
  // Fallback: derive path relative to this test file (useful for SwiftPM Resources folder)
  let fileURL = URL(fileURLWithPath: #filePath)
  let testDir = fileURL.deletingLastPathComponent()
  let candidates = [
    testDir.appendingPathComponent("Resources/\(name).\(ext)"),
    testDir.deletingLastPathComponent().appendingPathComponent("Resources/\(name).\(ext)"),
  ]
  for candidate in candidates {
    if FileManager.default.fileExists(atPath: candidate.path) {
      return candidate
    }
  }
  return nil
}
