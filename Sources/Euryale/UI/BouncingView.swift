public import SwiftUI

/// A SwiftUI view modifier that gives its content a tap-to-bounce micro-animation.
///
/// On tap the content briefly scales down to 80 % then springs back to its
/// original size, providing tactile feedback without changing the underlying
/// behaviour.  Useful on tvOS where focus-driven controls do not always feel
/// responsive enough on their own.
///
/// ```swift
/// BouncingView {
///     Button("Tap me") { … }
/// }
/// ```
public struct BouncingView<T: View>: View {
    @State private var scale: CGFloat = 1.0
    let content: () -> T

    /// Creates a bouncing wrapper around the supplied SwiftUI content.
    ///
    /// - Parameter content: A `@ViewBuilder` closure producing the wrapped view.
    public init(@ViewBuilder content: @escaping () -> T) {
        self.content = content
    }

    public var body: some View {
        content()
            .scaleEffect(scale)
            .onTapGesture {
                withAnimation {
                    scale = 0.8
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    withAnimation {
                        scale = 1.0
                    }
                }
            }
            .accessibilityIdentifier("BouncingView")
    }
}

#Preview("Button") {
    BouncingView {
        Button(action: {}, label: { Text("Click Me!").font(.largeTitle) })
    }
}

#Preview("Image") {
    BouncingView {
        Image(
            systemName: "square.and.arrow.up.trianglebadge.exclamationmark.fill"
        )
        .resizable()
        .aspectRatio(contentMode: .fit)
    }
}
