/**
 * Driver Flow Controller
 * Single source of truth for driver app state
 * Manages all state transitions through a state machine
 */

import Foundation
import Combine
import CoreLocation

/// Controls the entire driver flow with a clean state machine
@MainActor
class DriverFlowController: ObservableObject {

    // MARK: - Published State (Single Source of Truth)

    /// Current state of the driver - the only source of truth
    @Published private(set) var currentState: DriverState = .offline

    /// Current driver ID (set on login)
    private(set) var driverId: String?

    // MARK: - Dependencies

    private let apiClient: DriverAPIClient
    private let locationManager: CLLocationManager

    // MARK: - Timers & Tasks

    private var statsUpdateTimer: Timer?
    private var rideOfferExpiryTimer: Timer?
    private var offerPollingTimer: Timer?

    // MARK: - Initialization

    init(apiClient: DriverAPIClient? = nil) {
        self.apiClient = apiClient ?? DriverAPIClient()
        self.locationManager = CLLocationManager()

        setupLocationManager()
    }

    deinit {
        statsUpdateTimer?.invalidate()
        rideOfferExpiryTimer?.invalidate()
        print("🧹 DriverFlowController deallocated, cleaned up resources")
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
    }

    // MARK: - Authentication

    /// Login driver
    func login(driverId: String) async {
        guard case .offline = currentState else {
            print("⚠️ Cannot login - already logged in")
            return
        }

        transition(to: .loggingIn)

        do {
            // Request location permission if needed
            locationManager.requestWhenInUseAuthorization()

            // Get current location
            guard let location = locationManager.location?.coordinate else {
                throw DriverAPIError.locationUpdateFailed
            }

            // Login to backend
            let response = try await apiClient.login(driverId: driverId, location: location)

            self.driverId = driverId

            // Create initial stats from session
            let stats = DriverStats(
                onlineTime: 0,
                completedRides: response.session.completedRides,
                totalEarnings: response.session.totalEarnings,
                acceptanceRate: 100,
                rating: response.driver.rating
            )

            // Transition to online
            transition(to: .online(stats: stats))

            // Start updating stats periodically
            startStatsTimer()

            // Start polling for ride offers
            startOfferPolling()

            print("✅ Driver \(response.driver.name) logged in successfully")

        } catch {
            print("❌ Login failed: \(error)")
            transition(to: .error(message: "Login failed: \(error.localizedDescription)", previousState: .offline))
        }
    }

    /// Logout driver
    func logout() async {
        guard let driverId = driverId else {
            print("⚠️ No driver ID set")
            return
        }

        // Stop timers
        stopTimers()

        do {
            // Logout from backend
            try await apiClient.logout(driverId: driverId)

            // Transition to offline
            transition(to: .offline)

            self.driverId = nil

            print("✅ Driver logged out successfully")

        } catch {
            print("❌ Logout failed: \(error)")
            // Force offline anyway
            transition(to: .offline)
            self.driverId = nil
        }
    }

    // MARK: - Availability

    /// Toggle driver availability
    func toggleAvailability() async {
        guard let driverId = driverId,
              let stats = currentState.currentStats else {
            print("⚠️ Cannot toggle availability - not logged in")
            return
        }

        // Can only toggle when online (not on active ride)
        guard case .online = currentState else {
            print("⚠️ Cannot toggle availability - not in online state")
            return
        }

        // For now, going offline means logout
        // In production, you might want a separate offline state
        await logout()
    }

    // MARK: - Ride Offers

    /// Receive a new ride offer
    func receiveRideOffer(_ request: RideRequest) {
        guard case .online(let stats) = currentState else {
            print("⚠️ Cannot receive ride offer - not online")
            return
        }

        // Transition to ride offered state
        let newState = DriverStateMachine.receiveRideOffer(request: request, currentStats: stats)
        transition(to: newState)

        // Start expiry timer
        startRideOfferExpiryTimer(request: request)

        print("📱 New ride offer received: \(request.rideId)")
    }

