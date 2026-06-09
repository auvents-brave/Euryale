// Snapshot tests for `HtmlView`.
//
// On first run the assertion records a reference image in
// `Tests/EuryaleTests/__Snapshots__/HtmlView_Snapshot_Tests/...` and reports
// the test as failed with a "recorded" message — that is expected.  Commit
// the generated image and the next run will compare against it.
//
// All cases force `.preferredColorScheme(.light)` so the snapshot remains
// deterministic regardless of the host's dark-mode setting.

import SnapshotTesting
import SwiftUI
import Testing

@testable import Euryale

// iPhone-only: see note in Pill.Snapshot.Tests.swift.  References are @3x.
#if os(iOS) && !targetEnvironment(macCatalyst)
  import UIKit

  @MainActor
  @Suite("HtmlView snapshot", .enabled(if: UIDevice.current.userInterfaceIdiom == .phone))
  struct HtmlViewSnapshotTests {
    @Test func `plain text — no HTML tags`() async throws {
      let view = HtmlView(forHTML: "Hello world — plain text path, no parsing.")
        .preferredColorScheme(.light)
        .frame(width: 320, height: 80)
        .padding()

      assertSnapshot(of: view, as: .image)
    }

    @Test func `bold and italic`() async throws {
      let view = HtmlView(forHTML: "This is <b>bold</b> and <i>italic</i> inline.")
        .preferredColorScheme(.light)
        .frame(width: 320, height: 80)
        .padding()

      assertSnapshot(of: view, as: .image)
    }

    @Test func `anchor link to example dot com`() async throws {
      let view = HtmlView(
        forHTML: "Visit <a href=\"https://example.com\">example.com</a> for details."
      )
      .preferredColorScheme(.light)
      .frame(width: 320, height: 80)
      .padding()

      assertSnapshot(of: view, as: .image)
    }

    @Test func `inline CSS colour`() async throws {
      let view = HtmlView(
        forHTML: "<p style=\"color:#B22222\">Firebrick text</p>"
      )
      .preferredColorScheme(.light)
      .frame(width: 320, height: 80)
      .padding()

      assertSnapshot(of: view, as: .image)
    }

    @Test func `mixed paragraph`() async throws {
      let html = """
        <p>Read the latest at <a href="https://example.com/news">example.com/news</a> \
        or browse the <a href="https://example.com/docs">docs</a> for <b>full coverage</b>.</p>
        """
      let view = HtmlView(forHTML: html)
        .preferredColorScheme(.light)
        .frame(width: 320, height: 120)
        .padding()

      assertSnapshot(of: view, as: .image)
    }
  }

#endif  // os(iOS) && !macCatalyst
