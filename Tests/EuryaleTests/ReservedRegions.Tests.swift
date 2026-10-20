import Foundation
import Testing

@testable import Euryale

// The hinge of a folding iPhone, as the window would report it: a full-height
// band down the middle of a 1000 × 2000 inner display.
private let window = CGRect(x: 0, y: 0, width: 1000, height: 2000)
private let hinge = CGRect(x: 480, y: 0, width: 40, height: 2000)

@Suite("ReservedRegionLayout")
struct ReservedRegionLayoutTests {

	private func offset(_ content: CGRect, _ regions: [CGRect] = [hinge]) -> CGSize {
		ReservedRegionLayout.offset(for: content, clearing: regions, within: window)
	}

	@Test func `content clear of every region stays put`() {
		#expect(offset(CGRect(x: 800, y: 1800, width: 160, height: 44)) == .zero)
	}

	@Test func `no regions means no movement`() {
		#expect(offset(CGRect(x: 470, y: 100, width: 100, height: 44), []) == .zero)
	}

	@Test func `a capsule astride the hinge slides to its nearer side`() {
		// Mostly to the right of the band: pushing right costs 40, left 90.
		let pushedRight = offset(CGRect(x: 470, y: 1800, width: 100, height: 44))
		#expect(pushedRight == CGSize(width: 50, height: 0))

		// Mostly to the left: the other way, and leftwards is negative.
		let pushedLeft = offset(CGRect(x: 400, y: 1800, width: 100, height: 44))
		#expect(pushedLeft == CGSize(width: -20, height: 0))
	}

	@Test func `a full-height band is never escaped vertically`() {
		let moved = offset(CGRect(x: 470, y: 900, width: 100, height: 44))

		#expect(moved.height == 0)
		#expect(moved.width != 0)
	}

	@Test func `the escape keeps the content inside the window`() {
		// A band near the right edge: pushing right is the shorter move (50) but
		// would hang the capsule off the screen, so it goes left (70) instead.
		let edgeBand = CGRect(x: 930, y: 0, width: 40, height: 2000)
		let moved = offset(CGRect(x: 920, y: 100, width: 80, height: 44), [edgeBand])

		#expect(moved == CGSize(width: -70, height: 0))
	}

	@Test func `content that cannot clear the region is left alone`() {
		// Wider than either side of the band: no escape fits the window.
		#expect(offset(CGRect(x: 100, y: 100, width: 800, height: 44)) == .zero)
	}

	@Test func `a corner cut-out is escaped the short way`() {
		// A camera housing: squarer, so the vertical way out can be the nearest.
		let housing = CGRect(x: 420, y: 0, width: 160, height: 80)
		let moved = offset(CGRect(x: 450, y: 50, width: 100, height: 44), [housing])

		#expect(moved == CGSize(width: 0, height: 30))
	}

	@Test func `an escape that lands on another region is refused`() {
		let second = CGRect(x: 560, y: 0, width: 40, height: 2000)
		let moved = offset(CGRect(x: 470, y: 100, width: 100, height: 44), [hinge, second])

		// Rightwards is the nearest way out of the hinge (50) but drops the
		// capsule onto the second band, so it goes left of both (90).
		#expect(moved == CGSize(width: -90, height: 0))
	}
}
