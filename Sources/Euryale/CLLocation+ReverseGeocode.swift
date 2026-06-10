public import CoreLocation
import Logging
import MapKit

#if canImport(Playgrounds)
	import Playgrounds
#endif

#if canImport(GeoToolbox)
	import GeoToolbox
#endif

// MARK: - CLLocation + ReverseGeocode

extension CLLocation {

	// MARK: Public API

	/// Returns the name of the location using reverse geocoding.
	///
	/// On macOS 26+ and iOS 26+, this uses the modern `PlaceDescriptor` API to extract
	/// the first line of the address. On older systems, it falls back to `CLPlacemark.name`.
	///
	/// - Returns: The name of the location, or an empty string if geocoding fails or no name is available.
	///
	/// ## Example
	/// ```swift
	/// let location = CLLocation(latitude: 37.335, longitude: -122.009)
	/// let name = await location.Name()
	/// print(name) // "Apple Park"
	/// ```
	public func Name() async -> String {
		if #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) {
			guard let descriptor = await ReverseGeocode26(), let address = descriptor.address,
				let first = address.components(separatedBy: .newlines).first
			else { return "" }
			return first
		} else {
			guard let mark = await ReverseGeocode00() else { return "" }
			return mark.name ?? ""
		}
	}

	/// Determines whether the location is at sea.
	///
	/// `MKMapItem.placemark` is an `MKPlacemark` (which inherits from
	/// `CLPlacemark`).  The legacy `.ocean` / `.inlandWater` properties on
	/// `CLPlacemark` remain populated when the coordinate falls within a
	/// named body of water — only `CLGeocoder` itself is deprecated, not the
	/// placemark fields.  We therefore read them from the `MKMapItem`
	/// returned by `MKReverseGeocodingRequest` on macOS 26 / iOS 26+, and
	/// from the legacy `CLGeocoder` path on older systems.
	///
	/// `inlandWater` covers large lakes (e.g. the Great Lakes, Lake Geneva).
	/// Remove it from the check if you strictly want "sea or ocean".
	///
	/// - Returns: `true` if the location is over an ocean, sea, or large
	///   inland body of water; `false` otherwise (including when reverse
	///   geocoding fails).
	///
	/// ## Example
	/// ```swift
	/// let location = CLLocation(latitude: 43.370, longitude: 8.395)
	/// let isAtSea = await location.AtSea()
	/// print(isAtSea) // true (Mediterranean Sea)
	/// ```
	public func AtSea() async -> Bool {
		if #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) {
			let request = MKReverseGeocodingRequest(location: self)
			guard let item = try? await request?.mapItems.first else { return false }
			return item.placemark.ocean != nil
		} else {
			guard let mark = await ReverseGeocode00() else { return false }
			return mark.ocean != nil
		}
	}

	// MARK: Helpers

	/// Performs reverse geocoding using the legacy `CLGeocoder` API.
	///
	/// This method wraps the completion handler-based `reverseGeocodeLocation(_:completionHandler:)`
	/// method in a modern async/await interface using a checked continuation.
	///
	/// - Returns: The first `CLPlacemark` from the results, or `nil` if geocoding fails.
	fileprivate nonisolated func ReverseGeocode00() async -> CLPlacemark? {
		return await withCheckedContinuation { continuation in
			CLGeocoder().reverseGeocodeLocation(self) { placemarks, error in
				guard error == nil else {
					Logger(label: "").error(
						"Reverse geocoding failed", metadata: ["error": "\(error!.localizedDescription)"])
					continuation.resume(returning: nil)
					return
				}
				let placemark = placemarks?.first
				continuation.resume(returning: placemark)
			}
		}
	}

	/// Performs reverse geocoding using the modern `MKReverseGeocodingRequest` API.
	///
	/// This method uses the newer MapKit reverse geocoding API available in macOS 26+ and iOS 26+,
	/// which returns a `PlaceDescriptor` that can be used across different mapping services.
	///
	/// - Returns: A `PlaceDescriptor` for the location, or `nil` if geocoding fails.
	@available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
	fileprivate func ReverseGeocode26() async -> PlaceDescriptor? {
		let request = MKReverseGeocodingRequest(location: self)
		do {
			guard let mapItems = try await request?.mapItems, let firstItem = mapItems.first else {
				return nil
			}
			return PlaceDescriptor(item: firstItem)
		} catch {
			Logger(label: "").error(
				"Reverse geocoding failed", metadata: ["error": "\(error.localizedDescription)"])
			return nil
		}
	}
}

