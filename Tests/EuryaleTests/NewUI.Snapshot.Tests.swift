// Snapshot tests covering the new UI lines added across the PR so they count
// toward the SonarCloud new-code coverage metric.
//
// On first run each assertion records a reference image under
// `Tests/EuryaleTests/__Snapshots__/NewUI.Snapshot.Tests/...` and reports the
// test as failed with a "recorded" message — that is expected. Commit the
// generated images and the next runs compare against them.

import SnapshotTesting
import SwiftUI
import Testing

@testable import Euryale

// iPhone-only: see the note in Pill.Snapshot.Tests.swift. References are @3x.
#if os(iOS) && !targetEnvironment(macCatalyst)
import UIKit

@MainActor
@Suite("New UI snapshot", .enabled(if: UIDevice.current.userInterfaceIdiom == .phone))
struct NewUISnapshotTests {

    // MARK: - TaggedPhotoGallery

    @Test func `tagged photo gallery`() async throws {
        // The first photo carries decodable image bytes (so the `Image(uiImage:)`
        // branch runs) and many long labels (so the pill flow wraps across rows,
        // exercising TagFlowLayout's wrap branches). The second uses empty data,
        // rendering the "photo" placeholder branch.
        let pngData = solidImage(.gray).pngData() ?? Data()
        let view = TaggedPhotoGallery(
            photos: [
                TaggedPhoto(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    imageData: pngData,
                    tags: [
                        "sea": 0.95, "horizon line": 0.9, "clear sky": 0.85,
                        "sailing boat": 0.8, "rocky coastline": 0.75,
                        "distant islands": 0.7, "noise": 0.02,
                    ]
                ),
                TaggedPhoto(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    imageData: Data(),
                    tags: ["sail": 0.9, "boat": 0.7]
                ),
            ],
            pillColor: .blue
        )
        .frame(width: 240, height: 220)

        assertSnapshot(of: view, as: .image)
    }

    // MARK: - IconSegmentedControl (symbolRenderingMode added)

    @Test func `icon segmented control`() async throws {
        @State var selection = "marks"
        let view = IconSegmentedControl(
            selection: $selection,
            options: ["marks", "routes", "traces"],
            systemImage: { value in
                switch value {
                case "marks": "mappin.and.ellipse"
                case "routes": "point.topleft.down.to.point.bottomright.curvepath"
                default: "scribble.variable"
                }
            },
            label: { Text(verbatim: $0.capitalized) }
        )
        .frame(width: 320, height: 60)

        assertSnapshot(of: view, as: .image)
    }

    // MARK: - PaginatedView (indicator inset padding added)

    @Test func `paginated view indicator inset`() async throws {
        struct Page: Identifiable { let id: Int }
        let view = PaginatedView(pages: [Page(id: 1), Page(id: 2), Page(id: 3)]) { page in
            Text(verbatim: "Page \(page.id)")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.2))
        }
        .frame(width: 280, height: 140)

        assertSnapshot(of: view, as: .image)
    }

    // MARK: - IconLabel

    @Test func `icon label`() async throws {
        let view = VStack(alignment: .leading, spacing: 12) {
            IconLabel("Marks", systemImage: "mappin.and.ellipse")
            IconLabel("Routes" as String, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
        }
        .frame(width: 240, height: 80)

        assertSnapshot(of: view, as: .image)
    }

    // Renders the `#if DEBUG` IconLabel preview helper, exercising its view code.
    @Test func `icon label preview helper`() async throws {
        let view = IconLabelPickerPreview()
            .frame(width: 320, height: 120)

        assertSnapshot(of: view, as: .image)
    }

    // MARK: - ScatteredPhotosView (OSImage -> PlatformImage rename)

    @Test func `scattered photos view`() async throws {
        let view = ScatteredPhotosView(images: [solidImage(.red), solidImage(.green), solidImage(.blue)])
            .frame(width: 320, height: 240)

        assertSnapshot(of: view, as: .image(precision: 0.95, perceptualPrecision: 0.95))
    }

    // MARK: - PopupPresenter

    @Test func `popup presenter trigger`() async throws {
        let view = PopupPresenter {
            Label("Details", systemImage: "info.circle")
        } presentedContent: {
            Text(verbatim: "Body")
        }
        .frame(width: 200, height: 60)

        assertSnapshot(of: view, as: .image)
    }

    // MARK: - AdaptiveToolbar

    @Test func `adaptive toolbar`() async throws {
        let view = AdaptiveToolbar([
            ToolbarAction(title: "Add", systemImage: "plus") {},
            ToolbarAction(title: "Edit", systemImage: "pencil") {},
        ])
        .frame(width: 320, height: 60)

        assertSnapshot(of: view, as: .image)
    }
}

/// A 40×40 solid-colour `PlatformImage` for the scattered-photos snapshot, so no
/// sample assets are bundled.
@MainActor
private func solidImage(_ color: Color) -> PlatformImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40))
    return renderer.image { context in
        UIColor(color).setFill()
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
    }
}
#endif // os(iOS) && !macCatalyst
