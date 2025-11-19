//
//  CoordinatorTests.swift
//  Model S Tests
//
//  Tests for coordinators navigation logic
//  Verifies screen transitions work correctly
//

import XCTest
import CoreLocation
import Combine
@testable import Model_S

@MainActor
final class CoordinatorTests: XCTestCase {

    var stateStore: AppStateStore!
    var dependencies: DependencyContainer!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        stateStore = AppStateStore()
        dependencies = DependencyContainer(stateStore: stateStore)
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        stateStore = nil
        dependencies = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - RiderCoordinator Tests

    func testRiderCoordinatorStartsWithHomeScreen() {
        // Given
        let coordinator = RiderCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )

        // When
        coordinator.start()

        // Then
        XCTAssertEqual(coordinator.currentScreen, .home)
    }

    func testRiderCoordinatorShowRideRequest() {
        // Given
        let coordinator = RiderCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )
        coordinator.start()

        // When
        coordinator.showRideRequest()

        // Then
        XCTAssertEqual(coordinator.currentScreen, .rideRequest)
        XCTAssertNotNil(coordinator.rideRequestCoordinator)
    }

    func testRiderCoordinatorShowHistory() {
        // Given
        let coordinator = RiderCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )
        coordinator.start()

        // When
        coordinator.showHistory()

        // Then
        XCTAssertEqual(coordinator.currentScreen, .history)
    }

    func testRiderCoordinatorShowSettings() {
        // Given
        let coordinator = RiderCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )
        coordinator.start()

        // When
        coordinator.showSettings()

        // Then
        XCTAssertEqual(coordinator.currentScreen, .settings)
    }

    func testRiderCoordinatorNavigationSequence() {
        // Given
        let coordinator = RiderCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )
        coordinator.start()

        // When/Then - navigate through all screens
        coordinator.showRideRequest()
        XCTAssertEqual(coordinator.currentScreen, .rideRequest)

        coordinator.showHistory()
        XCTAssertEqual(coordinator.currentScreen, .history)

        coordinator.showSettings()
        XCTAssertEqual(coordinator.currentScreen, .settings)

        coordinator.showHome()
        XCTAssertEqual(coordinator.currentScreen, .home)
    }

    func testRiderCoordinatorCreatesRideRequestCoordinatorOnce() {
        // Given
        let coordinator = RiderCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )
        coordinator.start()

        // When - show ride request twice
        coordinator.showRideRequest()
        let firstCoordinator = coordinator.rideRequestCoordinator

        coordinator.showHome()
        coordinator.showRideRequest()
        let secondCoordinator = coordinator.rideRequestCoordinator

        // Then - same coordinator instance
        XCTAssertTrue(firstCoordinator === secondCoordinator)
    }

    // MARK: - DriverCoordinator Tests

    func testDriverCoordinatorStartsWithHomeScreen() {
        // Given
        let coordinator = DriverCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )

        // When
        coordinator.start()

        // Then
        XCTAssertEqual(coordinator.currentScreen, .home)
    }

    func testDriverCoordinatorShowActiveRide() {
        // Given
        let coordinator = DriverCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )
        coordinator.start()

        // When
        coordinator.showActiveRide()

        // Then
        XCTAssertEqual(coordinator.currentScreen, .activeRide)
    }

    func testDriverCoordinatorShowRideOffer() {
        // Given
        let coordinator = DriverCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )
        coordinator.start()

        // When
        coordinator.showRideOffer()

        // Then
        XCTAssertEqual(coordinator.currentScreen, .rideOffer)
    }

    func testDriverCoordinatorCreatesFlowController() {
        // Given
        let coordinator = DriverCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )

        // When
        coordinator.start()

        // Then
        XCTAssertNotNil(coordinator.driverFlowController)
    }

    // MARK: - MainCoordinator Tests

    func testMainCoordinatorStartsInRiderMode() {
        // Given
        stateStore.dispatch(.setDriverMode(false))
        let coordinator = MainCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )

        // When
        coordinator.start()

        // Then
        XCTAssertEqual(coordinator.currentMode, .rider)
    }

    func testMainCoordinatorStartsInDriverMode() {
        // Given
        stateStore.dispatch(.setDriverMode(true))
        let coordinator = MainCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )

        // When
        coordinator.start()

        // Then
        XCTAssertEqual(coordinator.currentMode, .driver)
    }

    func testMainCoordinatorSwitchesToDriverMode() {
        // Given
        stateStore.dispatch(.setDriverMode(false))
        let coordinator = MainCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )
        coordinator.start()
        XCTAssertEqual(coordinator.currentMode, .rider)

        // Create expectation for async state change
        let expectation = XCTestExpectation(description: "Mode switches to driver")

        coordinator.$currentMode
            .dropFirst() // Skip initial value
            .sink { mode in
                if mode == .driver {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        stateStore.dispatch(.setDriverMode(true))

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(coordinator.currentMode, .driver)
    }

    func testMainCoordinatorSwitchesToRiderMode() {
        // Given
        stateStore.dispatch(.setDriverMode(true))
        let coordinator = MainCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )
        coordinator.start()
        XCTAssertEqual(coordinator.currentMode, .driver)

        // Create expectation for async state change
        let expectation = XCTestExpectation(description: "Mode switches to rider")

        coordinator.$currentMode
            .dropFirst() // Skip initial value
            .sink { mode in
                if mode == .rider {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        stateStore.dispatch(.setDriverMode(false))

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(coordinator.currentMode, .rider)
    }

    func testMainCoordinatorProvidesRiderCoordinator() {
        // Given
        stateStore.dispatch(.setDriverMode(false))
        let coordinator = MainCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )

        // When
        coordinator.start()

        // Then
        XCTAssertNotNil(coordinator.activeRiderCoordinator)
        XCTAssertNil(coordinator.activeDriverCoordinator)
    }

    func testMainCoordinatorProvidesDriverCoordinator() {
        // Given
        stateStore.dispatch(.setDriverMode(true))
        let coordinator = MainCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )

        // When
        coordinator.start()

        // Then
        XCTAssertNotNil(coordinator.activeDriverCoordinator)
        XCTAssertNil(coordinator.activeRiderCoordinator)
    }

    // MARK: - AppCoordinator Tests

    func testAppCoordinatorStartsWithLoadingScreen() {
        // Given
        let coordinator = AppCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )

        // Then - default is loading
        XCTAssertEqual(coordinator.currentScreen, .loading)
    }

    func testAppCoordinatorShowsMainWhenAuthenticated() {
        // Given
        let user = User(
            id: "user123",
            name: "Test User",
            email: "test@example.com"
        )
        stateStore.dispatch(.setUser(user))

        let coordinator = AppCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )

        // When
        coordinator.start()

        // Then
        XCTAssertEqual(coordinator.currentScreen, .main)
    }

    func testAppCoordinatorShowsAuthWhenNotAuthenticated() {
        // Given - no user set
        let coordinator = AppCoordinator(
            stateStore: stateStore,
            dependencies: dependencies
        )

        // When
        coordinator.start()

        // Then
        XCTAssertEqual(coordinator.currentScreen, .authentication)
    }
}
