// Drives the `popupPresentation(...)` view modifiers and the `popupAdapted`
// helper with ViewInspector so the new lines are executed and counted for
// coverage. ViewInspector can't reach a presented popover's content directly, so
// the popover-building functions are exercised by finding the base view, and the
// compact adaptation is exercised by calling `popupAdapted` on its own.

import SwiftUI
import Testing
import ViewInspector

@testable import Euryale

@MainActor
@Suite("popupPresentation modifier")
struct PopupPresentationInspectorTests {

	private struct Sample: Identifiable { let id = 1 }

	@Test func `isPresented popup wraps the base view`() throws {
		let sut = Text(verbatim: "BoolBase").popupPresentation(isPresented: .constant(true)) {
			Text(verbatim: "BoolPopup")
		}
		// Finding the base view forces the function body (which applies the
		// popover / sheet) to run.
		_ = try sut.inspect().find(text: "BoolBase")
	}

	@Test func `item popup wraps the base view`() throws {
		let sut = Text(verbatim: "ItemBase").popupPresentation(item: .constant(Sample()), backgroundInteraction: true) {
			sample in
			Text(verbatim: "ItemPopup \(sample.id)")
		}
		_ = try sut.inspect().find(text: "ItemBase")
	}

	@Test func `popup adapted builds for both interaction modes`() throws {
		// Exercises the compact-width adaptation directly (the popover content
		// closure that calls it is built lazily, out of reach of inspection).
		_ = try popupAdapted(Text(verbatim: "AdaptedOn"), backgroundInteraction: true).inspect().find(text: "AdaptedOn")
		_ = try popupAdapted(Text(verbatim: "AdaptedOff"), backgroundInteraction: false).inspect()
			.find(text: "AdaptedOff")
	}

	@Test func `popup presenter renders its trigger`() throws {
		let sut = PopupPresenter {
			Text(verbatim: "Trigger")
		} presentedContent: {
			Text(verbatim: "PresenterBody")
		}
		// The trigger is always built; finding it exercises `PopupPresenter.body`,
		// which drives itself through `popupPresentation(isPresented:)`.
		_ = try sut.inspect().find(text: "Trigger")
	}
}
