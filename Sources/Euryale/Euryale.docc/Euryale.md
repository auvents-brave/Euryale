# ``Euryale``

@Metadata {
	@TitleHeading("Library")
	@PageColor(purple)
	@Available(macOS, introduced: "13")
	@Available(iOS, introduced: "17.0")
	@Available(tvOS, introduced: "17.0")
	@Available(watchOS, introduced: "11.0")
	@Available(visionOS, introduced: "1.0")
	@Available(macCatalyst, introduced: "17.0")
	@SupportedLanguage(swift)
	@CallToAction(
				  purpose: link,
				  url: "https://github.com/auvents-brave/Euryale")
}

Robust, reusable components for cross-platform Swift development.

## Overview

Euryale collects higher-level helpers built on top of MapKit, MetalKit,
PDFKit, WebKit, TextKit, Core Location and Vision.  It complements
[Sthenô](https://github.com/auvents-brave/Stheno) (pure-Swift cross-platform
building blocks) with Apple-platform-specific views, view modifiers and
extensions.

### Articles

- <doc:DisplayAppVersion>

## Topics

### Maps and cached tile overlays

- ``MapKitView``
- ``PopupMapView``

### Web content

- ``WebKitView``
- ``PopupWebView``

### Text and PDF

- ``TextKitView``
- ``HtmlView``
- ``PDFKitView``

### Metal rendering

- ``MetalKitView``

### Reusable UI components

- ``Pill``
- ``PillsView``
- ``PaginatedPill``
- ``StatusPill``
- ``BouncingView``
- ``Slider``
- ``PopupPresenter``
- ``SwiftUICore/View/PreferredAvailableButtonStyle()``

### Core Location

- ``CoreLocation/CLLocation/Name()``
- ``CoreLocation/CLLocation/AtSea()``

### Image classification

- ``classifyImage(url:)``
- ``loadCGImage(from:)``
- ``ImageLoadingError``

### Bundle helpers

- ``Foundation/Bundle/displayName``
- ``Foundation/Bundle/synchronizeDisplayedVersion(key:in:)``

### iCloud sync

- ``UserDefaultsCloudSync``

### Cross-platform aliases

- ``OSApplication``
- ``OSView``
- ``OSColor``
- ``OSImage``
- ``OSFont``
