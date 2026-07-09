#if os(tvOS)
	public import SwiftUI

	/// A tvOS replacement for SwiftUI's `Slider`.
	///
	/// On tvOS the standard `Slider` is unavailable.  This shim behaves like a
	/// real slider: a focusable track (a `ProgressView` flanked by chevrons) that
	/// the user nudges left/right with the Siri Remote.  It shows no numeric
	/// labels, so callers remain free to present the value however they like.
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

		@FocusState private var isFocused: Bool

		// MARK: Initialisers (same signatures as SwiftUI.Slider)

		/// Creates a continuous slider over `0...1`.
		public init(
			value: Binding<Double>,
			onEditingChanged: @escaping (Bool) -> Void = { _ in }
		) {
			self.init(value: value, in: 0...1, onEditingChanged: onEditingChanged)
		}

		/// Creates a continuous slider over the given bounds.
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

		/// Creates a stepped slider over `0...1`.
		public init(
			value: Binding<Double>,
			step: Double,
			onEditingChanged: @escaping (Bool) -> Void = { _ in }
		) {
			self.init(value: value, in: 0...1, step: step, onEditingChanged: onEditingChanged)
		}

		/// Creates a stepped slider over the given bounds.
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

		/// The content and behaviour of the view.
		public var body: some View {
			HStack(spacing: 20) {
				Image(systemName: "chevron.left")
				ProgressView(
					value: value - bounds.lowerBound,
					total: bounds.upperBound - bounds.lowerBound
				)
				Image(systemName: "chevron.right")
			}
			.foregroundStyle(isFocused ? Color.primary : Color.secondary)
			.padding(.vertical, 8)
			.padding(.horizontal, 16)
			.background(
				RoundedRectangle(cornerRadius: 12, style: .continuous)
					.fill(isFocused ? AnyShapeStyle(.white.opacity(0.15)) : AnyShapeStyle(Color.clear))
			)
			.focusable()
			.focused($isFocused)
			.animation(.easeInOut(duration: 0.12), value: isFocused)
			.onMoveCommand { direction in
				switch direction {
				case .left: adjust(by: -resolvedStep)
				case .right: adjust(by: resolvedStep)
				default: break
				}
			}
			.accessibilityElement()
			.accessibilityValue(Text(value, format: .number))
			.accessibilityAdjustableAction { action in
				switch action {
				case .increment: adjust(by: resolvedStep)
				case .decrement: adjust(by: -resolvedStep)
				@unknown default: break
				}
			}
			.accessibilityIdentifier("Slider.track")
		}

		// MARK: Private helpers

		/// The effective step size: explicit step, or 1/20th of the range.
		private var resolvedStep: Double {
			if let step { return step }
			return (bounds.upperBound - bounds.lowerBound) / 20
		}

		/// Moves the value by `delta`, clamped to the bounds, notifying via
		/// `onEditingChanged` around the change.
		private func adjust(by delta: Double) {
			let newValue = min(bounds.upperBound, max(bounds.lowerBound, value + delta))
			guard newValue != value else { return }
			onEditingChanged(true)
			value = newValue
			onEditingChanged(false)
		}
	}

	// MARK: - Previews

	private struct SliderPreviewContainer: View {
		@State private var continuous = 0.4
		@State private var stepped = 3.0
		@State private var integers = 5.0

		var body: some View {
			VStack(alignment: .leading, spacing: 40) {
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

	#Preview("Slider — tvOS track") {
		SliderPreviewContainer()
	}
#endif
