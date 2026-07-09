#if compiler(<6.4)
	public import SwiftUI

	/// Xcode 27's SwiftUI aliases `ContentBuilder` to `ViewBuilder` — the new
	/// spelling type-checks substantially faster there. Older toolchains (the
	/// CI runners' Xcode) lack the alias; this one keeps the package building
	/// on both, and compiles away under Swift 6.4+ where the real alias exists.
	public typealias ContentBuilder = SwiftUI.ViewBuilder
#endif
