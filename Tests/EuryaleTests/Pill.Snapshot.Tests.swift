// Snapshot tests for SwiftUI views.
//
// On first run the assertion records a reference image in
// `Tests/EuryaleTests/__Snapshots__/Pill_Snapshot_Tests/...` and reports the
// test as failed with a "recorded" message — that is expected.  Commit the
// generated image and the next run will compare against it.
//
// To regenerate every snapshot in this file (after intentional UI changes),
// temporarily wrap a test with:
//
//     withSnapshotTesting(record: .all) { ... existing assertSnapshot ... }
//
// then revert.  Don't leave `record: .all` in the committed code.

import SnapshotTesting
import SwiftUI
import Testing

@testable import Euryale

// Snapshot references are rendered at the host device's scale (iPhone 17 is
// @3x).  They are therefore checked in only for that one device: the suites
// compile on iOS (excluding Mac Catalyst) and skip at runtime on any non-phone
// idiom (e.g. iPad @2x), so a single @3x reference set stays valid.
#if os(iOS) && !targetEnvironment(macCatalyst)
  import UIKit

  @MainActor
  @Suite("Pill snapshot", .enabled(if: UIDevice.current.userInterfaceIdiom == .phone))
  struct PillSnapshotTests {
    @Test func `default rendering — Bedrooms 3`() async throws {
      let view = Pill(label: "Bedrooms", value: 3)
        .frame(width: 160, height: 70)

      assertSnapshot(of: view, as: .image)
    }

    @Test func `zero value`() async throws {
      let view = Pill(label: "Bathrooms", value: 0)
        .frame(width: 160, height: 70)

      assertSnapshot(of: view, as: .image)
    }

    @Test func `long label`() async throws {
      let view = Pill(label: "Outdoor parking spaces", value: 12)
        .frame(width: 220, height: 70)

      assertSnapshot(of: view, as: .image)
    }

    @Test func `large value`() async throws {
      let view = Pill(label: "Steps today", value: 14_237)
        .frame(width: 200, height: 70)

      // The grouped large number antialiases marginally differently between a
      // local Mac and the CI runner (same Xcode / iPhone 17 @3x simulator), so
      // this one allows a small perceptual tolerance rather than exact match.
      assertSnapshot(of: view, as: .image(precision: 0.97, perceptualPrecision: 0.98))
    }
  }

  @MainActor
  @Suite("PillsView snapshot", .enabled(if: UIDevice.current.userInterfaceIdiom == .phone))
  struct PillsViewSnapshotTests {
    @Test func `three pills, horizontal layout`() async throws {
      let view = PillsView(items: [
        ("Home", 12),
        ("Bathroom", 2),
        ("Bedroom", 3),
      ])
      .frame(width: 380, height: 80)

      assertSnapshot(of: view, as: .image)
    }

    @Test func `three pills, constrained falls back to vertical`() async throws {
      let view = PillsView(items: [
        ("Home", 12),
        ("Bathroom", 2),
        ("Bedroom", 3),
      ])
      .frame(width: 200, height: 240)

      assertSnapshot(of: view, as: .image)
    }
  }

#endif  // os(iOS) && !macCatalyst
