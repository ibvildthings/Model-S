//
//  AppStateStoreTests.swift
//  Model S Tests
//
//  Tests for AppStateStore global state management
//  Verifies state changes via actions work correctly
//

import XCTest
import CoreLocation
@testable import Model_S

@MainActor
final class AppStateStoreTests: XCTestCase {

    var stateStore: AppStateStore!

    override func setUp() {
        super.setUp()
        stateStore = AppStateStore()
    }

    override func tearDown() {
        stateStore = nil
        super.tearDown()
    }

    // MARK: - User State Tests

    func testSetUser() {
        // Given
        let user = User(
            id: "user123",
            name: "Test User",
            email: "test@example.com",
            phoneNumber: nil,
            isDriver: false
        )

        // When
        stateStore.dispatch(.setUser(user))

        // Then
        XCTAssertNotNil(stateStore.currentUser)
        XCTAssertEqual(stateStore.currentUser?.id, "user123")
        XCTAssertEqual(stateStore.currentUser?.name, "Test User")
        XCTAssertTrue(stateStore.isAuthenticated)
    }

    func testSetUserNil() {
        // Given - set a user first
        let user = User(
            id: "user123",
            name: "Test User",
            email: "test@example.com"
        )
        stateStore.dispatch(.setUser(user))
        XCTAssertTrue(stateStore.isAuthenticated)

        // When
        stateStore.dispatch(.setUser(nil))

        // Then
        XCTAssertNil(stateStore.currentUser)
        XCTAssertFalse(stateStore.isAuthenticated)
    }

    func testLogout() {
        // Given - set a user first
        let user = User(
            id: "user123",
            name: "Test User",
            email: "test@example.com"
        )
        stateStore.dispatch(.setUser(user))

        // When
        stateStore.dispatch(.logout)

        // Then
        XCTAssertNil(stateStore.currentUser)
        XCTAssertFalse(stateStore.isAuthenticated)
    }

    // MARK: - Location State Tests

    func testUpdateLocation() {
        // Given
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        // When
        stateStore.dispatch(.updateLocation(coordinate))

        // Then
        XCTAssertNotNil(stateStore.currentLocation)
        XCTAssertEqual(stateStore.currentLocation?.latitude, 37.7749)
        XCTAssertEqual(stateStore.currentLocation?.longitude, -122.4194)
    }

    func testUpdateLocationNil() {
        // Given - set location first
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        stateStore.dispatch(.updateLocation(coordinate))

        // When
        stateStore.dispatch(.updateLocation(nil))

        // Then
        XCTAssertNil(stateStore.currentLocation)
    }

    func testSetLocationAuthorization() {
        // When
        stateStore.dispatch(.setLocationAuthorization(true))

        // Then
        XCTAssertTrue(stateStore.locationAuthorized)

        // When
        stateStore.dispatch(.setLocationAuthorization(false))

        // Then
        XCTAssertFalse(stateStore.locationAuthorized)
    }

    // MARK: - Configuration State Tests

    func testSetMapProvider() {
        // When
        stateStore.dispatch(.setMapProvider(.google))

        // Then
        XCTAssertEqual(stateStore.mapProvider, .google)

        // When
        stateStore.dispatch(.setMapProvider(.apple))

        // Then
        XCTAssertEqual(stateStore.mapProvider, .apple)
    }

    func testSetDriverMode() {
        // When
        stateStore.dispatch(.setDriverMode(true))

        // Then
        XCTAssertTrue(stateStore.isDriverMode)

        // When
        stateStore.dispatch(.setDriverMode(false))

        // Then
        XCTAssertFalse(stateStore.isDriverMode)
    }

    // MARK: - Network State Tests

    func testSetNetworkAvailability() {
        // When
        stateStore.dispatch(.setNetworkAvailability(false))

        // Then
        XCTAssertFalse(stateStore.isNetworkAvailable)

        // When
        stateStore.dispatch(.setNetworkAvailability(true))

        // Then
        XCTAssertTrue(stateStore.isNetworkAvailable)
    }

    // MARK: - Ride State Tests

    func testUpdateRideState() {
        // Given
        let pickup = LocationPoint(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            name: "Pickup"
        )
        let destination = LocationPoint(
            coordinate: CLLocationCoordinate2D(latitude: 37.8049, longitude: -122.3994),
            name: "Destination"
        )

        // When
        stateStore.dispatch(.updateRideState(.selectingLocations(pickup: pickup, destination: nil)))

        // Then
        if case .selectingLocations = stateStore.currentRideState {
            // Success
        } else {
            XCTFail("Expected selectingLocations state")
        }
    }

    func testHasActiveRide() {
        // Given - idle state
        XCTAssertFalse(stateStore.hasActiveRide)

        // Given
        let pickup = LocationPoint(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            name: "Pickup"
        )
        let destination = LocationPoint(
            coordinate: CLLocationCoordinate2D(latitude: 37.8049, longitude: -122.3994),
            name: "Destination"
        )
        let driver = DriverInfo(
            id: "driver123",
            name: "John Doe",
            rating: 4.8,
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            vehicleColor: "Silver",
            licensePlate: "ABC123",
            photoURL: nil,
            phoneNumber: nil,
            currentLocation: nil,
            estimatedArrivalTime: 300
        )

        // When - driver en route (active ride)
        stateStore.dispatch(.updateRideState(.driverEnRoute(
            rideId: "ride123",
            driver: driver,
            eta: 300,
            pickup: pickup,
            destination: destination
        )))

        // Then
        XCTAssertTrue(stateStore.hasActiveRide)
        XCTAssertEqual(stateStore.currentRideId, "ride123")
        XCTAssertNotNil(stateStore.currentDriver)
        XCTAssertEqual(stateStore.currentDriver?.name, "John Doe")
    }

    // MARK: - Logout Resets Ride State

    func testLogoutResetsRideState() {
        // Given - user with active ride
        let user = User(
            id: "user123",
            name: "Test User",
            email: "test@example.com"
        )
        stateStore.dispatch(.setUser(user))

        let pickup = LocationPoint(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            name: "Pickup"
        )
        stateStore.dispatch(.updateRideState(.selectingLocations(pickup: pickup, destination: nil)))

        // When
        stateStore.dispatch(.logout)

        // Then
        XCTAssertFalse(stateStore.isAuthenticated)
        if case .idle = stateStore.currentRideState {
            // Success - ride state reset to idle
        } else {
            XCTFail("Expected ride state to reset to idle on logout")
        }
    }
}
