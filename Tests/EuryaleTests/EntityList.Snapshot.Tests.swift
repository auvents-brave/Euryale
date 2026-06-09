// Snapshot tests for `EntityList` and `ListControlBar`.
//
// On first run each assertion records a reference image under
// `Tests/EuryaleTests/__Snapshots__/EntityList.Snapshot.Tests/...` and reports
// the test as failed with a "recorded" message — that is expected. Commit the
// generated images and the next runs compare against them.
//
// Rendering concrete `EntityList` instances executes `body`, `list`, `rows`,
// `taggedRow`, the `.rowActions(...)` modifier, `rowActionButton` and the
// swipe-actions branch — the iOS-only UI code that the macOS test destination
// never reached.

import SnapshotTesting
import SwiftUI
import Testing

@testable import Euryale

// iPhone-only: see the note in Pill.Snapshot.Tests.swift. References are @3x.
#if os(iOS) && !targetEnvironment(macCatalyst)
  import UIKit

  private struct Port: Identifiable {
    // Fixed IDs so snapshots stay deterministic across runs.
    let id: Int
    let name: String
  }

  @MainActor
  private func samplePorts() -> [Port] {
    [
      Port(id: 1, name: "Monaco"),
      Port(id: 2, name: "Ajaccio"),
      Port(id: 3, name: "La Maddalena"),
    ]
  }

  @MainActor
  private func sampleActions(for port: Port) -> [RowAction] {
    [
      RowAction(title: Text(verbatim: "Pin"), systemImage: "pin") {},
      .delete {},
    ]
  }

  @MainActor
  @Suite("EntityList snapshot", .enabled(if: UIDevice.current.userInterfaceIdiom == .phone))
  struct EntityListSnapshotTests {
    // (a) The selecting init keyed by the items' own id.
    @Test func `selecting list keyed by id`() async throws {
      @State var selection: Port.ID?
      let view = EntityList(samplePorts(), selection: $selection) { port in
        Text(port.name)
      } actions: { port in
        sampleActions(for: port)
      }
      .frame(width: 320, height: 220)

      assertSnapshot(of: view, as: .image)
    }

    // (b) The selection + tag + scrollsToSelection init (drives ScrollViewReader).
    @Test func `selecting list with explicit tag and scroll`() async throws {
      @State var selection: Int? = 2
      let view = EntityList(
        samplePorts(),
        selection: $selection,
        tag: { $0.id },
        scrollsToSelection: true
      ) { port in
        Text(port.name)
      } actions: { port in
        sampleActions(for: port)
      }
      .frame(width: 320, height: 220)

      assertSnapshot(of: view, as: .image)
    }

    // (c) The non-selecting init (SelectionValue == Never).
    @Test func `non-selecting list`() async throws {
      let view = EntityList(samplePorts()) { port in
        Text(port.name)
      } actions: { port in
        sampleActions(for: port)
      }
      .frame(width: 320, height: 220)

      assertSnapshot(of: view, as: .image)
    }

    // (d) ListControlBar beneath an editable list.
    @Test func `control bar`() async throws {
      let view = ListControlBar(canRemove: true, remove: {}) {
        Button {
        } label: {
          Image(systemName: "plus")
        }
      }
      .frame(width: 320, height: 44)

      assertSnapshot(of: view, as: .image)
    }

    // A bare `List` row carrying `.rowActions(...)`. Rendering it inside a real
    // `List` realises the `contextMenu` (and, on iOS, the `swipeActions`) content
    // closures, exercising `rowActionButton` and the swipe-group branch.
    @Test func `row with row actions in a list`() async throws {
      let view = List {
        Text(verbatim: "Monaco")
          .rowActions([
            RowAction(title: Text(verbatim: "Pin"), systemImage: "pin") {},
            .delete {},
          ])
      }
      .frame(width: 320, height: 120)

      assertSnapshot(of: view, as: .image)
    }

    // Renders the `#if DEBUG` preview helper, exercising its view code (the
    // selection + scroll + control-bar wiring) the same way the canvas would.
    @Test func `preview helper renders`() async throws {
      let view = EntityListPreview()
        .frame(width: 320, height: 260)

      assertSnapshot(of: view, as: .image)
    }
  }
#endif  // os(iOS) && !macCatalyst
