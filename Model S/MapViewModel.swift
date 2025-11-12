//
//  MapViewModel.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import Foundation
import MapKit
import Combine

class MapViewModel: NSObject, ObservableObject {
    @Published var pickupLocation: LocationPoint?
    @Published var destinationLocation: LocationPoint?
    @Published var region: MKCoordinateRegion
    @Published var routePolyline: MKPolyline?

    private let locationManager = CLLocationManager()

    override init() {
        // Default region - San Francisco
        self.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        requestLocationPermission()
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func updatePickupLocation(_ coordinate: CLLocationCoordinate2D, name: String? = nil) {
        pickupLocation = LocationPoint(coordinate: coordinate, name: name)
        updateRouteIfNeeded()
    }

    func updateDestinationLocation(_ coordinate: CLLocationCoordinate2D, name: String? = nil) {
        destinationLocation = LocationPoint(coordinate: coordinate, name: name)
        updateRouteIfNeeded()
    }

    private func updateRouteIfNeeded() {
        guard let pickup = pickupLocation,
              let destination = destinationLocation else {
            routePolyline = nil
            return
        }

        // Create a simple straight-line polyline for now (fake route)
        // In a real app, you'd use MKDirections API
        let coordinates = [pickup.coordinate, destination.coordinate]
        routePolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
    }

    func centerOnUserLocation() {
        if let location = locationManager.location {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension MapViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Update region to user's location
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )

        // Auto-set pickup location to user's location if not already set
        if pickupLocation == nil {
            updatePickupLocation(location.coordinate, name: "Current Location")
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}
