// Snapshot test for `HelpBrowser` (HelpKit), so its new lines count toward the
// SonarCloud new-code coverage metric.
//
// On first run the assertion records a reference image under
// `Tests/EuryaleTests/__Snapshots__/HelpBrowser.Snapshot.Tests/...` and reports
// the test as failed with a "recorded" message — that is expected.

import SnapshotTesting
import SwiftUI
import Testing

@testable import HelpKit

// iPhone-only: see the note in Pill.Snapshot.Tests.swift. References are @3x.
#if os(iOS) && !targetEnvironment(macCatalyst)
	import UIKit

	@MainActor
	@Suite("HelpBrowser snapshot", .enabled(if: UIDevice.current.userInterfaceIdiom == .phone))
	struct HelpBrowserSnapshotTests {
		private func sampleBook() -> HelpBook {
			HelpBook(topics: [
				HelpTopic(
					id: "getting-started",
					title: "Getting started",
					body:
						"Welcome to **Thoosa**.\n\nConnect to your boat and watch the instruments come alive."
				),
				HelpTopic(
					id: "logbook",
					title: "Logbook",
					body: "Record a voyage and review its entries.",
					children: [
						HelpTopic(
							id: "logbook-units", title: "Units", body: "Choose nautical miles, knots and more.")
					]
				),
			])
		}

		@Test func `help browser renders a book`() async throws {
			let view = HelpBrowser(book: sampleBook())
				.frame(width: 360, height: 480)

			assertSnapshot(of: view, as: .image)
		}
	}
#endif  // os(iOS) && !macCatalyst
