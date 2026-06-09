import Foundation
import Testing

@testable import Euryale

@Suite("TaggedPhoto")
struct TaggedPhotoTests {
  @Test func `init keeps its data and tags`() {
    let data = Data([0x01, 0x02, 0x03])
    let photo = TaggedPhoto(imageData: data, tags: ["sea": 0.9])

    #expect(photo.imageData == data)
    #expect(photo.tags["sea"] == 0.9)
  }

  #if !os(watchOS)
    @Test func `makeTaggedPhoto loads the image bytes`() async throws {
      let url = try #require(testImageURL(named: "TestImage", ext: "jpeg"))
      let photo = try await makeTaggedPhoto(from: url)

      #expect(!photo.imageData.isEmpty)
      // Tags may be empty on a Simulator where Vision is unavailable; the
      // call still returns the loaded bytes, which is what we assert.
    }
  #endif
}

private final class ResourceLocator {}

private func testImageURL(named name: String, ext: String) -> URL? {
  if let url = Bundle(for: ResourceLocator.self).url(forResource: name, withExtension: ext) {
    return url
  }
  for bundle in Bundle.allBundles {
    if let url = bundle.url(forResource: name, withExtension: ext) {
      return url
    }
  }
  let fileURL = URL(fileURLWithPath: #filePath)
  let testDir = fileURL.deletingLastPathComponent()
  let candidates = [
    testDir.appendingPathComponent("Resources/\(name).\(ext)"),
    testDir.deletingLastPathComponent().appendingPathComponent("Resources/\(name).\(ext)"),
  ]
  for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
    return candidate
  }
  return nil
}
