#if os(tvOS) || os(watchOS)
    public import SwiftUI

    /// A tvOS / watchOS replacement for SwiftUI's `DisclosureGroup`.
    ///
    /// On tvOS and watchOS the standard `DisclosureGroup` is unavailable. This view
    /// presents the label as a button that toggles a chevron and reveals the content
    /// below when expanded.
    ///
    /// The public API mirrors SwiftUI's `init(isExpanded:content:label:)` so call sites
    /// require no platform guards:
    ///
    /// ```swift
    /// DisclosureGroup(isExpanded: $expanded) {
    ///     Text("Content")
    /// } label: {
    ///     Text("Title")
    /// }
    /// ```
    public struct DisclosureGroup<Label: View, Content: View>: View {
        @Binding private var isExpanded: Bool
        private let content: () -> Content
        private let label: () -> Label

        public init(
            isExpanded: Binding<Bool>,
            @ViewBuilder content: @escaping () -> Content,
            @ViewBuilder label: @escaping () -> Label
        ) {
            _isExpanded = isExpanded
            self.content = content
            self.label = label
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack {
                        label()
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.forward")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    content()
                }
            }
        }
    }
#endif
