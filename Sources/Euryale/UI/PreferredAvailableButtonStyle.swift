public import SwiftUI

// MARK: - View + PreferredAvailableButtonStyle

extension View {

    // MARK: Public API

    /// Applies the most modern button style available on the current platform.
    ///
    /// Resolution order (newest wins):
    /// 1. **OS 26 +** — `.glass` button style with `.controlSize(.large)`
    ///    (Liquid Glass on macOS Tahoe / iOS 26 / tvOS 26 / watchOS 26 /
    ///    visionOS 26).  Falls through to the bordered-prominent style on
    ///    visionOS where `.glass` is unavailable.
    /// 2. **macOS 12 / iOS 15 / tvOS 15 / watchOS 9 +** — `.borderedProminent`
    ///    with `.controlSize(.large)` and an accent-coloured tint.
    /// 3. **Earlier OSes** — a `.bordered` style on macOS/tvOS (or just an
    ///    accent tint on legacy iOS) as a last-resort fallback.
    ///
    /// ```swift
    /// Button("Continue") { … }
    ///     .PreferredAvailableButtonStyle()
    /// ```
    @ViewBuilder
    public func PreferredAvailableButtonStyle() -> some View {
        if #available(
            macOS 26,
            macCatalyst 26,
            iOS 26,
            watchOS 26,
            tvOS 26,
            visionOS 26,
            *
        ) {
            self.GlassButtonStyle()
        } else {
            self.RegularButtonStyle()
        }
    }

    // MARK: Methods

    @available(macOS 26, macCatalyst 26, iOS 26, watchOS 26, tvOS 26, visionOS 26, *)
    func GlassButtonStyle() -> some View {
        #if !os(visionOS)
            buttonStyle(.glass)
                .controlSize(.large)
        #else
            RegularButtonStyle()
        #endif
    }

    func RegularButtonStyle() -> some View {
        buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.accentColor)
    }

    func FallbackButtonStyle() -> some View {
        #if os(macOS)
            buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.accentColor)
        #elseif !os(iOS)
            buttonStyle(.bordered)
                .tint(.accentColor)
        #else
            tint(.accentColor)
        #endif
    }
}

// MARK: - Previews

#if DEBUG
    @MainActor let previewButton = Button {
    } label: {
        Label("Hello!", systemImage: "fireworks")
    }

    @available(macOS 26, macCatalyst 26, iOS 26, watchOS 26, tvOS 26, visionOS 26, *)
    #Preview("glass") {
        previewButton.GlassButtonStyle()
    }

    @available(macOS 26, macCatalyst 26, iOS 26, watchOS 26, tvOS 26, visionOS 26, *)
    #Preview("regular") {
        previewButton.RegularButtonStyle()
    }

    @available(macOS 26, macCatalyst 26, iOS 26, watchOS 26, tvOS 26, visionOS 26, *)
    #Preview("fallback") {
        previewButton.FallbackButtonStyle()
    }
#endif
