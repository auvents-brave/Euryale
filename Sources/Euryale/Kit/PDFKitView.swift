#if os(iOS) || os(macOS)
    public import SwiftUI

    import PDFKit

    // MARK: - PDFKitView

    /// A SwiftUI view that wraps a `PDFView` to display a PDF document with
    /// single-page continuous vertical scrolling and automatic zoom-to-fit.
    ///
    /// Available on iOS, iPadOS and macOS (PDFKit is unavailable on tvOS and
    /// watchOS).
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
            pdfDocument = document
            pdfView.autoScales = true
            pdfView.displayMode = .singlePageContinuous
            pdfView.displayDirection = .vertical
            pdfView.document = pdfDocument
        }

        public var body: some View {
            WrapperView(view: pdfView)
                .ignoresSafeArea()
                .accessibilityIdentifier("PDFKitView.pdfView")
        }
    }

    // MARK: - Previews

    #Preview {
        PDFKitView(url: URL(string: "https://pressbooks.senecapolytechnic.ca/projectmanagementfundamentals/open/download?type=print_pdf")!)
    }
#endif
