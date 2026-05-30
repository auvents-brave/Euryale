public import AppIntents
public import SwiftUI

// MARK: - Protocol

/// An `AppIntent` that supplies the Siri phrase shown in the tip card
/// on macOS and Mac Catalyst, where the system `SiriTipView` is unavailable.
public protocol SiriTipDisplayable: AppIntent {
    /// Primary Siri phrase displayed to the user.
    static var tipPhrase: LocalizedStringResource { get }
}

// MARK: - SiriTipItem

/// A typed (intent, visibility) pair consumed by ``RollingTipView``.
///
/// Hides the `SiriTipView` construction so call sites only pass intents:
///
/// ```swift
/// RollingTipView(
///     .init(intent: CountFurnitureIntent(), isVisible: $show1),
///     .init(intent: CountThingsIntent(),    isVisible: $show2)
/// )
/// ```
public struct SiriTipItem {
    let isVisible: Binding<Bool>
    let view: AnyView

    public init<I: SiriTipDisplayable>(_ intent: I, _ isVisible: Binding<Bool>) {
        self.isVisible = isVisible
        #if os(macOS) || targetEnvironment(macCatalyst)
        self.view = AnyView(SiriTipView(intent: intent, isVisible: isVisible))
        #else
        self.view = AnyView(
            SiriTipView(intent: intent, isVisible: isVisible)
                .siriTipViewStyle(.automatic)
        )
        #endif
    }
}

// MARK: - macOS / Mac Catalyst implementation

/// On macOS and Mac Catalyst the system `SiriTipView` (AppIntents) is unavailable.
/// This implementation provides the same `init(intent:isVisible:)` interface so
/// that ``SiriTipItem`` and ``RollingTipView`` compile identically on all platforms.
#if os(macOS) || targetEnvironment(macCatalyst)
public struct SiriTipView<Intent: SiriTipDisplayable>: View {
    let intent: Intent
    @Binding var isVisible: Bool

    public init(intent: Intent, isVisible: Binding<Bool>) {
        self.intent = intent
        _isVisible = isVisible
    }

    public var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                Text(Intent.tipPhrase)
                    .font(.caption)
                Spacer()
                Button { isVisible = false } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
#endif

// MARK: - Preview

#if DEBUG
private struct _DemoIntent: SiriTipDisplayable {
    static let title: LocalizedStringResource = "Demo"
    static let tipPhrase: LocalizedStringResource = "Try this in App"
    func perform() async throws -> some IntentResult { .result() }
}

#Preview {
    @Previewable @State var visible = true
    SiriTipView(intent: _DemoIntent(), isVisible: $visible)
        .padding()
}
#endif
