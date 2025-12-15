import CoreLocation
import Combine

/// Manages location services for tree collection mapping
@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var locationName: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var error: LocationError?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Public Methods

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            error = .permissionDenied
            return
        }

        locationManager.requestLocation()
    }

    func reverseGeocode(_ location: CLLocation) async -> String? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                return formatPlacemark(placemark)
            }
        } catch {
            self.error = .geocodingFailed
        }
        return nil
    }

    // MARK: - Private Methods

    private func formatPlacemark(_ placemark: CLPlacemark) -> String {
        var components: [String] = []

        if let name = placemark.name, !name.isEmpty {
            // Avoid duplicating locality in name
            if name != placemark.locality {
                components.append(name)
            }
        }

        if let locality = placemark.locality {
            components.append(locality)
        }

        if let administrativeArea = placemark.administrativeArea {
            // Only add if different from locality
            if administrativeArea != placemark.locality {
                components.append(administrativeArea)
            }
        }

        if components.isEmpty, let country = placemark.country {
            components.append(country)
        }

        return components.joined(separator: ", ")
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            self.currentLocation = location
            self.locationName = await self.reverseGeocode(location)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.error = .permissionDenied
                case .locationUnknown:
                    self.error = .locationUnavailable
                default:
                    self.error = .unknown
                }
            } else {
                self.error = .unknown
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}

// MARK: - Location Error

enum LocationError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case geocodingFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location access was denied. Enable location in Settings to save tree locations."
        case .locationUnavailable:
            return "Unable to determine your current location."
        case .geocodingFailed:
            return "Unable to determine the name of this location."
        case .unknown:
            return "An unknown location error occurred."
        }
    }
}
