import SwiftUI
import Testing

@testable import Euryale

// Cross-platform: `RowAction` is a plain value type, so these run on every
// destination (no `#if os(iOS)` gate). They cover the non-View part of
// EntityList.swift — the `delete(_:)` factory and the designated initialiser's
// `id` defaulting.
@MainActor
@Suite("RowAction")
struct RowActionTests {
  @Test func `delete factory has the expected defaults`() {
    let action = RowAction.delete {}

    #expect(action.id == "delete")
    #expect(action.systemImage == "trash")
    #expect(action.role == .destructive)
    #expect(action.isDefaultSwipe == true)
  }

  @Test func `id defaults to the system image`() {
    let action = RowAction(title: Text(verbatim: "Pin"), systemImage: "pin") {}

    #expect(action.id == "pin")
    #expect(action.role == nil)
    #expect(action.isDefaultSwipe == false)
  }

  @Test func `explicit id overrides the system image`() {
    let action = RowAction(
      id: "custom",
      title: Text(verbatim: "Rename"),
      systemImage: "pencil",
      role: .destructive,
      isDefaultSwipe: true
    ) {}

    #expect(action.id == "custom")
    #expect(action.systemImage == "pencil")
    #expect(action.role == .destructive)
    #expect(action.isDefaultSwipe == true)
  }
}
