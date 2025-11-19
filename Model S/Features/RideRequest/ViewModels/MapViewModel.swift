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

/// Route display mode for different ride phases
enum RouteDisplayMode {
    case approach    // Show driver → pickup route (blue)
    case activeRide  // Show pickup → destination route (purple)
}

/// Manages map display state, user location, and map region
/// Note: This does NOT manage ride request business logic - see RideRequestViewModel for that
@MainActor
class MapViewModel: NSObject, ObservableObject {
    // MARK: - Published State

    /// Location to show pickup pin (presentation state only)
    @Published var pickupLocation: LocationPoint?

    /// Location to show destination pin (presentation state only)
    @Published var destinationLocation: LocationPoint?

    /// Current map region (center and zoom level) - provider-agnostic
    @Published var region: MapRegion

    /// Route polyline to display on map (pickup to destination) - provider-agnostic coordinates
    @Published var routePolyline: [CLLocationCoordinate2D]?

    /// Driver's route polyline (driver location to pickup) - provider-agnostic coordinates
    @Published var driverRoutePolyline: [CLLocationCoordinate2D]?

    /// Current route display mode (approach vs active ride)
    @Published var routeDisplayMode: RouteDisplayMode = .approach

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

    /// Animation speed (progress increment per update) - calculated from ETA
    private var animationSpeed: Double = 0.008 // Default fallback

    /// Track if we've already notified about approaching
    private var hasNotifiedApproaching = false

    /// Counter for viewport updates (update every N frames to avoid excessive zooming)
    private var viewportUpdateCounter = 0

    /// Enable dynamic viewport adjustment during driver animation
    private var shouldDynamicallyAdjustViewport = false

    /// Target point for viewport adjustment (pickup or destination)
    private enum ViewportTarget {
        case pickup
        case destination
    }
    private var currentViewportTarget: ViewportTarget = .pickup

    /// Callback when user location updates (used by coordinator)
    var onLocationUpdate: ((CLLocation) -> Void)?

    // REMOVED: Animation callbacks no longer trigger state changes
    // Backend polling is now the single source of truth for ride state
    // Animation is purely visual and doesn't control state transitions

    // MARK: - Initialization

    override init() {
        // Try to use last known location, otherwise use default
        let lastLocation = CLLocationManager().location
        let initialCenter = lastLocation?.coordinate ?? MapConstants.defaultCenter

        // Start with user's location or default region (using provider-agnostic MapRegion)
        self.region = MapRegion(
            center: initialCenter,
            span: MapCoordinateSpan(
                latitudeDelta: MapConstants.defaultSpan.latitudeDelta,
                longitudeDelta: MapConstants.defaultSpan.longitudeDelta
            )
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

    deinit {
        // Clean up timer to prevent memory leaks
        driverAnimationTimer?.invalidate()
        driverAnimationTimer = nil
        locationManager.stopUpdatingLocation()
        print("🧹 MapViewModel deallocated, cleaned up resources")
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
            // Start updating - if location services are disabled, didFailWithError will be called
            locationManager.startUpdatingLocation()
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
    /// - Parameter coordinates: Array of coordinates defining the route
    func updateRoute(_ coordinates: [CLLocationCoordinate2D]) {
        self.routePolyline = coordinates

        // Center map on route with generous padding to show both pickup and destination clearly
        let bounds = MapBounds(coordinates: coordinates)
        let newRegion = bounds.toRegion() // Uses default padding (2.0 = ~25% on each side)

        print("📍 Zooming to show route: center=\(newRegion.center), span=\(newRegion.span)")

        // Animate the region change for smooth transition
        Task { @MainActor in
            withAnimation(.easeInOut(duration: TimingConstants.mapAnimationDuration)) {
                self.region = newRegion
            }
        }
    }

    /// Updates the route polyline and centers map on the route (backwards compatibility)
    /// - Parameter route: The MKRoute to display (converts to coordinates)
    func updateRouteFromMKRoute(_ route: MKRoute) {
        // Extract coordinates from MKRoute for backwards compatibility
        let polyline = route.polyline
        var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))

        updateRoute(coordinates)
    }

    /// Updates the driver's route polyline (from driver location to pickup)
    /// - Parameter coordinates: Array of coordinates defining the driver's route
    func updateDriverRouteCoordinates(_ coordinates: [CLLocationCoordinate2D]) {
        self.driverRoutePolyline = coordinates

        // Center map on driver route with generous padding to show driver and pickup
        let bounds = MapBounds(coordinates: coordinates)
        let newRegion = bounds.toRegion() // Uses default padding (2.0 = ~25% on each side)

        print("🚗 Zooming to show driver route: center=\(newRegion.center), span=\(newRegion.span)")

        // Animate the region change for smooth transition
        Task { @MainActor in
            withAnimation(.easeInOut(duration: TimingConstants.mapAnimationDuration)) {
                self.region = newRegion
            }
        }
    }

    /// Updates the driver's route polyline (from driver location to pickup) - backwards compatibility
    /// - Parameter route: The MKRoute for the driver's path to pickup (converts to coordinates)
    func updateDriverRoute(_ route: MKRoute) {
        // Extract coordinates from MKRoute for backwards compatibility
        let polyline = route.polyline
        var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))

