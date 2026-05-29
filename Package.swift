// swift-tools-version: 6.1

import PackageDescription
import Foundation

var swiftSettings: [SwiftSetting] = [
	.enableUpcomingFeature("InternalImportsByDefault"),
	.enableUpcomingFeature("ExistentialAny"),
]
if ProcessInfo.processInfo.environment["RUNNER"] == "VSCode" {
	swiftSettings.append(.define("VSCode"))
} else if ProcessInfo.processInfo.environment["XCODE_VERSION_ACTUAL"] != nil {
	swiftSettings.append(.define("Xcode"))
}

#if canImport(XcodeProject)
let isXcode = true
#else
let isXcode = false
#endif

var prods: [Product] = [
    .library(
        name: "Euryale",
        targets: ["Euryale"]
    ),
]

var deps: [Package.Dependency] = [
	.package(
		// Upper bound excludes 1.13.0+ : that release ships a Logger
		// `prepareMetadata` that fails Swift 6.3 strict type-checking
		// ("Cannot assign value of type 'String' to subscript of type
		// 'Logger.MetadataValue'").  Re-evaluate when upstream releases a
		// fixed 1.13.x patch.
		url: "https://github.com/apple/swift-log",
		"1.6.0"..<"1.13.0"
	),
	.package(
		// Upper bound excludes 1.19.0+ : those releases ship a Swift
		// Testing attachment path that calls `Attachment.record(image, …)`
		// where `image` is a `UIImage`/`NSImage`, which does not conform to
		// `AttachableAsImage` under Swift 6.3.  Compilation fails with
		// "Static method 'record(_:named:as:sourceLocation:)' requires that
		// 'UIImage' conform to 'AttachableAsImage'".  Re-evaluate once a
		// fixed 1.19.x or 1.20.x is released upstream.
		url: "https://github.com/pointfreeco/swift-snapshot-testing",
		"1.18.0"..<"1.19.0"
	),
	.package(
		url: "https://github.com/nalexn/ViewInspector",
		from: "0.10.0"
	),
]

let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let localSthenoPath = packageDirectory
	.deletingLastPathComponent()
	.appendingPathComponent("Stheno")
	.path
if FileManager.default.fileExists(atPath: localSthenoPath) {
	// Local development: use the sibling working copy of Stheno.
	deps.append(.package(path: localSthenoPath))
} else {
	// CI / fresh clone: resolve from GitHub.
	deps.append(
		.package(
			url: "https://github.com/auvents-brave/Stheno",
			branch: "main",
		)
	)
}

var targs: [Target] = [
  .target(
	name: "Euryale",
	dependencies: [
		.product(name: "Logging", package: "swift-log"),
		.product(name: "Stheno", package: "stheno"),
	],
	path: "Sources/Euryale",
	resources: [
		.process("Resources")
	],
	swiftSettings: swiftSettings
  ),
]

targs.append(
  .testTarget(
    name: "EuryaleTests",
	dependencies: [
		"Euryale",
		.product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
		.product(name: "ViewInspector",   package: "ViewInspector"),
	],
    resources: [.process("Resources")],
    swiftSettings: swiftSettings
  )
)

let package = Package(
    name: "Euryale",
	defaultLocalization: "en",
    platforms: [
        .macOS(.v13),
        .macCatalyst(.v17),
        .iOS(.v17),
        .tvOS(.v17),
		.watchOS(.v11),
        .visionOS(.v1),
    ],

    products: prods,

    dependencies: deps,

    targets: targs,
    
    swiftLanguageModes: [ .v6 ],
)
