// Snapshot tests for `StatusPill`.
//
// On first run the assertion records a reference image in
// `Tests/EuryaleTests/__Snapshots__/StatusPill_Snapshot_Tests/...` and reports
// the test as failed with a "recorded" message — that is expected.  Commit
// the generated image and the next run will compare against it.

import SnapshotTesting
import SwiftUI
import Testing

@testable import Euryale

// iPhone-only: see note in Pill.Snapshot.Tests.swift.  References are @3x.
#if os(iOS) && !targetEnvironment(macCatalyst)
	import UIKit

	@MainActor
	@Suite("StatusPill snapshot", .enabled(if: UIDevice.current.userInterfaceIdiom == .phone))
	struct StatusPillSnapshotTests {
		@Test func `status ok`() async throws {
			let view = StatusPill(label: "All Good", status: .ok)
				.preferredColorScheme(.light)
				.frame(width: 280, height: 50)
				.padding()

			assertSnapshot(of: view, as: .image)
		}

		@Test func `status warning`() async throws {
			let view = StatusPill(label: "Check Items", status: .warning)
				.preferredColorScheme(.light)
				.frame(width: 280, height: 50)
				.padding()

			assertSnapshot(of: view, as: .image)
		}

		@Test func `status error`() async throws {
			let view = StatusPill(label: "Needs Attention", status: .error)
				.preferredColorScheme(.light)
				.frame(width: 280, height: 50)
				.padding()

			assertSnapshot(of: view, as: .image)
		}

		@Test func `stacked vertically`() async throws {
			let view = VStack(spacing: 8) {
				StatusPill(label: "All Good", status: .ok)
				StatusPill(label: "Check Items", status: .warning)
				StatusPill(label: "Needs Attention", status: .error)
			}
			.preferredColorScheme(.light)
			.frame(width: 280, height: 200)
			.padding()

			assertSnapshot(of: view, as: .image)
		}

		@Test func `long label wraps or truncates predictably`() async throws {
			let view = StatusPill(
				label: "A particularly long status label that exercises the layout under width constraints",
				status: .warning
			)
			.preferredColorScheme(.light)
			.frame(width: 280, height: 80)
			.padding()

			assertSnapshot(of: view, as: .image)
		}
	}

#endif  // os(iOS) && !macCatalyst
