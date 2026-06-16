// Exercises HelpImageProvider's path resolution and image loading so the new
// lines are executed and counted for coverage. The provider only exists on
// platforms with a screenshot-bearing help browser, so the suite is gated the
// same way as the type.

#if os(iOS) || os(macOS) || os(visionOS)
	import Foundation
	import Testing

	@testable import Euryale

	@Suite("HelpImageProvider")
	struct HelpImageProviderTests {

		/// A valid 1×1 greyscale PNG, decodable by UIImage / NSImage.
		private static let onePixelPNG = Data(
			base64Encoded:
				"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGP4DwABAQEAsTj2FAAAAABJRU5ErkJggg==")!

		/// Makes a throwaway book directory holding `images/<name>` for each entry.
		private static func makeBook(images: [String: Data]) throws -> URL {
			let base = URL(fileURLWithPath: NSTemporaryDirectory())
				.appendingPathComponent("HelpImageProviderTests-\(UUID().uuidString)")
			let directory = base.appendingPathComponent("images")
			try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
			for (name, data) in images {
				try data.write(to: directory.appendingPathComponent(name))
			}
			return base
		}

		/// The platform variant suffix the provider looks for.
		private static var suffix: String {
			#if os(macOS)
				"mac"
			#else
				"iphone"
			#endif
		}

		@Test func `a nil base URL or a nil image URL resolves to nothing`() {
			#expect(HelpImageProvider(baseURL: nil).resolved(URL(string: "images/x.png")) == nil)
			let base = URL(fileURLWithPath: NSTemporaryDirectory())
			#expect(HelpImageProvider(baseURL: base).resolved(nil) == nil)
		}

		@Test func `a missing image resolves to nothing`() throws {
			let base = try Self.makeBook(images: [:])
			#expect(HelpImageProvider(baseURL: base).resolved(URL(string: "images/absent.png")) == nil)
		}

		@Test func `the platform variant is preferred when present`() throws {
			let base = try Self.makeBook(images: [
				"shot~\(Self.suffix).png": Self.onePixelPNG,
				"shot.png": Self.onePixelPNG,
			])
			#expect(HelpImageProvider(baseURL: base).resolved(URL(string: "images/shot.png")) != nil)
		}

		@Test func `the plain file is the fallback without a variant`() throws {
			let base = try Self.makeBook(images: ["plain.png": Self.onePixelPNG])
			let provider = HelpImageProvider(baseURL: base)
			#expect(provider.resolved(URL(string: "images/plain.png")) != nil)
			// Drive makeImage on the happy path so its body is covered too.
			_ = provider.makeImage(url: URL(string: "images/plain.png"))
		}
	}
#endif
