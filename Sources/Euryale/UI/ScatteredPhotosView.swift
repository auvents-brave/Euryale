import Foundation
public import SwiftUI

// MARK: - ScatteredPhotosView

/// Lays a list of images out as if they were physical prints dropped on the
/// floor: each one gets a small white paper border, a soft drop shadow, a
/// random rotation and position, and a gentle curl — and, lucky us, they all
/// landed face up.
///
/// The scatter is deterministic for a given ``seed``, so the layout is stable
/// across redraws (it does not reshuffle every time the view updates).
///
/// App-neutral: it draws no background of its own, so the caller decides what
/// the "floor" looks like (a colour, a material, a texture…).
///
/// ```swift
/// ScatteredPhotosView(images: prints)
///     .background(Color(white: 0.16))
///     .frame(height: 480)
/// ```
public struct ScatteredPhotosView: View {
  private let images: [PlatformImage]
  private let seed: UInt64
  private let maxAngle: Double
  private let spread: CGFloat
  private let borderWidth: CGFloat
  private let curl: Double

  /// Creates a scattered-photos view.
  ///
  /// - Parameters:
  ///   - images: The prints to scatter, drawn back-to-front in array order.
  ///   - seed: Seeds the deterministic scatter; change it to reshuffle.
  ///   - maxAngle: Maximum rotation, in degrees, either side of upright.
  ///   - spread: How far the prints stray from the centre, `0` (a neat pile)
  ///     to `1` (flung to the edges).
  ///   - borderWidth: Width of the white paper border around each print.
  ///   - curl: Strength of the paper curl and sheen, `0` (flat) to `1`.
  public init(
    images: [PlatformImage],
    seed: UInt64 = 7,
    maxAngle: Double = 16,
    spread: CGFloat = 0.55,
    borderWidth: CGFloat = 10,
    curl: Double = 0.6
  ) {
    self.images = images
    self.seed = seed
    self.maxAngle = maxAngle
    self.spread = spread
    self.borderWidth = borderWidth
    self.curl = curl
  }

