//
//  RideStateMachineTests.swift
//  Model S Tests
//
//  Tests for RideStateMachine state transitions
//  Verifies that only valid state transitions are allowed
//

import XCTest
import CoreLocation
@testable import Model_S

final class RideStateMachineTests: XCTestCase {

    var stateMachine: RideStateMachine!

    override func setUp() {
        super.setUp()
        stateMachine = RideStateMachine()
    }

    override func tearDown() {
        stateMachine = nil
        super.tearDown()
    }

    // MARK: - Helper Properties

    var samplePickup: LocationPoint {
        LocationPoint(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), name: "San Francisco")
    }

    var sampleDestination: LocationPoint {
        LocationPoint(coordinate: CLLocationCoordinate2D(latitude: 37.8049, longitude: -122.3994), name: "Oakland")
    }

    var sampleRoute: RouteInfo {
        RouteInfo(distance: 5000, estimatedTravelTime: 600, polyline: "test_polyline")
    }

    var sampleDriver: DriverInfo {
        DriverInfo(
            id: "driver123",
            name: "John Doe",
            rating: 4.8,
            vehicleMake: "Toyota",
            vehicleModel: "Camry",
            vehicleColor: "Silver",
            licensePlate: "ABC123",
            photoURL: nil,
            phoneNumber: nil,
            currentLocation: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
            estimatedArrivalTime: 300
        )
    }

    // MARK: - Valid Transitions from Idle

    func testTransition_idleToSelectingLocations_isValid() {
        let currentState = RideState.idle
        let nextState = RideState.selectingLocations(pickup: nil, destination: nil)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_idleToError_isValid() {
        let currentState = RideState.idle
        let nextState = RideState.error(.locationUnavailable, previousState: nil)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_idleToDriverAssigned_isInvalid() {
        let currentState = RideState.idle
        let nextState = RideState.driverAssigned(
            rideId: "ride123",
            driver: sampleDriver,
            pickup: samplePickup,
            destination: sampleDestination
        )

        XCTAssertFalse(stateMachine.canTransition(from: currentState, to: nextState))
    }

    // MARK: - Valid Transitions from SelectingLocations

    func testTransition_selectingLocationsToRouteReady_isValid() {
        let currentState = RideState.selectingLocations(pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.routeReady(pickup: samplePickup, destination: sampleDestination, route: sampleRoute)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_selectingLocationsToIdle_isValid() {
        let currentState = RideState.selectingLocations(pickup: samplePickup, destination: nil)
        let nextState = RideState.idle

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_selectingLocationsToItself_isValid() {
        // User can update location selection
        let currentState = RideState.selectingLocations(pickup: samplePickup, destination: nil)
        let nextState = RideState.selectingLocations(pickup: samplePickup, destination: sampleDestination)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    // MARK: - Valid Transitions from RouteReady

    func testTransition_routeReadyToSubmittingRequest_isValid() {
        let currentState = RideState.routeReady(pickup: samplePickup, destination: sampleDestination, route: sampleRoute)
        let nextState = RideState.submittingRequest(pickup: samplePickup, destination: sampleDestination)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_routeReadyToSelectingLocations_isValid() {
        // User can go back to change locations
        let currentState = RideState.routeReady(pickup: samplePickup, destination: sampleDestination, route: sampleRoute)
        let nextState = RideState.selectingLocations(pickup: samplePickup, destination: sampleDestination)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_routeReadyToIdle_isInvalid() {
        // Should go through selectingLocations to reset
        let currentState = RideState.routeReady(pickup: samplePickup, destination: sampleDestination, route: sampleRoute)
        let nextState = RideState.idle

        XCTAssertFalse(stateMachine.canTransition(from: currentState, to: nextState))
    }

    // MARK: - Valid Transitions from SubmittingRequest

    func testTransition_submittingRequestToSearchingForDriver_isValid() {
        let currentState = RideState.submittingRequest(pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.searchingForDriver(rideId: "ride123", pickup: samplePickup, destination: sampleDestination)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_submittingRequestToError_isValid() {
        let currentState = RideState.submittingRequest(pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.error(.rideRequestFailed, previousState: currentState)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    // MARK: - Valid Transitions from SearchingForDriver

    func testTransition_searchingForDriverToDriverAssigned_isValid() {
        let currentState = RideState.searchingForDriver(rideId: "ride123", pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.driverAssigned(rideId: "ride123", driver: sampleDriver, pickup: samplePickup, destination: sampleDestination)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_searchingForDriverToIdle_isValid() {
        // User can cancel the search
        let currentState = RideState.searchingForDriver(rideId: "ride123", pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.idle

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    // MARK: - Valid Transitions from DriverAssigned

    func testTransition_driverAssignedToDriverEnRoute_isValid() {
        let currentState = RideState.driverAssigned(rideId: "ride123", driver: sampleDriver, pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.driverEnRoute(rideId: "ride123", driver: sampleDriver, eta: 300, pickup: samplePickup, destination: sampleDestination)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_driverAssignedToIdle_isValid() {
        // User can cancel before driver arrives
        let currentState = RideState.driverAssigned(rideId: "ride123", driver: sampleDriver, pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.idle

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    // MARK: - Valid Transitions from DriverEnRoute

    func testTransition_driverEnRouteToDriverArriving_isValid() {
        let currentState = RideState.driverEnRoute(rideId: "ride123", driver: sampleDriver, eta: 300, pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.driverArriving(rideId: "ride123", driver: sampleDriver, pickup: samplePickup, destination: sampleDestination)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_driverEnRouteToIdle_isValid() {
        // User can cancel ride
        let currentState = RideState.driverEnRoute(rideId: "ride123", driver: sampleDriver, eta: 300, pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.idle

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    // MARK: - Valid Transitions from DriverArriving

    func testTransition_driverArrivingToRideInProgress_isValid() {
        let currentState = RideState.driverArriving(rideId: "ride123", driver: sampleDriver, pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.rideInProgress(rideId: "ride123", driver: sampleDriver, eta: 600, pickup: samplePickup, destination: sampleDestination)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_driverArrivingToIdle_isValid() {
        // User can still cancel
        let currentState = RideState.driverArriving(rideId: "ride123", driver: sampleDriver, pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.idle

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    // MARK: - Valid Transitions from RideInProgress

    func testTransition_rideInProgressToApproachingDestination_isValid() {
        let currentState = RideState.rideInProgress(rideId: "ride123", driver: sampleDriver, eta: 600, pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.approachingDestination(rideId: "ride123", driver: sampleDriver, pickup: samplePickup, destination: sampleDestination)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_rideInProgressToRideCompleted_isValid() {
        // Can skip approaching destination if backend goes directly to completed
        let currentState = RideState.rideInProgress(rideId: "ride123", driver: sampleDriver, eta: 600, pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.rideCompleted(rideId: "ride123", driver: sampleDriver, pickup: samplePickup, destination: sampleDestination)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    // MARK: - Valid Transitions from ApproachingDestination

    func testTransition_approachingDestinationToRideCompleted_isValid() {
        let currentState = RideState.approachingDestination(rideId: "ride123", driver: sampleDriver, pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.rideCompleted(rideId: "ride123", driver: sampleDriver, pickup: samplePickup, destination: sampleDestination)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_approachingDestinationToIdle_isValid() {
        // Can cancel at any point
        let currentState = RideState.approachingDestination(rideId: "ride123", driver: sampleDriver, pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.idle

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    // MARK: - Valid Transitions from RideCompleted

    func testTransition_rideCompletedToIdle_isValid() {
        let currentState = RideState.rideCompleted(rideId: "ride123", driver: sampleDriver, pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.idle

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_rideCompletedToSelectingLocations_isInvalid() {
        // Should reset to idle first
        let currentState = RideState.rideCompleted(rideId: "ride123", driver: sampleDriver, pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.selectingLocations(pickup: nil, destination: nil)

        XCTAssertFalse(stateMachine.canTransition(from: currentState, to: nextState))
    }

    // MARK: - Valid Transitions from Error

    func testTransition_errorToIdle_isValid() {
        let currentState = RideState.error(.rideRequestFailed, previousState: .idle)
        let nextState = RideState.idle

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_errorToSelectingLocations_isValid() {
        let currentState = RideState.error(.geocodingFailed, previousState: .selectingLocations(pickup: nil, destination: nil))
        let nextState = RideState.selectingLocations(pickup: nil, destination: nil)

        XCTAssertTrue(stateMachine.canTransition(from: currentState, to: nextState))
    }

    // MARK: - Transition Method Tests

    func testTransitionMethod_returnsNewStateForValidTransition() {
        let currentState = RideState.idle
        let nextState = RideState.selectingLocations(pickup: nil, destination: nil)

        let result = stateMachine.transition(from: currentState, to: nextState)

        // Should return the next state
        if case .selectingLocations = result {
            XCTAssert(true)
        } else {
            XCTFail("Expected selectingLocations state")
        }
    }

    func testTransitionMethod_returnsErrorStateForInvalidTransition() {
        let currentState = RideState.idle
        let nextState = RideState.rideCompleted(rideId: "ride123", driver: sampleDriver, pickup: samplePickup, destination: sampleDestination)

        let result = stateMachine.transition(from: currentState, to: nextState)

        // Should return error state
        if case .error = result {
            XCTAssert(true)
        } else {
            XCTFail("Expected error state for invalid transition")
        }
    }

    // MARK: - Edge Cases

    func testTransition_rideInProgressToSearchingForDriver_isInvalid() {
        // Cannot go backwards in the flow
        let currentState = RideState.rideInProgress(rideId: "ride123", driver: sampleDriver, eta: 600, pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.searchingForDriver(rideId: "ride123", pickup: samplePickup, destination: sampleDestination)

        XCTAssertFalse(stateMachine.canTransition(from: currentState, to: nextState))
    }

    func testTransition_submittingRequestToRouteReady_isInvalid() {
        // Cannot go backwards after submitting
        let currentState = RideState.submittingRequest(pickup: samplePickup, destination: sampleDestination)
        let nextState = RideState.routeReady(pickup: samplePickup, destination: sampleDestination, route: sampleRoute)

        XCTAssertFalse(stateMachine.canTransition(from: currentState, to: nextState))
    }
}
