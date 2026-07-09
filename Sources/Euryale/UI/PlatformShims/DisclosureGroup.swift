#if os(tvOS) || os(watchOS)
	public import SwiftUI

	// MARK: - DisclosureGroup

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

		/// Creates a disclosure group.
		/// - Parameters:
		///   - isExpanded: Binding driving whether the content is revealed.
		///   - content: The content shown when expanded.
		///   - label: The always-visible label that toggles expansion.
		public init(
			isExpanded: Binding<Bool>,
			@ContentBuilder content: @escaping () -> Content,
			@ContentBuilder label: @escaping () -> Label
		) {
			_isExpanded = isExpanded
			self.content = content
			self.label = label
		}

		/// The content and behaviour of the view.
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

	// MARK: - Previews

	#if DEBUG
		private struct DisclosureGroupPreview: View {
			@State private var expanded = true

			var body: some View {
				DisclosureGroup(isExpanded: $expanded) {
					VStack(alignment: .leading) {
						Text(verbatim: "First item")
						Text(verbatim: "Second item")
					}
				} label: {
					Text(verbatim: "Section")
				}
				.padding()
			}
		}

		#Preview("DisclosureGroup (tvOS / watchOS shim)") {
			DisclosureGroupPreview()
		}
	#endif
#endif
