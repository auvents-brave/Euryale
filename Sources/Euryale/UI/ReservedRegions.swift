public import SwiftUI

// Only the iOS SDK (27.1) declares the reserved-region API; the tvOS,
// visionOS and macCatalyst SDKs are still at 27.0 and do not compile against
// it. None of those runs on a folding screen, so they take the no-op below
// until their SDKs catch up.
#if os(iOS) && !targetEnvironment(macCatalyst)
	import UIKit
#endif

// MARK: - ReservedRegionLayout

/// Where floating content may sit once the regions the system reserves are
/// taken out of the usable area — on a folding iPhone the hinge, elsewhere a
/// camera housing.
///
/// Pure geometry, kept apart from the UIKit query so the rule can be exercised
/// on any platform, including those that have no reserved regions at all.
public enum ReservedRegionLayout {

	/// The smallest translation that moves `content` clear of every region.
	///
	/// Each region offers four ways out — past one of its edges — and the
	/// nearest one that clears *all* of them without leaving `container` wins,
	/// so a capsule between two bands slides past both rather than from one
	/// into the other. Content that cannot clear them at all stays where the
	/// layout put it: a cramped position beats one off the screen.
	///
	/// - Parameters:
	///   - content: The content's frame, before any avoidance.
	///   - regions: The reserved rectangles, margins included.
	///   - container: The area the content must stay inside, usually the window.
	/// - Returns: The translation to apply, zero when nothing is in the way.
	public static func offset(
		for content: CGRect,
		clearing regions: [CGRect],
		within container: CGRect
	) -> CGSize {
		guard regions.contains(where: { $0.intersects(content) }) else { return .zero }
		let room = container.insetBy(dx: -0.5, dy: -0.5) // rounding tolerance
		return
			regions
			.flatMap { escapes(from: $0, for: content) }
			.filter { move in
				let moved = content.offsetBy(dx: move.width, dy: move.height)
				return room.contains(moved) && !regions.contains { $0.intersects(moved) }
			}
			.min { magnitude($0) < magnitude($1) } ?? .zero
	}

	/// The four translations that put `content` past one region's edges.
	private static func escapes(from region: CGRect, for content: CGRect) -> [CGSize] {
		[
			CGSize(width: region.minX - content.maxX, height: 0),
			CGSize(width: region.maxX - content.minX, height: 0),
			CGSize(width: 0, height: region.minY - content.maxY),
			CGSize(width: 0, height: region.maxY - content.minY),
		]
	}

	private static func magnitude(_ size: CGSize) -> CGFloat { abs(size.width) + abs(size.height) }
}

// MARK: - View.clearingReservedRegions

extension View {

	/// Moves this content aside when the system reserves the part of the screen
	/// it would otherwise cover.
	///
	/// Meant for content the app floats over its own canvas — a map's control
	/// capsule, a read-out pill — which no safe area describes. Content placed
	/// in a navigation, tab or window toolbar needs none of this: the system
	/// lays those out itself.
	///
	/// A no-op before iOS 27.1, and on the platforms whose SDK does not yet
	/// declare the API.
	public func clearingReservedRegions() -> some View {
		#if os(iOS) && !targetEnvironment(macCatalyst)
			modifier(ClearingReservedRegions())
		#else
			self
		#endif
	}
}

#if os(iOS) && !targetEnvironment(macCatalyst)

	/// What the window currently reserves, in its own coordinates.
	private struct ReservedRegionReport: Equatable {
		var window: CGRect = .zero
		var regions: [CGRect] = []
	}

	private struct ClearingReservedRegions: ViewModifier {

		/// The slot the layout gave this content, which the offset never moves —
		/// the wrapper below is measured, not the content inside it, so the
		/// measurement cannot chase its own correction.
		@State private var slot: CGRect = .zero
		@State private var report = ReservedRegionReport()

		func body(content: Content) -> some View {
			ZStack {
				content.offset(clearance)
			}
			.background {
				GeometryReader { proxy in
					Color.clear
						.onChange(of: proxy.frame(in: .global), initial: true) { _, frame in
							slot = frame
						}
						.background { reader }
				}
			}
		}

		private var clearance: CGSize {
			ReservedRegionLayout.offset(for: slot, clearing: report.regions, within: report.window)
		}

		@ViewBuilder private var reader: some View {
			if #available(iOS 27.1, *) {
				ReservedRegionReader { report = $0 }
			}
		}
	}

	/// Reports the window's active occlusion regions, in window coordinates —
	/// the window rather than this view, so the regions are measured against the
	/// whole display however small the content is.
	@available(iOS 27.1, *)
	private struct ReservedRegionReader: UIViewRepresentable {

		let report: (ReservedRegionReport) -> Void

		func makeUIView(context: Context) -> ReportingView {
			let view = ReportingView()
			view.report = report
			return view
		}

		func updateUIView(_ view: ReportingView, context: Context) { view.report = report }

		final class ReportingView: UIView {

			var report: ((ReservedRegionReport) -> Void)?
			private var last = ReservedRegionReport()

			override func layoutSubviews() {
				super.layoutSubviews()
				send()
			}

			override func didMoveToWindow() {
				super.didMoveToWindow()
				send()
			}

			private func send() {
				guard let window else { return }
				let found = ReservedRegionReport(
					window: window.bounds,
					regions: window.reservedRegions(kind: .occlusion).map(\.frame)
				)
				guard found != last else { return }
				last = found
				// Out of the layout pass: the report drives SwiftUI state.
				let report = report
				Task { @MainActor in report?(found) }
			}
		}
	}

#endif