#if canImport(Playgrounds) && !NO_PLAYGROUND_EXAMPLES
	// MARK: - Examples (Playground)

	let locations = [
		(CLLocation(latitude: 41.470, longitude: 9.268), "Bonifacio"),
		(CLLocation(latitude: 43.736, longitude: 7.427), "Louis II"),
		(CLLocation(latitude: 41.192, longitude: 9.407), "Maddalena"),
		(CLLocation(latitude: 37.335, longitude: -122.009), "Apple"),
		(CLLocation(latitude: 43.370, longitude: 8.395), "Monaco/Corse"),
		(CLLocation(latitude: 39.8997, longitude: 0.8064), "Columbretes"),
	]

	@available(macOS 26.4, iOS 26.4, tvOS 26.4, watchOS 26.4, visionOS 26.4, *)
	#Playground {
		for (index, data) in locations.enumerated() {
			print("[\(index + 1)/\(locations.count)] Testing: \(data.1)")

			let reversedName = await data.0.Name()
			print("Name: \(reversedName.isEmpty ? "(empty)" : reversedName)")

			let atSea = await data.0.AtSea()
			print("At sea: \(atSea)")

			guard let placemark = await data.0.ReverseGeocode00() else {
				print("  - Reverse geocoding failed")
				return
			}
			print("Full CLPlacemark Details:")
			print("  - Name: \(placemark.name ?? "N/A")")

			// Location information
			if let location = placemark.location {
				let coord = location.coordinate
				print("  - Location: \(coord.latitude), \(coord.longitude)")
				print("  - Altitude: \(location.altitude)m")
				print("  - Horizontal Accuracy: \(location.horizontalAccuracy)m")
				print("  - Vertical Accuracy: \(location.verticalAccuracy)m")
			} else {
				print("  - Location: N/A")
			}

			// Address components
			print("  - Thoroughfare (Street): \(placemark.thoroughfare ?? "N/A")")
			print("  - SubThoroughfare (Street Number): \(placemark.subThoroughfare ?? "N/A")")
			print("  - Locality (City): \(placemark.locality ?? "N/A")")
			print("  - SubLocality: \(placemark.subLocality ?? "N/A")")
			print("  - Administrative Area (State): \(placemark.administrativeArea ?? "N/A")")
			print("  - SubAdministrative Area (County): \(placemark.subAdministrativeArea ?? "N/A")")
			print("  - Postal Code: \(placemark.postalCode ?? "N/A")")
			print("  - Country: \(placemark.country ?? "N/A")")
			print("  - ISO Country Code: \(placemark.isoCountryCode ?? "N/A")")

			// Geographic features
			print("  - Inland Water: \(placemark.inlandWater ?? "N/A")")
			print("  - Ocean: \(placemark.ocean ?? "N/A")")
			print("  - Areas of Interest: \(placemark.areasOfInterest?.joined(separator: ", ") ?? "N/A")")

			// Region — `CLPlacemark.region` and `CLCircularRegion` are unavailable
			// on visionOS, so the region details are skipped there.
			#if !os(visionOS)
				if let region = placemark.region {
					print("  - Region Identifier: \(region.identifier)")
					if let circularRegion = region as? CLCircularRegion {
						print(
							"  - Region Center: \(circularRegion.center.latitude), \(circularRegion.center.longitude)"
						)
						print("  - Region Radius: \(circularRegion.radius)m")
					}
				} else {
					print("  - Region: N/A")
				}
			#endif

			// Time zone
			if let timeZone = placemark.timeZone {
				print("  - Time Zone: \(timeZone.identifier) (UTC\(timeZone.secondsFromGMT() / 3600))")
			} else {
				print("  - Time Zone: N/A")
			}

			guard let descriptor = await data.0.ReverseGeocode26() else {
				print("  - Reverse geocoding failed")
				return
			}
			print("Full PlaceDescriptor Details:")
			print("  - Common Name: \(descriptor.commonName ?? "N/A")")

			if let coordinate = descriptor.coordinate {
				print("  - Descriptor Location: \(coordinate.latitude), \(coordinate.longitude)")
			}

			if let address = descriptor.address {
				print("  - Address: \(address)")
			}

			print("  - Description: \(descriptor.description)")  // starting OS 26.4

			print(
				"  - Supporting Representations: \(descriptor.supportingRepresentations.count) available")
			for rep in descriptor.supportingRepresentations {
				print("    • \(rep)")
			}

			print("  - Representations: \(descriptor.representations.count) available")
			for rep in descriptor.representations {
				switch rep {
				case .coordinate(let coord):
					print("    • Coordinate: \(coord.latitude), \(coord.longitude)")
				case .address(let addr):
					print("    • Address: \(addr)")
				case .deviceLocation(let device):
					print("    • Device: \(device)")
				@unknown default:
					print("    • Unknown representation")
				}
			}

			print("")  // Blank line between entries
		}
	}
#endif  // canImport(Playgrounds)
