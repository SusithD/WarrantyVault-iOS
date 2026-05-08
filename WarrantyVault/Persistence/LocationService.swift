import Foundation
import CoreLocation

/// One-shot wrapper around `CLLocationManager`. Asks for `whenInUse`
/// authorization on first call, returns the user's current location once,
/// then stops. Never tracks continuously.
@MainActor
final class LocationService: NSObject {

    static let shared = LocationService()

    enum Failure: Error {
        case authorizationDenied
        case unavailable
        case timedOut
        case underlying(Error)
    }

    private let manager: CLLocationManager
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        self.manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Whether the user has authorised When-In-Use access.
    var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
        }
    }

    /// Whether the user has explicitly denied access (so the UI can deep-link to Settings).
    var isDenied: Bool {
        manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
    }

    /// Asks for one location fix. Triggers the system permission alert on the
    /// very first call. Throws if the user denied access or no fix was found.
    func requestCurrentLocation() async throws -> CLLocation {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        if isDenied {
            throw Failure.authorizationDenied
        }

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            manager.requestLocation()
        }
    }
}

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else {
                self.continuation?.resume(throwing: Failure.unavailable)
                self.continuation = nil
                return
            }
            self.continuation?.resume(returning: location)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(throwing: Failure.underlying(error))
            self.continuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // No-op: we don't auto-retry on auth changes. The next call to
        // `requestCurrentLocation()` will see the new status.
    }
}
