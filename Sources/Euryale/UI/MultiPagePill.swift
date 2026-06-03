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
    public init(pageCount: Int = 1, @ViewBuilder page: @escaping (Int) -> Page) {
        self.pageCount = max(1, pageCount)
        self.page = page
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            page(min(index, pageCount - 1))
            if pageCount > 1 {
                HStack(spacing: 5) {
                    ForEach(0 ..< pageCount, id: \.self) { i in
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
