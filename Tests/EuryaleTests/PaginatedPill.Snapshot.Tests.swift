// Snapshot tests for `PaginatedPill`.
//
// On first run each assertion records a reference image in
// `Tests/EuryaleTests/__Snapshots__/PaginatedPill_Snapshot_Tests/...` and
// reports the test as failed with a "recorded" message — that is expected.
// Commit the generated images and the next runs will compare against them.

import SnapshotTesting
import SwiftUI
import Testing

@testable import Euryale

// iPhone-only: see note in Pill.Snapshot.Tests.swift.  References are @3x.
#if os(iOS) && !targetEnvironment(macCatalyst)
	import UIKit

	private struct Room: Identifiable {
		// Fixed IDs so snapshots remain deterministic across runs.
		let id: Int
		let name: String
		let count: Int
	}

	@MainActor
	@Suite("PaginatedPill snapshot", .enabled(if: UIDevice.current.userInterfaceIdiom == .phone))
	struct PaginatedPillSnapshotTests {
		private let rooms: [Room] = [
			Room(id: 1, name: "Bedrooms", count: 3),
			Room(id: 2, name: "Bathrooms", count: 2),
			Room(id: 3, name: "Garage", count: 1),
		]

		// MARK: - Overlay style (default)

		@Test func `overlay default — bottom-trailing`() async throws {
			let view = PaginatedPill(pages: rooms) { room in
				Pill(label: room.name, value: room.count)
			}
			.preferredColorScheme(.light)
			.frame(width: 280, height: 100)
			.padding()

			assertSnapshot(of: view, as: .image)
		}

		@Test func `overlay bottom-leading`() async throws {
			let view = PaginatedPill(
				pages: rooms,
				indicatorAlignment: .bottomLeading
			) { room in
				Pill(label: room.name, value: room.count)
			}
			.preferredColorScheme(.light)
			.frame(width: 280, height: 100)
			.padding()

			assertSnapshot(of: view, as: .image)
		}

		@Test func `overlay top-trailing`() async throws {
			let view = PaginatedPill(
				pages: rooms,
				indicatorAlignment: .topTrailing
			) { room in
				Pill(label: room.name, value: room.count)
			}
			.preferredColorScheme(.light)
			.frame(width: 280, height: 100)
			.padding()

			assertSnapshot(of: view, as: .image)
		}

		@Test func `overlay with custom purple accent`() async throws {
			let view = PaginatedPill(pages: rooms, accentColor: .purple) { room in
				Pill(label: room.name, value: room.count)
			}
			.preferredColorScheme(.light)
			.frame(width: 280, height: 100)
			.padding()

			assertSnapshot(of: view, as: .image)
		}

		// MARK: - Stacked style

		@Test func `stacked center (classic look)`() async throws {
			let view = PaginatedPill(
				pages: rooms,
				style: .stacked,
				indicatorAlignment: .center
			) { room in
				Pill(label: room.name, value: room.count)
			}
			.preferredColorScheme(.light)
			.frame(width: 280, height: 130)
			.padding()

			assertSnapshot(of: view, as: .image)
		}

		@Test func `stacked trailing`() async throws {
			let view = PaginatedPill(
				pages: rooms,
				style: .stacked,
				indicatorAlignment: .trailing
			) { room in
				Pill(label: room.name, value: room.count)
			}
			.preferredColorScheme(.light)
			.frame(width: 280, height: 130)
			.padding()

			assertSnapshot(of: view, as: .image)
		}

		// MARK: - Edge cases

		@Test func `many pages — bottom-center`() async throws {
			struct Slide: Identifiable { let id: Int }
			let slides = (1...8).map { Slide(id: $0) }

			let view = PaginatedPill(
				pages: slides,
				indicatorAlignment: .bottom
			) { slide in
				Text("Slide \(slide.id)")
					.font(.title2)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			.preferredColorScheme(.light)
			.frame(width: 280, height: 100)
			.padding()

			assertSnapshot(of: view, as: .image)
		}

		@Test func `single page — single dot`() async throws {
			let view = PaginatedPill(pages: [rooms[0]]) { room in
				Pill(label: room.name, value: room.count)
			}
			.preferredColorScheme(.light)
			.frame(width: 280, height: 90)
			.padding()

			assertSnapshot(of: view, as: .image)
		}

		@Test func `empty pages — collapses to zero-height`() async throws {
			let view = PaginatedPill(pages: [Room]()) { room in
				Pill(label: room.name, value: room.count)
			}
			.preferredColorScheme(.light)
			.frame(width: 280, height: 40)
			.padding()

			assertSnapshot(of: view, as: .image)
		}

		// MARK: - Pages with rich content (uses Tests/Resources/TestImage.jpeg)

		/// Each page renders a different kind of content — a tinted SF Symbol
		/// card, the bundled test image, and a `StatusPill` — to verify that
		/// the overlay layout keeps the indicator row legible regardless of
		/// what fills the page.
		@Test func `mixed content pages — symbol, photo, status`() async throws {
			enum Pane: Identifiable {
				case icon, photo, status
				var id: String { "\(self)" }
			}

			let testImage: UIImage = {
				// Resource is declared via `.process("Resources")` in the test target.
				guard let url = Bundle.module.url(forResource: "TestImage", withExtension: "jpeg"),
					let data = try? Data(contentsOf: url),
					let img = UIImage(data: data)
				else { return UIImage() }
				return img
			}()

			let view = PaginatedPill(pages: [Pane.icon, .photo, .status]) { pane in
				switch pane {
				case .icon:
					ZStack {
						LinearGradient(
							colors: [.blue, .purple],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
						Image(systemName: "house.fill")
							.font(.system(size: 40, weight: .bold))
							.foregroundStyle(.white)
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.clipShape(RoundedRectangle(cornerRadius: 6))

				case .photo:
					Image(uiImage: testImage)
						.resizable()
						.scaledToFill()
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.clipped()
						.clipShape(RoundedRectangle(cornerRadius: 6))

				case .status:
					VStack(spacing: 6) {
						StatusPill(label: "Sync complete", status: .ok)
						StatusPill(label: "1 item pending", status: .warning)
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity)
				}
			}
			.preferredColorScheme(.light)
			.frame(width: 320, height: 200)
			.padding()

			assertSnapshot(of: view, as: .image)
		}
	}

#endif  // os(iOS) && !macCatalyst
