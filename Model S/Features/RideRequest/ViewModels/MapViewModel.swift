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

    /// Driver's current location (animated during ride)
    @Published var driverLocation: CLLocationCoordinate2D?

    // MARK: - Private Dependencies

    private let locationManager = CLLocationManager()

    /// Timer for animating driver movement
    private var driverAnimationTimer: Timer?

    /// Current progress along the route (0.0 to 1.0)
    private var routeProgress: Double = 0.0

    /// Track if we've already notified about approaching
    private var hasNotifiedApproaching = false

    /// Callback when user location updates (used by coordinator)
    var onLocationUpdate: ((CLLocation) -> Void)?

    /// Callback when driver reaches pickup location
    var onDriverReachedPickup: (() -> Void)?

    /// Callback when driver is approaching pickup (< 100m)
    var onDriverApproaching: (() -> Void)?

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

    // MARK: - Driver Animation

    /// Starts animating the driver's movement along the route to pickup location
    /// - Parameter startingCoordinate: Initial driver position (or nil to start from beginning of route)
    func startDriverAnimation(from startingCoordinate: CLLocationCoordinate2D? = nil) {
        guard let polyline = routePolyline else {
            print("❌ Cannot start driver animation: routePolyline is nil")
            return
        }

        print("🚗 Starting driver animation with \(polyline.pointCount) points")

        // Stop any existing animation
        stopDriverAnimation()

        // Reset approaching notification flag
        hasNotifiedApproaching = false

        // Set initial driver location
        if let start = startingCoordinate {
            driverLocation = start
            // Calculate initial progress based on starting position
            routeProgress = calculateProgress(for: start, on: polyline)
            print("🚗 Driver starting at custom position: \(start)")
        } else {
            // Start from beginning of route
            routeProgress = 0.0
            if polyline.pointCount > 0 {
                let points = polyline.points()
                driverLocation = points[0].coordinate
                print("🚗 Driver starting at beginning of route: \(points[0].coordinate)")
            }
        }

        // Create timer to update driver position every 0.1 seconds
        driverAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateDriverPosition()
        }

        print("🚗 Driver location set to: \(driverLocation?.latitude ?? 0), \(driverLocation?.longitude ?? 0)")
    }

    /// Stops the driver animation
    func stopDriverAnimation() {
        driverAnimationTimer?.invalidate()
        driverAnimationTimer = nil
    }

    /// Clears the driver location from the map
    func clearDriverLocation() {
        stopDriverAnimation()
        driverLocation = nil
        routeProgress = 0.0
        hasNotifiedApproaching = false
    }

    /// Updates the driver's position along the route
    private func updateDriverPosition() {
        guard let polyline = routePolyline else {
            stopDriverAnimation()
            return
        }

        // Increment progress (adjust speed here - 0.01 = slower, 0.05 = faster)
        routeProgress += 0.008

        // Check if we've reached the end
        if routeProgress >= 1.0 {
            routeProgress = 1.0
            stopDriverAnimation()

            // Set driver at pickup location
            if let pickup = pickupLocation {
                driverLocation = pickup.coordinate
            }

            print("✅ Driver reached pickup")
            // Notify that driver reached pickup
            onDriverReachedPickup?()
            return
        }

        // Calculate new position along polyline
        let points = polyline.points()
        let totalPoints = polyline.pointCount
        let currentIndex = Int(Double(totalPoints - 1) * routeProgress)

        if currentIndex < totalPoints {
            let newLocation = points[currentIndex].coordinate
            driverLocation = newLocation

            // Log every 50 updates to avoid spam
            if currentIndex % 50 == 0 {
                print("🚗 Driver position updated: progress=\(String(format: "%.1f", routeProgress * 100))%, location=\(newLocation.latitude),\(newLocation.longitude)")
            }

            // Check if driver is approaching (< 100m from pickup)
            if !hasNotifiedApproaching && isDriverNearPickup() {
                hasNotifiedApproaching = true
                print("🚗 Driver approaching pickup (< 100m)")
                onDriverApproaching?()
            }
        }
    }

    /// Calculates progress (0.0-1.0) for a given coordinate on the polyline
    private func calculateProgress(for coordinate: CLLocationCoordinate2D, on polyline: MKPolyline) -> Double {
        let points = polyline.points()
        let totalPoints = polyline.pointCount

        guard totalPoints > 0 else { return 0.0 }

        // Find closest point on polyline
        var closestIndex = 0
        var minDistance = Double.infinity

        for i in 0..<totalPoints {
            let point = points[i].coordinate
            let distance = self.distance(from: coordinate, to: point)
            if distance < minDistance {
                minDistance = distance
                closestIndex = i
            }
        }

        return Double(closestIndex) / Double(totalPoints - 1)
    }

    /// Calculate distance between two coordinates in meters
    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// Check if driver is close to pickup (within 100 meters)
    func isDriverNearPickup() -> Bool {
        guard let driver = driverLocation,
              let pickup = pickupLocation else { return false }

        return distance(from: driver, to: pickup.coordinate) < 100
    }
}

// MARK: - CLLocationManagerDelegate

extension MapViewModel: CLLocationManagerDelegate {
    /// Called when new location data is available
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        print("📍 User location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")

        userLocation = location
        locationError = nil

        // Update region to user's location on first update (if still at default)
        if region.center.latitude == MapConstants.defaultCenter.latitude &&
           region.center.longitude == MapConstants.defaultCenter.longitude {
            print("📍 Centering map on user's location for the first time")
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
        print("📍 Location authorization changed to: \(status.rawValue)")
        locationAuthorizationStatus = status

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 Location authorized, starting location updates")
            if CLLocationManager.locationServicesEnabled() {
                locationManager.startUpdatingLocation()
                locationError = nil
            } else {
                print("❌ Location services disabled")
                locationError = .locationServicesDisabled
            }
        case .denied, .restricted:
            print("❌ Location permission denied or restricted")
            locationError = .locationPermissionDenied
        case .notDetermined:
            print("⚠️ Location permission not determined")
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
