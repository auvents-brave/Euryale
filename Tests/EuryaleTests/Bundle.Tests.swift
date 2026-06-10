import Foundation
import Testing

@testable import Euryale

@Test func `Bundle display name`() async throws {

	let _ = Bundle.module.displayName

	#expect(
		DisplayName.getDisplayName(
			MockBundle(
				base: [
					"CFBundleName": "Stheno",
					"CFBundleDisplayName": "Stheno Library",
				],
				localized: [:]
			)) == "Stheno Library")

	#expect(
		DisplayName.getDisplayName(
			MockBundle(
				base: [
					"CFBundleName": "Stheno"
				],
				localized: [:]
			)) == "Stheno")

	#expect(
		DisplayName.getDisplayName(
			MockBundle(
				base: [
					"CFBundleName": "Stheno",
					"CFBundleDisplayName": "Stheno Library",
				],
				localized: [
					"CFBundleName": "Sthenô",
					"CFBundleDisplayName": "Sthenô Librairie",
				]
			)) == "Sthenô Librairie")

	#expect(
		DisplayName.getDisplayName(
			MockBundle(
				base: [
					"CFBundleName": "Stheno"
				],
				localized: [
					"CFBundleName": "Sthenô"
				]
			)) == "Sthenô")

	#expect(
		DisplayName.getDisplayName(
			MockBundle(
				base: [:],
				localized: [:]
			)) != "")

	// Call our Bundle extensions to get correct code coverage
	_ = Bundle.module.displayName
}

@Suite("Bundle synchronizeDisplayedVersion") struct BundleSyncVersionTests {
	@Test func `writes version under the default key`() async throws {
		let suite = "Euryale.BundleSyncTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suite)!
		defer { defaults.removePersistentDomain(forName: suite) }

		Bundle.main.synchronizeDisplayedVersion(in: defaults)
		let stored = defaults.string(forKey: "version")
		#expect(stored != nil)
		#expect(stored == Bundle.main.displayedVersion)
	}

	@Test func `writes version under a custom key`() async throws {
		let suite = "Euryale.BundleSyncTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suite)!
		defer { defaults.removePersistentDomain(forName: suite) }

		Bundle.main.synchronizeDisplayedVersion(key: "appVersion", in: defaults)
		#expect(defaults.string(forKey: "appVersion") != nil)
		#expect(defaults.string(forKey: "version") == nil)
	}

	@Test func `subsequent calls overwrite the value`() async throws {
		let suite = "Euryale.BundleSyncTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suite)!
		defer { defaults.removePersistentDomain(forName: suite) }

		Bundle.main.synchronizeDisplayedVersion(in: defaults)
		let first = defaults.string(forKey: "version")
		Bundle.main.synchronizeDisplayedVersion(in: defaults)
		let second = defaults.string(forKey: "version")
		#expect(first == second)
	}
}

private struct MockBundle: BundleInfoProviding, @unchecked Sendable {
	private let base: [String: Any]?
	private let localized: [String: Any]?

	init(base: [String: Any]?, localized: [String: Any]?) {
		self.base = base
		self.localized = localized
	}

	var infoDictionary: [String: Any]? { base }
	var localizedInfoDictionary: [String: Any]? { localized }
}
