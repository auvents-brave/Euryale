public import CoreGraphics  // CGImage used in public function return type
public import Foundation
import ImageIO

// MARK: - Image classification

#if !os(watchOS)
    import Vision

    /// Classifies the image at `url` using the Vision framework and returns
    /// the recognised labels with their confidence scores.
    ///
    /// On macOS 15 / iOS 18 / tvOS 18 / visionOS 2 and later this uses the
    /// modern Swift-concurrency `ClassifyImageRequest` API.  Older platforms
    /// fall back to the legacy `VNClassifyImageRequest` against a `CGImage`
    /// loaded via ``loadCGImage(from:)``.
    ///
    /// Results are filtered with `hasMinimumPrecision(0.1, forRecall: 0.8)` on
    /// the modern path — a high-recall preset that keeps most plausible
    /// matches while excluding the very weakest.
    ///
    /// - Parameter url: A local file URL or remote URL pointing to an image.
    /// - Returns: A dictionary keyed by classification identifier (e.g.
    ///   `"animal"`, `"sunset"`) with `0.0 ... 1.0` confidence values.
    /// - Throws: A Vision framework error if classification fails, or
    ///   ``ImageLoadingError`` on the legacy path if the image cannot be
    ///   decoded.
    public func classifyImage(url: URL) async throws -> [String: Double] {
        if #available(macOS 15, iOS 18, tvOS 18, visionOS 2, *) {
            // Use the modern Vision concurrency API when available.
            let request = ClassifyImageRequest()
            let results = try await request.perform(on: url)
                // Use `hasMinimumPrecision` for a high-recall filter.
                .filter { $0.hasMinimumPrecision(0.1, forRecall: 0.8) }
            // Alternatively, for high-precision filter:
            // .filter { $0.hasMinimumRecall(0.01, forPrecision: 0.9) }

            var observations: [String: Double] = [:]
            for classification in results {
                observations[classification.identifier] = Double(classification.confidence)
            }
            return observations
        } else {
            // Fallback using VNClassifyImageRequest and a CGImage loaded from the URL.
            let cgImage = try await loadCGImage(from: url)
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            guard let results = request.results else {
                return [:]
            }

            var observations: [String: Double] = [:]
            for classification in results {
                observations[classification.identifier] = Double(classification.confidence)
            }
            return observations
        }
    }
#endif

// MARK: - ImageLoadingError

/// Errors that can occur while loading an image from a URL.
public enum ImageLoadingError: Error {
    case cannotCreateImageSource
    case cannotCreateCGImage
}

// MARK: - Image loading

/// Loads a CGImage from a URL. Supports both local file URLs and remote (e.g., https) URLs.
/// - Parameter url: The URL of the image. Can be a file URL or a remote URL.
/// - Returns: A `CGImage` created from the contents at the URL.
/// - Throws: `ImageLoadingError` if the image cannot be decoded, or network errors for remote URLs.
public func loadCGImage(from url: URL) async throws -> CGImage {
    if url.isFileURL {
        // Load from disk using ImageIO for efficient decoding.
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageLoadingError.cannotCreateImageSource
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageLoadingError.cannotCreateCGImage
        }
        return image
    } else {
        // Load from network using URLSession, then decode with ImageIO.
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageLoadingError.cannotCreateImageSource
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageLoadingError.cannotCreateCGImage
        }
        return image
    }
}
