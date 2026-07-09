public import SwiftUI

/// A small, glanceable overlay capsule that pages through compact read-outs —
/// for example a corner heads-up display laid over a map.
///
/// The pill is generic over its pages, so any app supplies its own content and
/// can grow more pages later. It sizes itself to its content (kept small) and,
/// when there is more than one page, shows tappable page dots and supports a
/// horizontal swipe.
public struct MultiPagePill<Page: View>: View {

	private let pageCount: Int
	private let page: (Int) -> Page
	@State private var index = 0

	/// Creates a paged pill.
	/// - Parameters:
	///   - pageCount: Number of pages (at least 1).
	///   - page: Builds the content for a given page index.
	public init(pageCount: Int = 1, @ContentBuilder page: @escaping (Int) -> Page) {
		self.pageCount = max(1, pageCount)
		self.page = page
	}

	/// The content and behaviour of the view.
	public var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			page(min(index, pageCount - 1))
			if pageCount > 1 {
				HStack(spacing: 5) {
					ForEach(0..<pageCount, id: \.self) { i in
						Circle()
							.fill(i == index ? Color.primary : Color.secondary.opacity(0.4))
							.frame(width: 5, height: 5)
							.contentShape(Rectangle())
							.onTapGesture { withAnimation(.easeInOut) { index = i } }
					}
				}
				.frame(maxWidth: .infinity)
			}
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
		.background(.ultraThinMaterial, in: shape)
		.overlay(shape.strokeBorder(.white.opacity(0.12)))
		.fixedSize()
		#if !os(tvOS)
			.gesture(pageSwipe)
		#endif
		.animation(.easeInOut, value: index)
	}

	private var shape: RoundedRectangle {
		RoundedRectangle(cornerRadius: 16, style: .continuous)
	}

	#if !os(tvOS)
		private var pageSwipe: some Gesture {
			DragGesture(minimumDistance: 20)
				.onEnded { value in
					guard pageCount > 1 else { return }
					withAnimation(.easeInOut) {
						if value.translation.width < -20 {
							index = (index + 1) % pageCount
						} else if value.translation.width > 20 {
							index = (index - 1 + pageCount) % pageCount
						}
					}
				}
		}
	#endif
}

// MARK: - Previews

/// A stand-in sea backdrop so the pill's translucent material reads correctly.
private var seaBackdrop: some View {
	LinearGradient(
		colors: [.teal, .blue, .indigo],
		startPoint: .top, endPoint: .bottom
	)
	.ignoresSafeArea()
}

#Preview("Single page") {
	ZStack(alignment: .topLeading) {
		seaBackdrop
		MultiPagePill { _ in
			VStack(alignment: .leading) {
				Text("Speed")
					.font(.caption2)
					.foregroundStyle(.secondary)
				Text("12.4 kn")
					.font(.headline.monospacedDigit())
			}
		}
		.padding()
	}
}

/// Preview host: a three-page boat read-out HUD.
private struct ReadoutHUDPreview: View {
	struct Readout {
		let title: LocalizedStringKey
		let value: String
		let systemImage: String
	}

	let pages = [
		Readout(title: "Heading", value: "235°", systemImage: "location.north.line"),
		Readout(title: "Speed", value: "12.4 kn", systemImage: "speedometer"),
		Readout(title: "Apparent wind", value: "18 kn", systemImage: "wind"),
	]

	var body: some View {
		ZStack(alignment: .topLeading) {
			seaBackdrop
			MultiPagePill(pageCount: pages.count) { index in
				let page = pages[index]
				HStack(spacing: 8) {
					Image(systemName: page.systemImage)
						.font(.title3)
					VStack(alignment: .leading) {
						Text(page.title)
							.font(.caption2)
							.foregroundStyle(.secondary)
						Text(page.value)
							.font(.headline.monospacedDigit())
					}
				}
			}
			.padding()
		}
	}
}

#Preview("Three pages — boat read-out HUD") {
	ReadoutHUDPreview()
}

#Preview("Centred over a map corner") {
	ZStack(alignment: .bottomTrailing) {
		seaBackdrop
		MultiPagePill(pageCount: 2) { index in
			Text(index == 0 ? "Page one" : "Page two")
				.font(.headline)
		}
		.padding()
	}
}