        updateDriverRouteCoordinates(coordinates)
    }

    /// Centers the map on the user's current location
    func centerOnUserLocation() {
        if let location = userLocation {
            let newRegion = MapRegion(
                center: location.coordinate,
                span: MapCoordinateSpan(
                    latitudeDelta: MapConstants.defaultSpan.latitudeDelta,
                    longitudeDelta: MapConstants.defaultSpan.longitudeDelta
                )
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
    /// - Parameters:
    ///   - startingCoordinate: Initial driver position (or nil to start from beginning of route)
    ///   - estimatedDuration: Backend's ETA in seconds (used to sync animation speed)
    func startDriverAnimation(from startingCoordinate: CLLocationCoordinate2D? = nil, estimatedDuration: TimeInterval? = nil) {
        // Use driver's route (driver to pickup) if available, otherwise fall back to main route
        guard let coordinates = driverRoutePolyline ?? routePolyline else {
            print("❌ Cannot start driver animation: no route available")
            return
        }

        // Calculate animation speed based on backend ETA
        if let eta = estimatedDuration, eta > 0 {
            // Update interval is 0.1 seconds
            let updateInterval: TimeInterval = 0.1
            let totalUpdates = eta / updateInterval
            animationSpeed = 1.0 / totalUpdates
            print("🎯 Animation synchronized with backend ETA: \(eta)s, speed: \(animationSpeed)")
        } else {
            // Fallback to default speed if no ETA provided
            animationSpeed = 0.008
            print("⚠️ No ETA provided, using default animation speed")
        }

        print("🚗 Starting driver animation with \(coordinates.count) points (using \(driverRoutePolyline != nil ? "driver route" : "main route"))")

        // Stop any existing animation
        stopDriverAnimation()

        // Reset approaching notification flag
        hasNotifiedApproaching = false

        // Set initial driver location
        if let start = startingCoordinate {
            driverLocation = start
            // Calculate initial progress based on starting position
            routeProgress = calculateProgress(for: start, on: coordinates)
            print("🚗 Driver starting at custom position: \(start)")
        } else {
            // Start from beginning of route
            routeProgress = 0.0
            if !coordinates.isEmpty {
                driverLocation = coordinates[0]
                print("🚗 Driver starting at beginning of route: \(coordinates[0])")
            }
        }

        // Enable dynamic viewport adjustment
        shouldDynamicallyAdjustViewport = true
        viewportUpdateCounter = 0

        // Adjust viewport to include driver, pickup, and destination
        adjustViewportForDriver()

        // Create timer to update driver position every 0.1 seconds
        driverAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDriverPosition()
            }
        }

        print("🚗 Driver location set to: \(driverLocation?.latitude ?? 0), \(driverLocation?.longitude ?? 0)")
    }

    /// Adjusts the map viewport to include driver, pickup, and destination (initial setup)
    private func adjustViewportForDriver() {
        guard let driver = driverLocation else { return }

        var coordinates: [CLLocationCoordinate2D] = [driver]

        if let pickup = pickupLocation {
            coordinates.append(pickup.coordinate)
        }
        if let destination = destinationLocation {
            coordinates.append(destination.coordinate)
        }

        // Use MapBounds to calculate optimal region
        let bounds = MapBounds(coordinates: coordinates)
        let newRegion = bounds.toRegion() // Uses default padding (2.0 = ~25% on each side)

        print("📍 Adjusting viewport to include driver: center=\(newRegion.center), span=\(newRegion.span)")

        withAnimation(.easeInOut(duration: 0.8)) {
            region = newRegion
        }
    }

    /// Switch viewport target (call when transitioning from pickup to destination phase)
    func switchToDestinationTracking() {
        currentViewportTarget = .destination
        print("📍 Switched viewport tracking to destination")
    }

    /// Switch to active ride mode (shows pickup → destination route)
    func switchToActiveRideRoute() {
        routeDisplayMode = .activeRide
        // Clear the driver route polyline as it's no longer needed
        driverRoutePolyline = nil
        print("🛣️ Switched to active ride route (pickup → destination)")
    }

    /// Switch to approach mode (shows driver → pickup route)
    func switchToApproachRoute() {
        routeDisplayMode = .approach
        print("🛣️ Switched to approach route (driver → pickup)")
    }

    /// Dynamically adjusts viewport to keep driver and target in frame (zooms in as they get closer)
    private func adjustViewportForDriverAndPickup() {
        guard let driver = driverLocation else { return }

        // Determine target based on current phase
        let targetCoordinate: CLLocationCoordinate2D

        switch currentViewportTarget {
        case .pickup:
            guard let pickup = pickupLocation else { return }
            targetCoordinate = pickup.coordinate

        case .destination:
            guard let destination = destinationLocation else { return }
            targetCoordinate = destination.coordinate
        }

        // Calculate distance between driver and target
        let driverCL = CLLocation(latitude: driver.latitude, longitude: driver.longitude)
        let targetCL = CLLocation(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude)
        let distance = driverCL.distance(from: targetCL) // in meters

        // Calculate center point between driver and target
        let center = CLLocationCoordinate2D(
            latitude: (driver.latitude + targetCoordinate.latitude) / 2,
            longitude: (driver.longitude + targetCoordinate.longitude) / 2
        )

        // Dynamic padding based on distance - zooms in as driver gets closer
        // When far: more padding, When close: less padding for tighter view
        let paddingMultiplier: Double
        if distance > 5000 { // > 5km
            paddingMultiplier = 2.5
        } else if distance > 2000 { // 2-5km
            paddingMultiplier = 2.2
        } else if distance > 500 { // 500m-2km
            paddingMultiplier = 2.0
        } else { // < 500m
            paddingMultiplier = 1.8 // Tighter zoom when very close
        }

        // Calculate span based on distance
        let latDelta = abs(driver.latitude - targetCoordinate.latitude) * paddingMultiplier
        let lonDelta = abs(driver.longitude - targetCoordinate.longitude) * paddingMultiplier

        let span = MapCoordinateSpan(
            latitudeDelta: max(latDelta, 0.005), // Minimum span for close proximity
            longitudeDelta: max(lonDelta, 0.005)
        )

        // Smooth animation for viewport changes
        withAnimation(.easeInOut(duration: 1.0)) {
            region = MapRegion(center: center, span: span)
        }
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
        driverRoutePolyline = nil
        routeProgress = 0.0
        animationSpeed = 0.008 // Reset to default
        hasNotifiedApproaching = false
        shouldDynamicallyAdjustViewport = false
        viewportUpdateCounter = 0
        currentViewportTarget = .pickup // Reset to pickup for next ride
        routeDisplayMode = .approach // Reset to approach mode for next ride
    }

    /// Updates the driver's position along the route
    private func updateDriverPosition() {
        // Use driver's route if available, otherwise fall back to main route
        guard let coordinates = driverRoutePolyline ?? routePolyline else {
            stopDriverAnimation()
            return
        }

        // Increment progress using calculated speed (synchronized with backend ETA)
        routeProgress += animationSpeed

        // Check if we've reached the end
        if routeProgress >= 1.0 {
            routeProgress = 1.0
            stopDriverAnimation()

            // Set driver at pickup location
            if let pickup = pickupLocation {
                driverLocation = pickup.coordinate
            }

            print("✅ Driver animation reached pickup (visual only)")
            // Animation complete - backend polling will handle state transition
            return
        }

        // Calculate new position along polyline
        let totalPoints = coordinates.count
        let currentIndex = Int(Double(totalPoints - 1) * routeProgress)

        if currentIndex < totalPoints {
            let newLocation = coordinates[currentIndex]
            driverLocation = newLocation

            // Log every 50 updates to avoid spam
            if currentIndex % 50 == 0 {
                print("🚗 Driver position updated: progress=\(String(format: "%.1f", routeProgress * 100))%, location=\(newLocation.latitude),\(newLocation.longitude)")
            }

            // Dynamically adjust viewport every 20 frames (every 2 seconds) to keep driver and pickup in view
            if shouldDynamicallyAdjustViewport {
                viewportUpdateCounter += 1
                if viewportUpdateCounter >= 20 {
                    viewportUpdateCounter = 0
                    adjustViewportForDriverAndPickup()
                }
            }

            // Check if driver is approaching (< 100m from pickup) - for logging only
            if !hasNotifiedApproaching && isDriverNearPickup() {
                hasNotifiedApproaching = true
                print("🚗 Driver animation approaching pickup (< 100m, visual only)")
                // Backend polling will handle state transition
            }
        }
    }

    /// Calculates progress (0.0-1.0) for a given coordinate on the polyline
    private func calculateProgress(for coordinate: CLLocationCoordinate2D, on coordinates: [CLLocationCoordinate2D]) -> Double {
        let totalPoints = coordinates.count

        guard totalPoints > 0 else { return 0.0 }

        // Find closest point on polyline
        var closestIndex = 0
        var minDistance = Double.infinity

        for (i, point) in coordinates.enumerated() {
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
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            print("📍 User location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")

            let isFirstLocation = userLocation == nil
            userLocation = location
            locationError = nil

            // Update region to user's location on first update only if we don't have pins yet
            if isFirstLocation && pickupLocation == nil && destinationLocation == nil {
                print("📍 Centering map on user's location for the first time")
                withAnimation(.easeInOut(duration: 0.5)) {
                    region = MapRegion(
                        center: location.coordinate,
                        span: MapCoordinateSpan(
                            latitudeDelta: MapConstants.defaultSpan.latitudeDelta,
                            longitudeDelta: MapConstants.defaultSpan.longitudeDelta
                        )
                    )
                }
            }

            // Notify coordinator about location update
            onLocationUpdate?(location)
        }
    }

    /// Called when location authorization status changes
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            print("📍 Location authorization changed to: \(status.rawValue)")
            locationAuthorizationStatus = status

            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                print("📍 Location authorized, starting location updates")
                // Start updating - if location services are disabled, didFailWithError will be called
                locationManager.startUpdatingLocation()
                locationError = nil
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
    }

    /// Called when location manager fails to get location
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationError = .locationUnavailable
        }
    }
}
