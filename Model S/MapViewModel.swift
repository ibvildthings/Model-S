//
//  MapViewModel.swift
//  Model S
//
//  Manages map display state and user location tracking.
//  This ViewModel is presentation-focused - it only handles what the map shows,
//  not business logic about rides.
//
//  Created by Pritesh Desai on 11/12/25.
//

import Foundation
import MapKit
import Combine
import SwiftUI

/// Manages map display state, user location, and map region
/// Note: This does NOT manage ride request business logic - see RideRequestViewModel for that
@MainActor
class MapViewModel: NSObject, ObservableObject {
    // MARK: - Published State

    /// Location to show pickup pin (presentation state only)
    @Published var pickupLocation: LocationPoint?

    /// Location to show destination pin (presentation state only)
    @Published var destinationLocation: LocationPoint?

    /// Current map region (center and zoom level)
    @Published var region: MKCoordinateRegion

    /// Route polyline to display on map
    @Published var routePolyline: MKPolyline?

    /// Current location permission status
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Location-related errors
    @Published var locationError: RideRequestError?

    /// User's current location
    @Published var userLocation: CLLocation?

    // MARK: - Private Dependencies

    private let locationManager = CLLocationManager()

    /// Callback when user location updates (used by coordinator)
    var onLocationUpdate: ((CLLocation) -> Void)?

    // MARK: - Initialization

    override init() {
        // Start with default map region (configured in Constants)
        self.region = MKCoordinateRegion(
            center: MapConstants.defaultCenter,
            span: MapConstants.defaultSpan
        )

        super.init()

        // Configure location manager
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = MapConstants.locationUpdateDistance

        // Check current authorization
        locationAuthorizationStatus = locationManager.authorizationStatus
        checkLocationAuthorization()
    }

    // MARK: - Location Permissions

    /// Requests location permission from the user
    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationError = .locationPermissionDenied
        default:
            break
        }
    }

    /// Checks current authorization status and starts location updates if authorized
    private func checkLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if CLLocationManager.locationServicesEnabled() {
                locationManager.startUpdatingLocation()
            } else {
                locationError = .locationServicesDisabled
            }
        case .denied, .restricted:
            locationError = .locationPermissionDenied
        case .notDetermined:
            requestLocationPermission()
        @unknown default:
            break
        }
    }

    // MARK: - Map Display Updates

    /// Updates the pickup pin location on the map
    /// - Parameters:
    ///   - coordinate: The coordinate to place the pin
    ///   - name: Optional name/address for the location
    func updatePickupLocation(_ coordinate: CLLocationCoordinate2D, name: String? = nil) {
        pickupLocation = LocationPoint(coordinate: coordinate, name: name)
    }

    /// Updates the destination pin location on the map
    /// - Parameters:
    ///   - coordinate: The coordinate to place the pin
    ///   - name: Optional name/address for the location
    func updateDestinationLocation(_ coordinate: CLLocationCoordinate2D, name: String? = nil) {
        destinationLocation = LocationPoint(coordinate: coordinate, name: name)
    }

    /// Updates the route polyline and centers map on the route
    /// - Parameter route: The MKRoute to display
    func updateRouteFromMKRoute(_ route: MKRoute) {
        self.routePolyline = route.polyline

        // Center map on route with padding
        let padding: Double = 50
        let rect = route.polyline.boundingMapRect
        let newRegion = MKCoordinateRegion(rect.insetBy(dx: -padding, dy: -padding))

        // Animate the region change for smooth transition
        Task { @MainActor in
            withAnimation(.easeInOut(duration: TimingConstants.mapAnimationDuration)) {
                self.region = newRegion
            }
        }
    }

    /// Centers the map on the user's current location
    func centerOnUserLocation() {
        if let location = userLocation {
            let newRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MapConstants.defaultSpan
            )

            Task { @MainActor in
                withAnimation(.easeInOut(duration: TimingConstants.mapAnimationDuration)) {
                    region = newRegion
                }
            }
        }
    }

    /// Stops tracking user location (call when map is no longer visible)
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
}

// MARK: - CLLocationManagerDelegate

extension MapViewModel: CLLocationManagerDelegate {
    /// Called when new location data is available
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        userLocation = location
        locationError = nil

        // Update region to user's location on first update (if still at default)
        if region.center.latitude == MapConstants.defaultCenter.latitude &&
           region.center.longitude == MapConstants.defaultCenter.longitude {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MapConstants.defaultSpan
            )
        }

        // Notify coordinator about location update
        onLocationUpdate?(location)
    }

    /// Called when location authorization status changes
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        locationAuthorizationStatus = status

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if CLLocationManager.locationServicesEnabled() {
                locationManager.startUpdatingLocation()
                locationError = nil
            } else {
                locationError = .locationServicesDisabled
            }
        case .denied, .restricted:
            locationError = .locationPermissionDenied
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    /// Called when location manager fails to get location
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = .locationUnavailable
    }
}
