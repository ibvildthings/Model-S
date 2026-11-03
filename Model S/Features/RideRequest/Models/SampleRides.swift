//
//  SampleRides.swift
//  Model S
//
//  San Francisco landmark pairs used by the "Quick Test" button in debug builds.
//  They match the locations in backend/config/geoConfig.js so the simulated
//  drivers are nearby.
//

#if DEBUG
import CoreLocation

enum SampleRides {
    struct Ride {
        let pickup: LocationPoint
        let destination: LocationPoint
    }

    private static func ride(
        _ pickupName: String, _ pickupLat: Double, _ pickupLng: Double,
        _ destinationName: String, _ destinationLat: Double, _ destinationLng: Double
    ) -> Ride {
        Ride(
            pickup: LocationPoint(
                coordinate: CLLocationCoordinate2D(latitude: pickupLat, longitude: pickupLng),
                name: pickupName
            ),
            destination: LocationPoint(
                coordinate: CLLocationCoordinate2D(latitude: destinationLat, longitude: destinationLng),
                name: destinationName
            )
        )
    }

    static let all: [Ride] = [
        // Commute patterns
        ride("Mission Dolores", 37.7599, -122.4148, "Transamerica Pyramid", 37.7952, -122.4028),
        ride("Haight-Ashbury", 37.7692, -122.4481, "Union Square", 37.7879, -122.4074),
        ride("Salesforce Tower", 37.7897, -122.3969, "Castro District", 37.7609, -122.4350),
        // Airport / transit
        ride("Alamo Square", 37.7763, -122.4351, "San Francisco International Airport", 37.6213, -122.3790),
        ride("Ferry Building", 37.7955, -122.3937, "Civic Center BART", 37.7764, -122.4168),
        // Tourist
        ride("Fisherman's Wharf", 37.8080, -122.4177, "Golden Gate Bridge", 37.8199, -122.4783),
        ride("North Beach", 37.7989, -122.4117, "Pier 39", 37.8024, -122.4058),
        ride("Ghirardelli Square", 37.8085, -122.4180, "Twin Peaks", 37.7544, -122.4477),
        // Venues / culture
        ride("Oracle Park", 37.7786, -122.3893, "Chase Center", 37.7680, -122.3875),
        ride("Chinatown", 37.7941, -122.4078, "Palace of Fine Arts", 37.8025, -122.4382),
    ]
}
#endif