    /// Accept current ride offer
    func acceptRide() async {
        guard case .rideOffered(let request, let stats) = currentState,
              let driverId = driverId else {
            print("⚠️ Cannot accept ride - no active offer")
            return
        }

        // Stop expiry timer
        rideOfferExpiryTimer?.invalidate()

        do {
            // Accept ride on backend
            try await apiClient.acceptRide(driverId: driverId, rideId: request.rideId)

            // Create active ride from request
            let activeRide = ActiveRide(
                rideId: request.rideId,
                pickup: request.pickup,
                destination: request.destination,
                passenger: ActiveRide.PassengerInfo(
                    name: "Passenger", // Would come from backend
                    rating: 4.8,
                    phoneNumber: nil
                ),
                currentDriverLocation: locationManager.location.map {
                    LocationPoint(coordinate: $0.coordinate, name: nil)
                } ?? request.pickup,
                estimatedArrival: nil,
                distanceToDestination: request.distance
            )

            // Transition to heading to pickup
            let newState = DriverStateMachine.acceptRide(ride: activeRide, stats: stats)
            transition(to: newState)

            print("✅ Ride accepted: \(request.rideId)")

        } catch {
            print("❌ Failed to accept ride: \(error)")
            transition(to: .error(message: "Failed to accept ride", previousState: currentState))
        }
    }

    /// Reject current ride offer
    func rejectRide() async {
        guard case .rideOffered(let request, let stats) = currentState,
              let driverId = driverId else {
            print("⚠️ Cannot reject ride - no active offer")
            return
        }

        // Stop expiry timer
        rideOfferExpiryTimer?.invalidate()

        do {
            // Reject ride on backend
            try await apiClient.rejectRide(driverId: driverId, rideId: request.rideId)

            // Transition back to online
            let newState = DriverStateMachine.rejectRide(stats: stats)
            transition(to: newState)

            // Resume polling for new offers
            startOfferPolling()

            print("❌ Ride rejected: \(request.rideId)")

        } catch {
            print("❌ Failed to reject ride: \(error)")
            // Still transition to online
            transition(to: .online(stats: stats))
            // Resume polling
            startOfferPolling()
        }
    }

    // MARK: - Ride Progress

    /// Mark arrival at pickup location
    func arriveAtPickup() async {
        guard case .headingToPickup(let ride, let stats) = currentState,
              let driverId = driverId else {
            print("⚠️ Cannot mark arrival - not heading to pickup")
            return
        }

        do {
            // Update status on backend
            try await apiClient.updateRideStatus(driverId: driverId, rideId: ride.rideId, status: "arrived")

            // Transition to arrived state
            let newState = DriverStateMachine.arriveAtPickup(ride: ride, stats: stats)
            transition(to: newState)

            print("📍 Arrived at pickup")

        } catch {
            print("❌ Failed to update arrival status: \(error)")
        }
    }

    /// Pick up passenger
    func pickupPassenger() async {
        guard case .arrivedAtPickup(let ride, let stats) = currentState,
              let driverId = driverId else {
            print("⚠️ Cannot pickup passenger - not at pickup location")
            return
        }

        do {
            // Update status on backend
            try await apiClient.updateRideStatus(driverId: driverId, rideId: ride.rideId, status: "pickedUp")

            // Transition to ride in progress
            let newState = DriverStateMachine.pickupPassenger(ride: ride, stats: stats)
            transition(to: newState)

            print("🚗 Passenger picked up")

        } catch {
            print("❌ Failed to update pickup status: \(error)")
        }
    }

    /// Complete ride
    func completeRide() async {
        guard case .rideInProgress(let ride, let stats) = currentState,
              let driverId = driverId else {
            print("⚠️ Cannot complete ride - ride not in progress")
            return
        }

        do {
            // Update status on backend
            try await apiClient.updateRideStatus(driverId: driverId, rideId: ride.rideId, status: "completed")

            // Create ride summary
            let summary = RideSummary(
                rideId: ride.rideId,
                pickup: ride.pickup,
                destination: ride.destination,
                distance: ride.distanceToDestination ?? 0,
                duration: 0, // Would calculate from ride start time
                earnings: calculateEarnings(distance: ride.distanceToDestination ?? 0),
                passengerRating: nil,
                completedAt: Date()
            )

            // Update stats
            var updatedStats = stats
            updatedStats.completedRides += 1
            updatedStats.totalEarnings += summary.earnings

            // Transition to completed
            let newState = DriverStateMachine.completeRide(summary: summary, updatedStats: updatedStats)
            transition(to: newState)

            print("✅ Ride completed")

        } catch {
            print("❌ Failed to complete ride: \(error)")
        }
    }

