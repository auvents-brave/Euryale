# Euryale

> In Greek mythology, **Euryale** (Εὐρυάλη) is one of the three Gorgon sisters—alongside **Sthenô** and **Medusa**. Often depicted as immortal like Sthenô (with Medusa the mortal sister), Euryale is associated with a powerful, piercing cry and formidable resilience. This name reflects the library's emphasis on composability, strength, and clarity across platforms.

Euryale is a small Swift package collecting higher-level helpers built on top of MapKit, MetalKit, PDFKit, WebKit, TextKit, Core Location and Vision. It complements [Sthenô](https://github.com/auvents-brave/Stheno) (pure-Swift cross-platform building blocks) with Apple-platform-specific views, view modifiers and extensions, designed to be adopted piecemeal across apps.

Euryale depends on [Sthenô](https://github.com/auvents-brave/Stheno) for cross-platform foundations and on [swift-log](https://github.com/apple/swift-log) for structured logging, keeping the overall dependency footprint minimal.

Continuous Integration (CI) is handled through GitHub Actions, which automatically builds, tests, generates documentation, and analyses the codebase using CodeQL and SonarQube to ensure quality, consistency, and cross-platform reliability.

> **A note on UI tests.** Tests covering the public SwiftUI views don't just instantiate the views — they verify that each view is built correctly by asserting on its `accessibilityIdentifier` via [**ViewInspector**](https://github.com/nalexn/ViewInspector) (by [Alex Nikishin](https://github.com/nalexn), MIT), and for selected views the rendered output is pinned via image snapshots with [**swift-snapshot-testing**](https://github.com/pointfreeco/swift-snapshot-testing) (by [Brandon Williams](https://github.com/mbrandonw) and [Stephen Celis](https://github.com/stephencelis) at [Point-Free](https://www.pointfree.co), MIT). Both are **test-only dependencies** and do not ship in the binary consumers link against.

![Swift](https://img.shields.io/badge/Swift-6.1+-orange?logo=swift)

[![CodeQL](https://github.com/auvents-brave/Euryale/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Euryale/actions/workflows/codeql.yml) [![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=auvents-brave_Euryale&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=auvents-brave_Euryale) [![Coverage](https://sonarcloud.io/api/project_badges/measure?project=auvents-brave_Euryale&metric=coverage)](https://sonarcloud.io/summary/new_code?id=auvents-brave_Euryale)

[![DocC](https://img.shields.io/badge/DocC-available-brightgreen)](https://auvents-brave.github.io/Euryale/)

Documentation is available directly in Xcode and VS Code, and [online](https://auvents-brave.github.io/Euryale/).

## Platforms and CI

| Platform | CI Status |
|---|---|
| ![macOS](https://img.shields.io/badge/macOS-111111?logo=apple&logoColor=white) ![min OS 13.0+](https://img.shields.io/badge/min%20OS-13.0%2B-444444) | [![macOS](https://github.com/auvents-brave/Euryale/actions/workflows/apple-macos.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Euryale/actions/workflows/apple-macos.yml) |
| ![Mac Catalyst](https://img.shields.io/badge/Mac_Catalyst-111111?logo=apple&logoColor=white) ![min OS 17.0+](https://img.shields.io/badge/min%20OS-17.0%2B-444444) | [![Mac Catalyst](https://github.com/auvents-brave/Euryale/actions/workflows/apple-maccatalyst.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Euryale/actions/workflows/apple-maccatalyst.yml) |
| ![iOS](https://img.shields.io/badge/iOS-111111?logo=apple&logoColor=white) ![min OS 17.0+](https://img.shields.io/badge/min%20OS-17.0%2B-444444) | [![iOS](https://github.com/auvents-brave/Euryale/actions/workflows/apple-ios.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Euryale/actions/workflows/apple-ios.yml) |
| ![iPadOS](https://img.shields.io/badge/iPadOS-111111?logo=apple&logoColor=white) ![min OS 17.0+](https://img.shields.io/badge/min%20OS-17.0%2B-444444) | [![iPadOS](https://github.com/auvents-brave/Euryale/actions/workflows/apple-ipados.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Euryale/actions/workflows/apple-ipados.yml) |
| ![tvOS](https://img.shields.io/badge/tvOS-111111?logo=apple&logoColor=white) ![min OS 17.0+](https://img.shields.io/badge/min%20OS-17.0%2B-444444) | [![tvOS](https://github.com/auvents-brave/Euryale/actions/workflows/apple-tvos.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Euryale/actions/workflows/apple-tvos.yml) |
| ![watchOS](https://img.shields.io/badge/watchOS-111111?logo=apple&logoColor=white) ![min OS 11.0+](https://img.shields.io/badge/min%20OS-11.0%2B-444444) | [![watchOS](https://github.com/auvents-brave/Euryale/actions/workflows/apple-watchos.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Euryale/actions/workflows/apple-watchos.yml) |
| ![visionOS](https://img.shields.io/badge/visionOS-111111?logo=apple&logoColor=white) ![min OS 1.0+](https://img.shields.io/badge/min%20OS-1.0%2B-444444) | [![visionOS](https://github.com/auvents-brave/Euryale/actions/workflows/apple-visionos.yml/badge.svg?branch=main)](https://github.com/auvents-brave/Euryale/actions/workflows/apple-visionos.yml) |

## Public API

### Maps and cached tile overlays

A SwiftUI-friendly `MKMapView` wrapper plus a popup variant that pairs an embedded map with an "Open in Maps" button. Both accept any number of cached XYZ/TMS raster tile overlays — OpenStreetMap, OpenTopoMap, OpenSeaMap, IGN France, Cassini, NOAA, etc. — stacked on top of the Apple Maps base layer.

- [`MapKitView`](https://auvents-brave.github.io/Euryale/documentation/euryale/mapkitview/) — Cross-platform `MKMapView` SwiftUI wrapper with on-disk-cached XYZ/TMS tile overlays (configurable cache age and optional App Group container for cross-app sharing).
- [`PopupMapView`](https://auvents-brave.github.io/Euryale/documentation/euryale/popupmapview/) — Pre-built popover that embeds a `MapKitView` and an "Open in Maps" escape hatch. Adapts gracefully to watchOS (direct Maps launch) and tvOS (no Open-in-Maps button).

### Web content

- [`WebKitView`](https://auvents-brave.github.io/Euryale/documentation/euryale/webkitview/) — SwiftUI wrapper around `WKWebView`. On tvOS and watchOS a stub view is provided instead.
- [`PopupWebView`](https://auvents-brave.github.io/Euryale/documentation/euryale/popupwebview/) — Popover with an embedded `WebKitView` and an "Open in Browser" escape via the SwiftUI `openURL` action.

### Text and PDF

- [`TextKitView`](https://auvents-brave.github.io/Euryale/documentation/euryale/textkitview/) — Native rich-text view wrapped for SwiftUI: `UITextView` on iOS/iPadOS/tvOS/Catalyst/visionOS, `NSTextView` (inside an `NSScrollView`) on macOS. `setHTML(_:)` renders an attributed HTML document; data detectors and link detection are enabled by default. Use for **long HTML documents** that need scrolling, text selection and tappable links.
- [`HtmlView`](https://auvents-brave.github.io/Euryale/documentation/euryale/htmlview/) — Lightweight cross-platform HTML-to-`Text` renderer for **short inline HTML fragments** embedded in SwiftUI layouts (lists, cells, stacks). Pure SwiftUI, dark-mode and Dynamic Type aware. Fast path when the string contains no HTML tags.
- [`PDFKitView`](https://auvents-brave.github.io/Euryale/documentation/euryale/pdfkitview/) — `PDFView` wrapped for SwiftUI with auto-scaling and single-page continuous vertical scrolling (iOS / iPadOS / macOS).

### Metal rendering

- [`MetalKitView`](https://auvents-brave.github.io/Euryale/documentation/euryale/metalkitview/) — `MTKView` wrapped for SwiftUI. Pass a Metal shader source string and pick a built-in renderer (`generic` / `mountains`) from [`RendererKind`](https://auvents-brave.github.io/Euryale/documentation/euryale/metalkitview/rendererkind/).

### Reusable UI components

- [`Pill`](https://auvents-brave.github.io/Euryale/documentation/euryale/pill/) and [`PillsView`](https://auvents-brave.github.io/Euryale/documentation/euryale/pillsview/) — Compact label-and-value badges with an adaptive horizontal/vertical layout container.
- [`PaginatedPill`](https://auvents-brave.github.io/Euryale/documentation/euryale/paginatedpill/) — Generic paginated pill container that shows one page of arbitrary content at a time, with tap-to-jump indicator dots and horizontal swipe-to-navigate. Configurable layout: `.overlay` (default — content full-bleed, dots floating, e.g. bottom-trailing) or `.stacked` (dots below content). Indicators use the SwiftUI environment tint (override via `accentColor:`) on legacy systems; on OS 26+ they pick up the Liquid Glass material with no colour tint at all (active/inactive distinguished by size + outline opacity).
- [`StatusPill`](https://auvents-brave.github.io/Euryale/documentation/euryale/statuspill/) — Status badge pairing an SF Symbol with a short label, tinted by semantic status: [`.ok`](https://auvents-brave.github.io/Euryale/documentation/euryale/statuspill/status-swift.enum/ok) (green check), [`.warning`](https://auvents-brave.github.io/Euryale/documentation/euryale/statuspill/status-swift.enum/warning) (yellow triangle), [`.error`](https://auvents-brave.github.io/Euryale/documentation/euryale/statuspill/status-swift.enum/error) (red cross).
- [`BouncingView`](https://auvents-brave.github.io/Euryale/documentation/euryale/bouncingview/) — Tap-to-bounce micro-animation modifier, especially useful on tvOS where focus controls need extra feedback.
- [`Slider`](https://auvents-brave.github.io/Euryale/documentation/euryale/slider/) — List-based replacement for `SwiftUI.Slider` on tvOS (where it is unavailable), with the same public API.
- [`PopupPresenter`](https://auvents-brave.github.io/Euryale/documentation/euryale/popuppresenter/) — Generic popover / sheet driver used by `PopupMapView` and `PopupWebView`. Use it to build your own inline expandable UI.
- [`PreferredAvailableButtonStyle()`](https://auvents-brave.github.io/Euryale/documentation/euryale/swiftuicore/view/preferredavailablebuttonstyle()) — `View` modifier that picks the most modern button style available on the running OS (Liquid Glass on OS 26 +, bordered-prominent before).

### Core Location

- [`CLLocation.Name()`](https://auvents-brave.github.io/Euryale/documentation/euryale/corelocation/cllocation/name()) — Async reverse geocoding helper that returns a single human-readable name. Uses the modern `PlaceDescriptor` API on OS 26 + and falls back to `CLPlacemark` on older systems.
- [`CLLocation.AtSea()`](https://auvents-brave.github.io/Euryale/documentation/euryale/corelocation/cllocation/atsea()) — Async predicate that returns `true` when a coordinate is over an ocean / sea / large body of water.

### Image classification

- [`classifyImage(url:)`](https://auvents-brave.github.io/Euryale/documentation/euryale/classifyimage(url:)) — Async Vision-based classification that returns `[String: Double]` keyed by label identifier with their confidence scores.
- [`loadCGImage(from:)`](https://auvents-brave.github.io/Euryale/documentation/euryale/loadcgimage(from:)) — Async loader that decodes a local or remote URL into a `CGImage` via ImageIO.
- [`ImageLoadingError`](https://auvents-brave.github.io/Euryale/documentation/euryale/imageloadingerror/) — Error type for image-loading failures.

### Bundle helpers

- [`Bundle.displayName`](https://auvents-brave.github.io/Euryale/documentation/euryale/foundation/bundle/displayname) — User-visible application name with localised lookup (`CFBundleDisplayName` → `CFBundleName` → `ProcessInfo.processName`).
- [`Bundle.synchronizeDisplayedVersion(key:in:)`](https://auvents-brave.github.io/Euryale/documentation/euryale/foundation/bundle/synchronizedisplayedversion(key:in:)) — Writes the app's `displayedVersion` into `UserDefaults` so an iOS `Settings.bundle` entry can render it. See <doc:DisplayAppVersion>.

### iCloud sync

- [`UserDefaultsCloudSync`](https://auvents-brave.github.io/Euryale/documentation/euryale/userdefaultscloudsync/) — Mirrors `UserDefaults` with `NSUbiquitousKeyValueStore` (optionally filtered by key prefix) so settings flow between a user's devices via iCloud.

### Cross-platform aliases

- [`OSApplication`](https://auvents-brave.github.io/Euryale/documentation/euryale/osapplication), [`OSView`](https://auvents-brave.github.io/Euryale/documentation/euryale/osview), [`OSColor`](https://auvents-brave.github.io/Euryale/documentation/euryale/oscolor), [`OSImage`](https://auvents-brave.github.io/Euryale/documentation/euryale/osimage), [`OSFont`](https://auvents-brave.github.io/Euryale/documentation/euryale/osfont) — `WKExtension` / `UIApplication` / `NSApplication` family of native typealiases, plus `OSApplication.osShared` to get the shared instance, so shared code can avoid `#if` blocks at every reference site.
