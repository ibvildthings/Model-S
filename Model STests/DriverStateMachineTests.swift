//
//  DriverStateMachineTests.swift
//  Model S Tests
//
//  Tests for DriverStateMachine state transitions
//  Verifies that only valid state transitions are allowed for driver flow
//

import XCTest
import CoreLocation
@testable import Model_S

final class DriverStateMachineTests: XCTestCase {

    // MARK: - Helper Properties

    var sampleStats: DriverStats {
        DriverStats(
            onlineTime: 3600,
            completedRides: 10,
            totalEarnings: 250.0,
            acceptanceRate: 95.0,
            rating: 4.8
        )
    }

    var samplePickup: LocationPoint {
        LocationPoint(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), name: "San Francisco")
    }

    var sampleDestination: LocationPoint {
        LocationPoint(coordinate: CLLocationCoordinate2D(latitude: 37.8049, longitude: -122.3994), name: "Oakland")
    }

    var sampleRideRequest: RideRequest {
        RideRequest(
            rideId: "ride123",
            pickup: samplePickup,
            destination: sampleDestination,
            distance: 5000,
            estimatedEarnings: 15.50,
            expiresAt: Date().addingTimeInterval(30)
        )
    }

    var sampleActiveRide: ActiveRide {
        ActiveRide(
            rideId: "ride123",
            pickup: samplePickup,
            destination: sampleDestination,
            passenger: ActiveRide.PassengerInfo(name: "Jane Doe", rating: 4.9, phoneNumber: "+14155551234"),
            currentDriverLocation: samplePickup,
            estimatedArrival: 600,
            distanceToDestination: 5000
        )
    }

    var sampleRideSummary: RideSummary {
        RideSummary(
            rideId: "ride123",
            pickup: samplePickup,
            destination: sampleDestination,
            distance: 5000,
            duration: 600,
            earnings: 15.50,
            passengerRating: 5.0,
            completedAt: Date()
        )
    }

    // MARK: - Valid Transitions from Offline

    func testTransition_offlineToLoggingIn_isValid() {
        let currentState = DriverState.offline
        let nextState = DriverState.loggingIn

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
        if case .loggingIn = result! {
            XCTAssert(true)
        } else {
            XCTFail("Expected loggingIn state")
        }
    }

    func testTransition_offlineToOnline_isInvalid() {
        let currentState = DriverState.offline
        let nextState = DriverState.online(stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNil(result)
    }

    // MARK: - Valid Transitions from LoggingIn

    func testTransition_loggingInToOnline_isValid() {
        let currentState = DriverState.loggingIn
        let nextState = DriverState.online(stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
        if case .online = result! {
            XCTAssert(true)
        } else {
            XCTFail("Expected online state")
        }
    }

    func testTransition_loggingInToError_isValid() {
        let currentState = DriverState.loggingIn
        let nextState = DriverState.error(message: "Login failed", previousState: currentState)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
        if case .error = result! {
            XCTAssert(true)
        } else {
            XCTFail("Expected error state")
        }
    }

    func testTransition_loggingInToRideOffered_isInvalid() {
        let currentState = DriverState.loggingIn
        let nextState = DriverState.rideOffered(request: sampleRideRequest, stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNil(result)
    }

    // MARK: - Valid Transitions from Online

    func testTransition_onlineToRideOffered_isValid() {
        let currentState = DriverState.online(stats: sampleStats)
        let nextState = DriverState.rideOffered(request: sampleRideRequest, stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
        if case .rideOffered = result! {
            XCTAssert(true)
        } else {
            XCTFail("Expected rideOffered state")
        }
    }

    func testTransition_onlineToOffline_isValid() {
        let currentState = DriverState.online(stats: sampleStats)
        let nextState = DriverState.offline

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
        if case .offline = result! {
            XCTAssert(true)
        } else {
            XCTFail("Expected offline state")
        }
    }

    func testTransition_onlineToError_isValid() {
        let currentState = DriverState.online(stats: sampleStats)
        let nextState = DriverState.error(message: "Connection lost", previousState: currentState)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
    }

    // MARK: - Valid Transitions from RideOffered

    func testTransition_rideOfferedToHeadingToPickup_isValid() {
        // Driver accepted the ride
        let currentState = DriverState.rideOffered(request: sampleRideRequest, stats: sampleStats)
        let nextState = DriverState.headingToPickup(ride: sampleActiveRide, stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
        if case .headingToPickup = result! {
            XCTAssert(true)
        } else {
            XCTFail("Expected headingToPickup state")
        }
    }

    func testTransition_rideOfferedToOnline_isValid() {
        // Driver rejected or offer expired
        let currentState = DriverState.rideOffered(request: sampleRideRequest, stats: sampleStats)
        let nextState = DriverState.online(stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
        if case .online = result! {
            XCTAssert(true)
        } else {
            XCTFail("Expected online state")
        }
    }

    func testTransition_rideOfferedToError_isValid() {
        let currentState = DriverState.rideOffered(request: sampleRideRequest, stats: sampleStats)
        let nextState = DriverState.error(message: "Network error", previousState: currentState)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
    }

    // MARK: - Valid Transitions from HeadingToPickup

    func testTransition_headingToPickupToArrivedAtPickup_isValid() {
        let currentState = DriverState.headingToPickup(ride: sampleActiveRide, stats: sampleStats)
        let nextState = DriverState.arrivedAtPickup(ride: sampleActiveRide, stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
        if case .arrivedAtPickup = result! {
            XCTAssert(true)
        } else {
            XCTFail("Expected arrivedAtPickup state")
        }
    }

    func testTransition_headingToPickupToOnline_isValid() {
        // Ride was cancelled
        let currentState = DriverState.headingToPickup(ride: sampleActiveRide, stats: sampleStats)
        let nextState = DriverState.online(stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
    }

    func testTransition_headingToPickupToError_isValid() {
        let currentState = DriverState.headingToPickup(ride: sampleActiveRide, stats: sampleStats)
        let nextState = DriverState.error(message: "GPS lost", previousState: currentState)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
    }

    // MARK: - Valid Transitions from ArrivedAtPickup

    func testTransition_arrivedAtPickupToRideInProgress_isValid() {
        // Passenger picked up
        let currentState = DriverState.arrivedAtPickup(ride: sampleActiveRide, stats: sampleStats)
        let nextState = DriverState.rideInProgress(ride: sampleActiveRide, stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
        if case .rideInProgress = result! {
            XCTAssert(true)
        } else {
            XCTFail("Expected rideInProgress state")
        }
    }

    func testTransition_arrivedAtPickupToOnline_isValid() {
        // Passenger cancelled
        let currentState = DriverState.arrivedAtPickup(ride: sampleActiveRide, stats: sampleStats)
        let nextState = DriverState.online(stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
    }

    func testTransition_arrivedAtPickupToError_isValid() {
        let currentState = DriverState.arrivedAtPickup(ride: sampleActiveRide, stats: sampleStats)
        let nextState = DriverState.error(message: "Error", previousState: currentState)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
    }

    // MARK: - Valid Transitions from RideInProgress

    func testTransition_rideInProgressToApproachingDestination_isValid() {
        let currentState = DriverState.rideInProgress(ride: sampleActiveRide, stats: sampleStats)
        let nextState = DriverState.approachingDestination(ride: sampleActiveRide, stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
        if case .approachingDestination = result! {
            XCTAssert(true)
        } else {
            XCTFail("Expected approachingDestination state")
        }
    }

    func testTransition_rideInProgressToRideCompleted_isValid() {
        // Can skip approaching destination for very short rides
        let currentState = DriverState.rideInProgress(ride: sampleActiveRide, stats: sampleStats)
        let nextState = DriverState.rideCompleted(summary: sampleRideSummary, stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
        if case .rideCompleted = result! {
            XCTAssert(true)
        } else {
            XCTFail("Expected rideCompleted state")
        }
    }

    func testTransition_rideInProgressToError_isValid() {
        let currentState = DriverState.rideInProgress(ride: sampleActiveRide, stats: sampleStats)
        let nextState = DriverState.error(message: "Error", previousState: currentState)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
    }

    // MARK: - Valid Transitions from ApproachingDestination

    func testTransition_approachingDestinationToRideCompleted_isValid() {
        let currentState = DriverState.approachingDestination(ride: sampleActiveRide, stats: sampleStats)
        let nextState = DriverState.rideCompleted(summary: sampleRideSummary, stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
        if case .rideCompleted = result! {
            XCTAssert(true)
        } else {
            XCTFail("Expected rideCompleted state")
        }
    }

    func testTransition_approachingDestinationToError_isValid() {
        let currentState = DriverState.approachingDestination(ride: sampleActiveRide, stats: sampleStats)
        let nextState = DriverState.error(message: "Error", previousState: currentState)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
    }

    // MARK: - Valid Transitions from RideCompleted

    func testTransition_rideCompletedToOnline_isValid() {
        let currentState = DriverState.rideCompleted(summary: sampleRideSummary, stats: sampleStats)
        let nextState = DriverState.online(stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
        if case .online = result! {
            XCTAssert(true)
        } else {
            XCTFail("Expected online state")
        }
    }

    func testTransition_rideCompletedToOffline_isValid() {
        let currentState = DriverState.rideCompleted(summary: sampleRideSummary, stats: sampleStats)
        let nextState = DriverState.offline

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
        if case .offline = result! {
            XCTAssert(true)
        } else {
            XCTFail("Expected offline state")
        }
    }

    func testTransition_rideCompletedToHeadingToPickup_isInvalid() {
        let currentState = DriverState.rideCompleted(summary: sampleRideSummary, stats: sampleStats)
        let nextState = DriverState.headingToPickup(ride: sampleActiveRide, stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNil(result)
    }

    // MARK: - Valid Transitions from Error

    func testTransition_errorToOffline_isValid() {
        let previousState = DriverState.online(stats: sampleStats)
        let currentState = DriverState.error(message: "Error", previousState: previousState)
        let nextState = DriverState.offline

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
    }

    func testTransition_errorToOnline_isValid() {
        let previousState = DriverState.online(stats: sampleStats)
        let currentState = DriverState.error(message: "Error", previousState: previousState)
        let nextState = DriverState.online(stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNotNil(result)
    }

    // MARK: - Edge Cases

    func testTransition_rideInProgressToOnline_isInvalid() {
        // Cannot abandon active ride without completing it
        let currentState = DriverState.rideInProgress(ride: sampleActiveRide, stats: sampleStats)
        let nextState = DriverState.online(stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNil(result)
    }

    func testTransition_onlineToHeadingToPickup_isInvalid() {
        // Must receive ride offer first
        let currentState = DriverState.online(stats: sampleStats)
        let nextState = DriverState.headingToPickup(ride: sampleActiveRide, stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNil(result)
    }

    func testTransition_headingToPickupToRideInProgress_isInvalid() {
        // Must arrive at pickup first
        let currentState = DriverState.headingToPickup(ride: sampleActiveRide, stats: sampleStats)
        let nextState = DriverState.rideInProgress(ride: sampleActiveRide, stats: sampleStats)

        let result = DriverStateMachine.transition(from: currentState, to: nextState)

        XCTAssertNil(result)
    }

    // MARK: - isValidTransition Tests

    func testIsValidTransition_checksCorrectly() {
        let currentState = DriverState.offline
        let validNext = DriverState.loggingIn
        let invalidNext = DriverState.online(stats: sampleStats)

        XCTAssertTrue(DriverStateMachine.isValidTransition(from: currentState, to: validNext))
        XCTAssertFalse(DriverStateMachine.isValidTransition(from: currentState, to: invalidNext))
    }

    // MARK: - Helper Method Tests

    func testLogin_createsLoggingInState() {
        let state = DriverStateMachine.login(driverId: "driver123")

        if case .loggingIn = state {
            XCTAssert(true)
        } else {
            XCTFail("Expected loggingIn state")
        }
    }

    func testLoginComplete_createsOnlineState() {
        let state = DriverStateMachine.loginComplete(stats: sampleStats)

        if case .online(let stats) = state {
            XCTAssertEqual(stats.rating, 4.8)
        } else {
            XCTFail("Expected online state")
        }
    }

    func testGoOffline_createsOfflineState() {
        let state = DriverStateMachine.goOffline()

        if case .offline = state {
            XCTAssert(true)
        } else {
            XCTFail("Expected offline state")
        }
    }

    func testAcceptRide_createsHeadingToPickupState() {
        let state = DriverStateMachine.acceptRide(ride: sampleActiveRide, stats: sampleStats)

        if case .headingToPickup = state {
            XCTAssert(true)
        } else {
            XCTFail("Expected headingToPickup state")
        }
    }

    func testRejectRide_createsOnlineState() {
        let state = DriverStateMachine.rejectRide(stats: sampleStats)

        if case .online = state {
            XCTAssert(true)
        } else {
            XCTFail("Expected online state")
        }
    }
}
