// Drives the `rowActions(_:)` View modifier with ViewInspector so its non-empty
// branch (which builds the `contextMenu` / `swipeActions` wrapper) is executed.

import SwiftUI
import Testing
import ViewInspector

@testable import Euryale

@MainActor
@Suite("rowActions modifier")
struct RowActionsInspectorTests {
    private func sampleActions() -> [RowAction] {
        [
            RowAction(title: Text(verbatim: "Pin"), systemImage: "pin") {},
            RowAction(title: Text(verbatim: "Rename"), systemImage: "pencil") {},
            .delete {},
        ]
    }

    @Test func `empty actions leave the row unchanged`() throws {
        let row = Text(verbatim: "Row").rowActions([])
        _ = try row.inspect().find(text: "Row")
    }

    @Test func `non-empty actions still render the row content`() throws {
        let row = Text(verbatim: "Row").rowActions(sampleActions())
        // Inspecting the wrapped view forces the non-empty branch (the
        // `contextMenu` / `swipeActions` wrapper) to be built around the row.
        _ = try row.inspect().find(text: "Row")
    }
}
