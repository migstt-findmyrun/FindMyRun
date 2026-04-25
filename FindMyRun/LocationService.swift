//
//  LocationService.swift
//  FindMyRun
//

import Foundation
import CoreLocation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var location: CLLocationCoordinate2D?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Starts location updates if permission is already granted. Never shows a prompt.
    /// Call this on app launch / view appear to silently resume location if the user
    /// already gave permission in a previous session.
    func startIfAuthorized() {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    /// Starts location updates if authorized, or shows the system permission prompt
    /// if status is undetermined. Call this only from an explicit user action.
    func requestPermission() {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        } else if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    // iOS 14+ unified callback
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    // iOS 13 fallback
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Fail silently — location is supplementary
    }
}
