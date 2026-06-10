public import Foundation
public import SwiftUI

// MARK: - TaggedPhoto

/// A photo together with the image-classification labels produced for it.
///
/// App-neutral and asset-free: it carries only the image bytes and a
/// `label → confidence` dictionary (as returned by ``classifyImage(url:)``).
/// `Sendable`, so it crosses actor boundaries freely — the classification work
/// can run off the main actor and the result hand back to a `@MainActor` view.
public struct TaggedPhoto: Identifiable, Sendable, Hashable {
	public let id: UUID
	/// The encoded image (PNG / JPEG / HEIC bytes).
	public let imageData: Data
	/// Classification labels keyed by identifier, with `0.0 ... 1.0` confidence.
	public let tags: [String: Double]

	public init(id: UUID = UUID(), imageData: Data, tags: [String: Double] = [:]) {
		self.id = id
		self.imageData = imageData
		self.tags = tags
	}
}

#if !os(watchOS)
	/// Loads the image at `url` and classifies it, returning a ``TaggedPhoto``.
	///
	/// A pure function with no global state — the caller owns whatever storage
	/// the result ends up in.
	///
	/// - Parameters:
	///   - url: A local file URL pointing to the image to ingest.
	///   - id: An optional stable identity for the resulting photo.
	/// - Returns: The photo bytes paired with its classification labels.
	/// - Throws: Any error thrown while reading the file or running Vision.
	public func makeTaggedPhoto(from url: URL, id: UUID = UUID()) async throws -> TaggedPhoto {
		let data = try Data(contentsOf: url)
		let tags = (try? await classifyImage(url: url)) ?? [:]
		return TaggedPhoto(id: id, imageData: data, tags: tags)
	}
#endif

// MARK: - TaggedPhotoGallery

/// A paginated gallery that shows tagged photos one at a time, drawing each
/// classification label as a small pill overlaid on the image.
///
/// The pill background colour is supplied by the caller — Euryale ships no asset
/// catalog, so apps pass in their own brand colour (e.g. an asset colour).
public struct TaggedPhotoGallery: View {
	private let photos: [TaggedPhoto]
	private let pillColor: Color
	private let pillForeground: Color
	private let maxTagsPerPhoto: Int
	private let minimumConfidence: Double

	/// Creates a tagged-photo gallery.
	///
	/// - Parameters:
	///   - photos: The photos to page through.
	///   - pillColor: Background colour for the label pills.
	///   - pillForeground: Text colour for the label pills. Defaults to white.
	///   - maxTagsPerPhoto: Maximum number of labels drawn per photo, highest
	///     confidence first. Defaults to `6`.
	///   - minimumConfidence: Labels below this confidence are dropped. Defaults
	///     to `0.1`.
	public init(
		photos: [TaggedPhoto],
		pillColor: Color,
		pillForeground: Color = .white,
		maxTagsPerPhoto: Int = 6,
		minimumConfidence: Double = 0.1
	) {
		self.photos = photos
		self.pillColor = pillColor
		self.pillForeground = pillForeground
		self.maxTagsPerPhoto = maxTagsPerPhoto
		self.minimumConfidence = minimumConfidence
	}

	public var body: some View {
		PaginatedView(pages: photos) { photo in
			// The image is bounded to the page (both dimensions) and fitted, so the
			// whole photo shows rather than only its top, and the label pills — an
			// overlay anchored to the visible bottom — are never pushed off-screen.
			photoImage(photo)
				.resizable()
				.scaledToFit()
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.overlay(alignment: .bottomLeading) {
					TagFlowLayout(spacing: 4) {
						ForEach(topLabels(for: photo), id: \.self) { label in
							Text(label)
								.font(.caption2)
								.lineLimit(1)
								.padding(.horizontal, 8)
								.padding(.vertical, 3)
								.foregroundStyle(pillForeground)
								.background(pillColor, in: Capsule())
						}
					}
					.padding(8)
				}
				.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
		}
	}

	/// The highest-confidence labels for a photo, filtered and capped.
	private func topLabels(for photo: TaggedPhoto) -> [String] {
		photo.tags
			.filter { $0.value >= minimumConfidence }
			.sorted { $0.value > $1.value }
			.prefix(maxTagsPerPhoto)
			.map(\.key)
	}

	private func photoImage(_ photo: TaggedPhoto) -> Image {
		if let osImage = PlatformImage(data: photo.imageData) {
			#if canImport(UIKit)
				return Image(uiImage: osImage)
			#elseif canImport(AppKit)
				return Image(nsImage: osImage)
			#else
				return Image(systemName: "photo")
			#endif
		}
		return Image(systemName: "photo")
	}
}

// MARK: - TagFlowLayout

/// A minimal wrapping layout: places subviews left-to-right and wraps to a new
/// line when the row is full. Used for the label pills so they flow over two or
/// three lines rather than overflowing.
struct TagFlowLayout: Layout {
	var spacing: CGFloat = 4

	func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
		let maxWidth = proposal.width ?? .infinity
		var rowWidth: CGFloat = 0
		var rowHeight: CGFloat = 0
		var totalHeight: CGFloat = 0
		var totalWidth: CGFloat = 0
		for subview in subviews {
			let size = subview.sizeThatFits(.unspecified)
			if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
				totalHeight += rowHeight + spacing
				totalWidth = max(totalWidth, rowWidth)
				rowWidth = size.width
				rowHeight = size.height
			} else {
				rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
				rowHeight = max(rowHeight, size.height)
			}
		}
		totalHeight += rowHeight
		totalWidth = max(totalWidth, rowWidth)
		return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
	}

	func placeSubviews(
		in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
	) {
		let maxWidth = bounds.width
		var x = bounds.minX
		var y = bounds.minY
		var rowHeight: CGFloat = 0
		for subview in subviews {
			let size = subview.sizeThatFits(.unspecified)
			if x > bounds.minX, x + size.width - bounds.minX > maxWidth {
				x = bounds.minX
				y += rowHeight + spacing
				rowHeight = 0
			}
			subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
			x += size.width + spacing
			rowHeight = max(rowHeight, size.height)
		}
	}
}

// MARK: - Previews

#if DEBUG
	#Preview("TaggedPhotoGallery") {
		// Empty image data renders the "photo" placeholder, so the preview shows
		// the label-pill flow and paging without bundling sample images.
		TaggedPhotoGallery(
			photos: [
				TaggedPhoto(imageData: Data(), tags: ["sea": 0.95, "horizon": 0.6, "sky": 0.4]),
				TaggedPhoto(imageData: Data(), tags: ["sail": 0.9, "boat": 0.7]),
			],
			pillColor: .blue
		)
		.frame(height: 220)
		.padding()
	}
#endif
