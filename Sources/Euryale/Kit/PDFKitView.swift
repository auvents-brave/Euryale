#if os(iOS) || os(macOS) || os(visionOS)
	public import SwiftUI

	import PDFKit

	// MARK: - PDFKitView

	/// A SwiftUI view that wraps a `PDFView` to display a PDF document with
	/// single-page continuous vertical scrolling and automatic zoom-to-fit.
	///
	/// Available on iOS, iPadOS, macOS and visionOS (PDFKit is unavailable on
	/// tvOS and watchOS).
	///
	/// ```swift
	/// if let pdf = PDFKitView(url: someFileURL) {
	///     pdf
	/// } else {
	///     Text("Cannot open PDF")
	/// }
	/// ```
	public struct PDFKitView: View {

		var pdfView = PDFView()
		let pdfDocument: PDFDocument

		/// Creates a `PDFKitView` for the document at `url`.
		///
		/// - Parameter url: A local or remote URL pointing to a PDF document.
		/// - Returns: `nil` when `PDFDocument(url:)` cannot decode the file.
		public init?(url: URL) {
			guard let document = PDFDocument(url: url) else { return nil }
			self.init(document: document)
		}

		/// Creates a `PDFKitView` from raw PDF bytes (e.g. an imported attachment
		/// kept in the data store).
		///
		/// - Parameter data: The PDF document's bytes.
		/// - Returns: `nil` when `PDFDocument(data:)` cannot decode the bytes.
		public init?(data: Data) {
			guard let document = PDFDocument(data: data) else { return nil }
			self.init(document: document)
		}

		private init(document: PDFDocument) {
			pdfDocument = document
			pdfView.autoScales = true
			pdfView.displayMode = .singlePageContinuous
			pdfView.displayDirection = .vertical
			pdfView.document = pdfDocument
		}

		/// The content and behaviour of the view.
		public var body: some View {
			WrapperView(view: pdfView)
				.ignoresSafeArea()
				.accessibilityIdentifier("PDFKitView.pdfView")
		}
	}

	// MARK: - Previews

	#Preview {
		PDFKitView(
			url: URL(
				string:
					"https://pressbooks.senecapolytechnic.ca/projectmanagementfundamentals/open/download?type=print_pdf"
			)!)
	}
#endif