  public var body: some View {
    GeometryReader { proxy in
      let minSide = min(proxy.size.width, proxy.size.height)
      ZStack {
        ForEach(Array(images.enumerated()), id: \.offset) { index, image in
          let layout = Self.layout(index: index, seed: seed, maxAngle: maxAngle)
          PhotoCard(
            image: image,
            longestSide: minSide * layout.scale,
            borderWidth: borderWidth,
            curl: curl,
            curlAxis: layout.curlAxis
          )
          .rotation3DEffect(.degrees(curl * layout.tilt), axis: layout.curlAxis, perspective: 0.65)
          .rotationEffect(.degrees(layout.angle))
          .offset(
            x: layout.offset.x * proxy.size.width * spread * 0.5,
            y: layout.offset.y * proxy.size.height * spread * 0.5
          )
          .zIndex(Double(index))
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
  }

  // MARK: Deterministic scatter

  private struct Layout {
    var angle: Double
    var offset: CGPoint
    var scale: CGFloat
    var tilt: Double
    var curlAxis: (x: CGFloat, y: CGFloat, z: CGFloat)
  }

  private static func layout(index: Int, seed: UInt64, maxAngle: Double) -> Layout {
    var rng = SeededGenerator(seed &+ UInt64(bitPattern: Int64(index)) &* 0x100_0000_01B3)
    let angle = Double.random(in: -maxAngle...maxAngle, using: &rng)
    let offset = CGPoint(
      x: CGFloat.random(in: -1...1, using: &rng),
      y: CGFloat.random(in: -1...1, using: &rng)
    )
    let scale = CGFloat.random(in: 0.42...0.56, using: &rng)
    let tilt = Double.random(in: 12...20, using: &rng)
    // Curl mostly bows away along the horizontal axis, with a little lean.
    let axis = (x: CGFloat(1), y: CGFloat.random(in: -0.4...0.4, using: &rng), z: CGFloat(0))
    return Layout(angle: angle, offset: offset, scale: scale, tilt: tilt, curlAxis: axis)
  }
}

// MARK: - PhotoCard

/// A single print: the image filling a paper card with a white border, a curl
/// sheen and a drop shadow.
private struct PhotoCard: View {
  let image: PlatformImage
  let longestSide: CGFloat
  let borderWidth: CGFloat
  let curl: Double
  let curlAxis: (x: CGFloat, y: CGFloat, z: CGFloat)

  private var size: CGSize {
    let aspect = max(0.4, min(2.5, image.size.width / max(1, image.size.height)))
    return aspect >= 1
      ? CGSize(width: longestSide, height: longestSide / aspect)
      : CGSize(width: longestSide * aspect, height: longestSide)
  }

  var body: some View {
    photoImage
      .resizable()
      .scaledToFill()
      .frame(width: size.width, height: size.height)
      .clipped()
      .overlay(curlShading)
      .padding(borderWidth)
      .background(Color.white)
      .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
      .shadow(color: .black.opacity(0.35), radius: 9, x: 4, y: 7)
  }

  /// Shading that reads as a gently curled print: a cylindrical bow across the
  /// width, a soft top sheen, and a bottom edge that lifts — a self-shadow band
  /// topped by a brighter curling lip.
  private var curlShading: some View {
    ZStack {
      LinearGradient(
        colors: [
          .black.opacity(0.22 * curl), .clear,
          .white.opacity(0.10 * curl), .clear,
          .black.opacity(0.22 * curl),
        ],
        startPoint: .leading, endPoint: .trailing
      )
      LinearGradient(
        colors: [.white.opacity(0.22 * curl), .clear], startPoint: .top, endPoint: .center)
      VStack(spacing: 0) {
        Spacer()
        LinearGradient(
          colors: [.clear, .black.opacity(0.30 * curl)], startPoint: .top, endPoint: .bottom
        )
        .frame(height: size.height * 0.20)
        LinearGradient(
          colors: [.white.opacity(0.65 * curl), .white.opacity(0.05 * curl)], startPoint: .bottom,
          endPoint: .top
        )
        .frame(height: size.height * 0.05)
      }
    }
    .allowsHitTesting(false)
  }

  private var photoImage: Image {
    #if canImport(UIKit)
      Image(uiImage: image)
    #elseif canImport(AppKit)
      Image(nsImage: image)
    #else
      Image(systemName: "photo")
    #endif
  }
}

// MARK: - Deterministic RNG

/// A tiny SplitMix64 generator so the scatter is reproducible for a given seed.
private struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(_ seed: UInt64) {
    state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
  }

  mutating func next() -> UInt64 {
    state = state &+ 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

// MARK: - Previews

#if DEBUG
  /// Sample prints for the previews, fetched from the web (Lorem Picsum,
  /// deterministic per seed) with a coloured fallback so the canvas still shows
  /// something when offline.
  @MainActor
  private enum ScatteredPhotosPreviewData {
    static let photos: [PlatformImage] = specs.map { spec in
      let url = URL(string: "https://picsum.photos/seed/\(spec.seed)/\(spec.w)/\(spec.h)")!
      if let data = try? Data(contentsOf: url), let image = PlatformImage(data: data) {
        return image
      }
      return placeholder(width: spec.w, height: spec.h, seed: spec.seed)
    }

    private static let specs: [(seed: Int, w: Int, h: Int)] = [
      (11, 400, 300), (24, 300, 400), (37, 420, 300),
      (48, 300, 380), (52, 360, 360), (63, 400, 280),
    ]

    private static func placeholder(width: Int, height: Int, seed: Int) -> PlatformImage {
      let space = CGColorSpaceCreateDeviceRGB()
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )!
      let top = CGColor(srgbRed: Double(seed * 37 % 256) / 255, green: 0.55, blue: 0.7, alpha: 1)
      let bottom = CGColor(srgbRed: 0.2, green: Double(seed * 53 % 256) / 255, blue: 0.5, alpha: 1)
      let gradient = CGGradient(
        colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!
      context.drawLinearGradient(
        gradient, start: CGPoint(x: 0, y: height), end: .zero, options: []
      )
      let cgImage = context.makeImage()!
      #if canImport(UIKit)
        return PlatformImage(cgImage: cgImage)
      #else
        return PlatformImage(cgImage: cgImage, size: NSSize(width: width, height: height))
      #endif
    }
  }

  #Preview("Default scatter") {
    ScatteredPhotosView(images: ScatteredPhotosPreviewData.photos)
      .padding(40)
      .frame(width: 700, height: 520)
      .background(Color(white: 0.16))
  }

  #Preview("Flung wide, strong curl") {
    ScatteredPhotosView(
      images: ScatteredPhotosPreviewData.photos,
      seed: 23, maxAngle: 24, spread: 0.85, curl: 0.85
    )
    .padding(40)
    .frame(width: 780, height: 560)
    .background(Color(red: 0.42, green: 0.30, blue: 0.20))
  }

  #Preview("Neat pile, almost flat") {
    ScatteredPhotosView(
      images: ScatteredPhotosPreviewData.photos,
      seed: 5, maxAngle: 6, spread: 0.18, borderWidth: 14, curl: 0.15
    )
    .padding(40)
    .frame(width: 620, height: 480)
    .background(Color(white: 0.9))
  }

  #Preview("Thick border, light floor") {
    ScatteredPhotosView(
      images: ScatteredPhotosPreviewData.photos,
      seed: 99, maxAngle: 14, spread: 0.5, borderWidth: 18, curl: 0.55
    )
    .padding(40)
    .frame(width: 700, height: 520)
    .background(
      LinearGradient(
        colors: [Color(white: 0.82), Color(white: 0.66)], startPoint: .top, endPoint: .bottom)
    )
  }
#endif
