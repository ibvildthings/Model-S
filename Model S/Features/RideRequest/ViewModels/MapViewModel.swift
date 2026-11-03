//
//  MapViewModel.swift
//  Model S
//
//  Presentation state for the rider map: pins, polylines, driver marker, region
//  and the user's GPS location. It owns no ride business logic – the
//  RideRequestCoordinator projects RideFlowController's state onto it.
//
//  Created by Pritesh Desai on 11/12/25.
//

import Foundation
import MapKit
import Combine
import SwiftUI

/// Route display mode for different ride phases
enum RouteDisplayMode {
    case approach    // Show driver → pickup route (blue)
    case activeRide  // Show pickup → destination route (purple)
}

@MainActor
class MapViewModel: NSObject, ObservableObject {
    // MARK: - Published State

    /// Pickup pin (projected from RideFlowController's state)
    @Published var pickupLocation: LocationPoint?

    /// Destination pin (projected from RideFlowController's state)
    @Published var destinationLocation: LocationPoint?

    /// Current map region (center and zoom level) - provider-agnostic
    @Published var region: MapRegion

    /// Route polyline to display on map (pickup to destination) - provider-agnostic coordinates
    @Published var routePolyline: [CLLocationCoordinate2D]?

    /// Driver's route polyline (driver location to pickup) - provider-agnostic coordinates
    @Published var driverRoutePolyline: [CLLocationCoordinate2D]?

    /// Current route display mode (approach vs active ride)
    @Published var routeDisplayMode: RouteDisplayMode = .approach

    /// User's current location
    @Published var userLocation: CLLocation?

    /// Driver's current location (from backend updates)
    @Published var driverLocation: CLLocationCoordinate2D?

    // MARK: - Private

    private let locationManager = CLLocationManager()

    /// Callback when user location updates (used by coordinator)
    var onLocationUpdate: ((CLLocation) -> Void)?

    // MARK: - Initialization

    override init() {
        // Try to use last known location, otherwise use default
        let initialCenter = CLLocationManager().location?.coordinate ?? MapConstants.defaultCenter

        self.region = MapRegion(
            center: initialCenter,
            span: MapCoordinateSpan(
                latitudeDelta: MapConstants.defaultSpan.latitudeDelta,
                longitudeDelta: MapConstants.defaultSpan.longitudeDelta
            )
        )

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = MapConstants.locationUpdateDistance

        checkLocationAuthorization()
    }

    deinit {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Location Permissions

    /// Starts location updates if authorized, or asks for permission
    private func checkLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Dispatch async to avoid blocking main thread
            DispatchQueue.main.async { [weak self] in
                self?.locationManager.startUpdatingLocation()
            }
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            AppLog.warning("⚠️ Location permission denied or restricted")
        @unknown default:
            break
        }
    }

    /// Stops tracking user location (call when map is no longer visible)
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Map Display Updates

    /// Shows the pickup → destination route and zooms to fit it
    func updateRoute(_ coordinates: [CLLocationCoordinate2D]) {
        routePolyline = coordinates
        zoom(toFit: coordinates)
    }

    /// Shows the driver → pickup route and zooms to fit it
    func updateDriverRouteCoordinates(_ coordinates: [CLLocationCoordinate2D]) {
        driverRoutePolyline = coordinates
        zoom(toFit: coordinates)
    }

    /// Switch to active ride mode (shows pickup → destination route)
    func switchToActiveRideRoute() {
        routeDisplayMode = .activeRide
        // The driver → pickup route is no longer needed
        driverRoutePolyline = nil
    }

    /// Switch to approach mode (shows driver → pickup route)
    func switchToApproachRoute() {
        routeDisplayMode = .approach
    }

    /// Clears the driver marker and driver route (back to booking state)
    func clearDriverLocation() {
        driverLocation = nil
        driverRoutePolyline = nil
        routeDisplayMode = .approach
    }

    /// Animates the region to the given value
    func setRegion(_ newRegion: MapRegion, animationDuration: TimeInterval = TimingConstants.mapAnimationDuration) {
        withAnimation(.easeInOut(duration: animationDuration)) {
            region = newRegion
        }
    }

    private func zoom(toFit coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else { return }
        // Default padding 2.0 ≈ 25% on each side
        setRegion(MapBounds(coordinates: coordinates).toRegion())
    }
}

// MARK: - CLLocationManagerDelegate

extension MapViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            let isFirstLocation = userLocation == nil
            userLocation = location

            // Center on the user the first time, unless pins are already shown
            if isFirstLocation && pickupLocation == nil && destinationLocation == nil {
                setRegion(
                    MapRegion(
                        center: location.coordinate,
                        span: MapCoordinateSpan(
                            latitudeDelta: MapConstants.defaultSpan.latitudeDelta,
                            longitudeDelta: MapConstants.defaultSpan.longitudeDelta
                        )
                    ),
                    animationDuration: 0.5
                )
            }

            onLocationUpdate?(location)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            checkLocationAuthorization()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            AppLog.warning("⚠️ Location error: \(error.localizedDescription)")
        }
    }
}
