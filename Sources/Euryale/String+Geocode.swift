public import CoreLocation
import Logging
import MapKit

// MARK: - String + Geocode

extension String {

	// MARK: Public API

	/// Forward-geocodes the address and returns the coordinate of the best match.
	///
	/// On macOS 26+ / iOS 26+ (and the other 26 OSes) this uses the modern
	/// `MKGeocodingRequest`; on older systems it falls back to the legacy
	/// `CLGeocoder.geocodeAddressString(_:)`. This mirrors the reverse-geocoding
	/// split on ``CoreLocation/CLLocation``.
	///
	/// - Parameter near: An optional reference coordinate used to disambiguate
	///   place names that resolve in several countries (e.g. a port name). When
	///   provided, the candidate closest to it is returned; otherwise the first
	///   match is used.
	/// - Returns: The coordinate of the best match, or `nil` when the address
	///   can't be resolved or geocoding fails.
	///
	/// ## Example
	/// ```swift
	/// let coordinate = await "Zeebrugge".Coordinate(near: vesselCoordinate)
	/// ```
	public func Coordinate(near: CLLocationCoordinate2D? = nil) async -> CLLocationCoordinate2D? {
		if #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) {
			return await Geocode26(near: near)
		} else {
			return await Geocode00(near: near)
		}
	}

	// MARK: Helpers

	/// Forward geocoding via the legacy `CLGeocoder` API, wrapped in async/await.
	///
	/// - Parameter near: Optional reference coordinate to pick the closest match.
	/// - Returns: The best coordinate, or `nil` if geocoding fails.
	fileprivate nonisolated func Geocode00(near: CLLocationCoordinate2D?) async
		-> CLLocationCoordinate2D?
	{
		return await withCheckedContinuation { continuation in
			CLGeocoder().geocodeAddressString(self) { placemarks, error in
				guard error == nil else {
					Logger(label: "").error(
						"Forward geocoding failed", metadata: ["error": "\(error!.localizedDescription)"])
					continuation.resume(returning: nil)
					return
				}
				let coordinates = (placemarks ?? []).compactMap { $0.location?.coordinate }
				continuation.resume(returning: Self.nearest(coordinates, to: near))
			}
		}
	}

	/// Forward geocoding via the modern `MKGeocodingRequest` API.
	///
	/// - Parameter near: Optional reference coordinate to pick the closest match.
	/// - Returns: The best coordinate, or `nil` if geocoding fails.
	@available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
	fileprivate func Geocode26(near: CLLocationCoordinate2D?) async -> CLLocationCoordinate2D? {
		let request = MKGeocodingRequest(addressString: self)
		do {
			guard let mapItems = try await request?.mapItems else { return nil }
			let coordinates = mapItems.map { $0.placemark.coordinate }
			return Self.nearest(coordinates, to: near)
		} catch {
			Logger(label: "").error(
				"Forward geocoding failed", metadata: ["error": "\(error.localizedDescription)"])
			return nil
		}
	}

	/// Returns the coordinate closest to `reference`, or the first one when no
	/// reference is given.
	fileprivate static func nearest(
		_ coordinates: [CLLocationCoordinate2D], to reference: CLLocationCoordinate2D?
	) -> CLLocationCoordinate2D? {
		guard let reference else { return coordinates.first }
		let origin = CLLocation(latitude: reference.latitude, longitude: reference.longitude)
		return coordinates.min {
			CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: origin)
				< CLLocation(latitude: $1.latitude, longitude: $1.longitude).distance(from: origin)
		}
	}
}
