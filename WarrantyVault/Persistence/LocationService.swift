import Foundation
import CoreLocation


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


    var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
        }
    }


    var isDenied: Bool {
        manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
    }


    func requestCurrentLocation() async throws -> CLLocation {
        if isDenied {
            throw Failure.authorizationDenied
        }

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()


            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                cont.resume(throwing: Failure.authorizationDenied)
                self.continuation = nil
            }
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


        Task { @MainActor in
            guard self.continuation != nil else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                self.continuation?.resume(throwing: Failure.authorizationDenied)
                self.continuation = nil
            default:
                break
            }
        }
    }
}
