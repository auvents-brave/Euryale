import SwiftUI

/// A disclosure section that works on every platform.
///
/// Uses the native `DisclosureGroup` on iOS / macOS / Mac Catalyst / visionOS,
/// and a manual button-toggle fallback on tvOS / watchOS, where `DisclosureGroup`
/// is unavailable. The public interface is the same as `DisclosureGroup`'s
/// `init(isExpanded:content:label:)`.
struct CrossPlatformDisclosure<Label: View, Content: View>: View {
    @Binding private var isExpanded: Bool
    private let content: () -> Content
    private let label: () -> Label

    init(
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: @escaping () -> Label
    ) {
        _isExpanded = isExpanded
        self.content = content
        self.label = label
    }

    var body: some View {
        #if os(tvOS) || os(watchOS)
            // Manual disclosure — DisclosureGroup is unavailable on these platforms.
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
        #else
            DisclosureGroup(isExpanded: $isExpanded, content: content, label: label)
        #endif
    }
}
