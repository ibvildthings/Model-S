//
//  MapViewModel.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import Foundation
import MapKit
import Combine
import SwiftUI

@MainActor
class MapViewModel: NSObject, ObservableObject {
    @Published var pickupLocation: LocationPoint?
    @Published var destinationLocation: LocationPoint?
    @Published var region: MKCoordinateRegion
    @Published var routePolyline: MKPolyline?
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: RideRequestError?
    @Published var userLocation: CLLocation?

    private let locationManager = CLLocationManager()
    var onLocationUpdate: ((CLLocation) -> Void)?

    override init() {
        // Default region - San Francisco
        self.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters

        locationAuthorizationStatus = locationManager.authorizationStatus
        checkLocationAuthorization()
    }

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

    func updatePickupLocation(_ coordinate: CLLocationCoordinate2D, name: String? = nil) {
        pickupLocation = LocationPoint(coordinate: coordinate, name: name)
        updateRouteIfNeeded()
    }

    func updateDestinationLocation(_ coordinate: CLLocationCoordinate2D, name: String? = nil) {
        destinationLocation = LocationPoint(coordinate: coordinate, name: name)
        updateRouteIfNeeded()
    }

    func updateRouteFromMKRoute(_ route: MKRoute) {
        self.routePolyline = route.polyline

        // Center map on route
        let padding: Double = 50
        let rect = route.polyline.boundingMapRect
        let newRegion = MKCoordinateRegion(rect.insetBy(dx: -padding, dy: -padding))

        // Animate the region change
        Task { @MainActor in
            withAnimation {
                self.region = newRegion
            }
        }
    }

    private func updateRouteIfNeeded() {
        guard let pickup = pickupLocation,
              let destination = destinationLocation else {
            routePolyline = nil
            return
        }

        // Create a simple straight-line polyline as fallback
        let coordinates = [pickup.coordinate, destination.coordinate]
        routePolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
    }

    func centerOnUserLocation() {
        if let location = userLocation {
            let newRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )

            Task { @MainActor in
                withAnimation {
                    region = newRegion
                }
            }
        }
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
}

// MARK: - CLLocationManagerDelegate
extension MapViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        userLocation = location
        locationError = nil

        // Update region to user's location on first update
        if region.center.latitude == 37.7749 && region.center.longitude == -122.4194 {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }

        // Auto-set pickup location to user's location if not already set
        if pickupLocation == nil {
            updatePickupLocation(location.coordinate, name: "Current Location")
        }

        onLocationUpdate?(location)
    }

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

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = .locationUnavailable
    }
}
