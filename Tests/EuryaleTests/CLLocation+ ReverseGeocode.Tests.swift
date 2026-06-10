import MapKit
import Testing

@testable import Euryale

// Apple's reverse geocoding populates `CLPlacemark.ocean` (and so `AtSea()`
// returns `true`) whenever the coordinate falls over water, including
// **named** waters like marine parks, reserves and straits — not only open
// sea.  Land coordinates leave `ocean` nil and `AtSea()` returns `false`.
//
// Each argument is `(coordinate, expectedAtSea, nameSubstring?)`.  The
// `nameSubstring` is checked case-insensitively against `Name()`; pass `nil`
// to skip the name assertion for coordinates whose reverse-geocoded name is
// locale-dependent (e.g. "Atlantic Ocean" vs "Océan Atlantique").
//
// Every case logs the actual name returned by `Name()` so failures or
// locale drifts are easy to inspect in the test output.
@Test(arguments: [
	// Water inside the Strait of Bonifacio natural marine reserve.
	(CLLocation(latitude: 41.470, longitude: 9.268), true, "Bonifacio" as String?),

	// Land in Monaco.
	(CLLocation(latitude: 43.736, longitude: 7.427), false, "Louis" as String?),

	// Water inside the La Maddalena marine national park.
	(CLLocation(latitude: 41.192, longitude: 9.407), true, "Maddalena" as String?),

	// Land in California.
	(CLLocation(latitude: 37.335, longitude: -122.009), false, "Apple" as String?),

	// Open Ligurian / Tyrrhenian Sea between Monaco and Corsica
	// (name is locale-dependent — skip the substring check).
	(CLLocation(latitude: 43.370, longitude: 8.395), true, nil),

	// Open Atlantic, ~250 NM west of Brittany
	// (name is locale-dependent — skip the substring check).
	(CLLocation(latitude: 48.000, longitude: -8.000), true, nil),
])
func `Reverse Location`(_ value: (CLLocation, Bool, String?)) async throws {
	let coord = value.0.coordinate
	let atSea = await value.0.AtSea()
	let name = await value.0.Name()

	Attachment.record("name=\"\(name)\"", named: "geocode")

	#expect(
		value.1 == atSea,
		"Expected atSea=\(value.1) at (\(coord.latitude), \(coord.longitude)), got \(atSea)")

	if let expected = value.2 {
		#expect(
			name.range(of: expected, options: .caseInsensitive) != nil,
			"Expected name at (\(coord.latitude), \(coord.longitude)) to contain \"\(expected)\", got \"\(name)\"")
	}
}