    /// Finish viewing ride summary and return to online
    func finishRideSummary() {
        guard case .rideCompleted(_, let stats) = currentState else {
            print("⚠️ Cannot finish summary - no completed ride")
            return
        }

        let newState = DriverStateMachine.finishRideSummary(stats: stats)
        transition(to: newState)

        // Resume polling for new offers
        startOfferPolling()
    }

    // MARK: - Location Updates

    /// Update driver location (called periodically while online)
    func updateLocation() async {
        guard let driverId = driverId,
              currentState.isOnline,
              let location = locationManager.location?.coordinate else {
            return
        }

        do {
            try await apiClient.updateLocation(driverId: driverId, location: location)
        } catch {
            // Silent failure for location updates
            print("⚠️ Failed to update location: \(error)")
        }
    }

    // MARK: - State Management

    private func transition(to newState: DriverState) {
        // Validate transition
        guard let validatedState = DriverStateMachine.transition(from: currentState, to: newState) else {
            print("❌ Invalid state transition attempted")
            return
        }

        currentState = validatedState
    }

    // MARK: - Timers

    private func startStatsTimer() {
        statsUpdateTimer?.invalidate()

        statsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateStats()
            }
        }
    }

    private func startRideOfferExpiryTimer(request: RideRequest) {
        rideOfferExpiryTimer?.invalidate()

        rideOfferExpiryTimer = Timer.scheduledTimer(withTimeInterval: request.timeRemaining, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleRideOfferExpiry()
            }
        }
    }

    private func startOfferPolling() {
        offerPollingTimer?.invalidate()

        // Poll every 3 seconds for ride offers
        offerPollingTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkForRideOffers()
            }
        }
    }

    private func stopTimers() {
        statsUpdateTimer?.invalidate()
        statsUpdateTimer = nil

        rideOfferExpiryTimer?.invalidate()
        rideOfferExpiryTimer = nil

        offerPollingTimer?.invalidate()
        offerPollingTimer = nil
    }

    private func handleRideOfferExpiry() {
        guard case .rideOffered(let request, let stats) = currentState else {
            return
        }

        print("⏱️ Ride offer expired: \(request.rideId)")

        // Automatically transition back to online
        transition(to: .online(stats: stats))

        // Resume polling for new offers
        startOfferPolling()
    }

    private func checkForRideOffers() async {
        guard let driverId = driverId,
              case .online(let stats) = currentState else {
            return
        }

        do {
            let response = try await apiClient.getOffers(driverId: driverId)

            if response.hasOffer, let offer = response.offer {
                // Received a ride offer!
                print("🎯 Received ride offer: \(offer.rideId)")

                let request = RideRequest(
                    rideId: offer.rideId,
                    pickup: offer.pickup,
                    destination: offer.destination,
                    distance: offer.distance,
                    estimatedEarnings: offer.estimatedEarnings,
                    expiresAt: ISO8601DateFormatter().date(from: offer.expiresAt) ?? Date().addingTimeInterval(30)
                )

                // Stop polling while we have an offer
                offerPollingTimer?.invalidate()

                receiveRideOffer(request)
            }
        } catch {
            // Silent failure for offer polling
            print("⚠️ Failed to check for offers: \(error)")
        }
    }

    private func updateStats() async {
        guard let driverId = driverId else { return }

        do {
            let response = try await apiClient.getStats(driverId: driverId)

            // Update stats in current state
            let newStats = DriverStats(
                onlineTime: response.stats.onlineTime,
                completedRides: response.stats.completedRides,
                totalEarnings: response.stats.totalEarnings,
                acceptanceRate: response.stats.acceptanceRate,
                rating: response.stats.rating
            )

            let updatedState = DriverStateMachine.updateStats(in: currentState, newStats: newStats)
            currentState = updatedState

        } catch {
            print("⚠️ Failed to update stats: \(error)")
        }
    }

    // MARK: - Helpers

    private func calculateEarnings(distance: Double) -> Double {
        // Simple calculation: $2 base + $1.50 per km
        let distanceKm = distance / 1000
        let earnings = 2 + (distanceKm * 1.5)
        return Double(round(100 * earnings) / 100)
    }
}
