//
//  BackendModels.swift
//  Model S
//
//  Backend API response models
//

import Foundation
import CoreLocation

// MARK: - Ride Request/Response

struct RideRequestPayload: Codable {
    let pickup: LocationPayload
    let destination: LocationPayload
}

struct LocationPayload: Codable {
    let lat: Double
    let lng: Double
    let address: String?
}

struct RideResponse: Codable {
    let rideId: String
    let status: String
    let pickup: LocationPayload
    let destination: LocationPayload
    let driver: DriverResponse?
    let estimatedArrival: Double?
    let createdAt: String?
    let updatedAt: String?
}

struct DriverResponse: Codable {
    let id: String
    let name: String
    let vehicleType: String
    let vehicleModel: String
    let licensePlate: String
    let rating: Double
    let location: LocationResponse
    let available: Bool?
}

struct LocationResponse: Codable {
    let lat: Double
    let lng: Double
}

// MARK: - Error Response

struct ErrorResponse: Codable {
    let error: String
    let message: String
}

// MARK: - Conversion Extensions

extension LocationPayload {
    init(from locationPoint: LocationPoint) {
        self.lat = locationPoint.coordinate.latitude
        self.lng = locationPoint.coordinate.longitude
        self.address = locationPoint.name
    }

    func toLocationPoint() -> LocationPoint {
        LocationPoint(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            name: address
        )
    }
}

extension DriverResponse {
    func toDriverInfo(estimatedArrival: Double?) -> DriverInfo {
        DriverInfo(
            id: id,
            name: name,
            rating: rating,
            vehicleMake: vehicleType,
            vehicleModel: vehicleModel,
            vehicleColor: "Unknown", // Backend doesn't provide this yet
            licensePlate: licensePlate,
            photoURL: nil,
            phoneNumber: nil,
            currentLocation: CLLocationCoordinate2D(latitude: location.lat, longitude: location.lng),
            estimatedArrivalTime: estimatedArrival
        )
    }
}
