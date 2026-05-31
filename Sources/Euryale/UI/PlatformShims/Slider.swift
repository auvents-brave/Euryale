#if os(tvOS)
    public import SwiftUI

    /// A tvOS replacement for SwiftUI's `Slider`.
    ///
    /// On tvOS the standard `Slider` is unavailable.  This view presents the
    /// available values as a scrollable `List` that the user navigates with the
    /// Siri Remote D-pad.  The currently selected row is marked with a checkmark
    /// and the list scrolls to it automatically when the view appears.
    ///
    /// The public API is intentionally identical to SwiftUI's `Slider` so that
    /// call sites require no platform guards:
    ///
    /// ```swift
    /// Slider(value: $zoom, in: 1...10, step: 0.5)
    /// ```
    ///
    /// When no `step` is supplied the range is divided into 20 equal steps.
    public struct Slider: View {
        @Binding private var value: Double
        private let bounds: ClosedRange<Double>
        private let step: Double?
        private let onEditingChanged: (Bool) -> Void

        // MARK: Initialisers (same signatures as SwiftUI.Slider)

        public init(
            value: Binding<Double>,
            onEditingChanged: @escaping (Bool) -> Void = { _ in }
        ) {
            self.init(value: value, in: 0...1, onEditingChanged: onEditingChanged)
        }

        public init(
            value: Binding<Double>,
            in bounds: ClosedRange<Double> = 0...1,
            onEditingChanged: @escaping (Bool) -> Void = { _ in }
        ) {
            _value = value
            self.bounds = bounds
            step = nil
            self.onEditingChanged = onEditingChanged
        }

        public init(
            value: Binding<Double>,
            step: Double,
            onEditingChanged: @escaping (Bool) -> Void = { _ in }
        ) {
            self.init(value: value, in: 0...1, step: step, onEditingChanged: onEditingChanged)
        }

        public init(
            value: Binding<Double>,
            in bounds: ClosedRange<Double> = 0...1,
            step: Double,
            onEditingChanged: @escaping (Bool) -> Void = { _ in }
        ) {
            _value = value
            self.bounds = bounds
            self.step = step > 0 ? step : nil
            self.onEditingChanged = onEditingChanged
        }

        // MARK: Body

        public var body: some View {
            ScrollViewReader { proxy in
                List {
                    ForEach(steps, id: \.self) { stepValue in
                        Button {
                            onEditingChanged(true)
                            value = stepValue
                            onEditingChanged(false)
                        } label: {
                            HStack {
                                Text(formatted(stepValue))
                                Spacer()
                                if isSelected(stepValue) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .id(stepValue)
                    }
                }
                .onAppear {
                    scrollToCurrentValue(proxy: proxy)
                }
                .onChange(of: value) {
                    scrollToCurrentValue(proxy: proxy)
                }
                .accessibilityIdentifier("Slider.list")
            }
        }

        // MARK: Private helpers

        /// The effective step size: explicit step, or 1/20th of the range.
        private var resolvedStep: Double {
            if let step { return step }
            return (bounds.upperBound - bounds.lowerBound) / 20
        }

        /// All discrete values exposed as list rows.
        private var steps: [Double] {
            let s = resolvedStep
            let count = Int(((bounds.upperBound - bounds.lowerBound) / s).rounded())
            return (0...count).map { i in
                min(bounds.lowerBound + Double(i) * s, bounds.upperBound)
            }
        }

        /// Formats a value for display: integer when whole, otherwise as many
        /// decimal places as needed to distinguish adjacent steps.
        private func formatted(_ v: Double) -> String {
            if v.truncatingRemainder(dividingBy: 1) == 0 {
                return String(Int(v))
            }
            let decimals = max(1, Int(ceil(-log10(resolvedStep))))
            return String(format: "%.\(decimals)f", v)
        }

        /// True when `v` is the closest step to the current binding value.
        private func isSelected(_ v: Double) -> Bool {
            guard let closest = steps.min(by: { abs($0 - value) < abs($1 - value) }) else {
                return false
            }
            return v == closest
        }

        private func scrollToCurrentValue(proxy: ScrollViewProxy) {
            guard let closest = steps.min(by: { abs($0 - value) < abs($1 - value) }) else { return }
            withAnimation { proxy.scrollTo(closest, anchor: .center) }
        }
    }

    // MARK: - Previews

    private struct SliderPreviewContainer: View {
        @State private var continuous = 0.4
        @State private var stepped = 3.0
        @State private var integers = 5.0

        var body: some View {
            HStack(spacing: 40) {
                VStack(alignment: .leading) {
                    Text("Continuous (0…1)")
                        .font(.headline)
                    Text("Value: \(continuous, format: .number.precision(.fractionLength(2)))")
                        .foregroundStyle(.secondary)
                    Slider(value: $continuous, in: 0...1)
                }

                VStack(alignment: .leading) {
                    Text("Stepped (0…10, step 0.5)")
                        .font(.headline)
                    Text("Value: \(stepped, format: .number.precision(.fractionLength(1)))")
                        .foregroundStyle(.secondary)
                    Slider(value: $stepped, in: 0...10, step: 0.5)
                }

                VStack(alignment: .leading) {
                    Text("Integers (1…20)")
                        .font(.headline)
                    Text("Value: \(Int(integers))")
                        .foregroundStyle(.secondary)
                    Slider(value: $integers, in: 1...20, step: 1)
                }
            }
            .padding(60)
        }
    }

    #Preview("Slider — tvOS list") {
        SliderPreviewContainer()
    }
#endif
