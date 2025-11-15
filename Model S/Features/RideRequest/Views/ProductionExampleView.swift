//
//  ProductionExampleView.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI
import CoreLocation
import MapKit

/// Example of how to integrate RideRequestView in a production app
/// with all production-ready features enabled
struct ProductionExampleView: View {
    @State private var showRideRequest = true

    var body: some View {
        ZStack {
            if showRideRequest {
                // Production-ready RideRequestView with full integration
                RideRequestViewWithViewModel(
                    configuration: productionConfig,
                    onRideConfirmed: handleRideConfirmed,
                    onCancel: {
                        showRideRequest = false
                    }
                )
            } else {
                // Your main app UI
                MainAppPlaceholder(onRequestRide: {
                    showRideRequest = true
                })
            }
        }
    }

    private var productionConfig: RideRequestConfiguration {
        var config = RideRequestConfiguration.default
        config.enableGeocoding = true
        config.enableRouteCalculation = true
        config.enableValidation = true
        config.showRouteInfo = true
        config.showErrorBanner = true
        return config
    }

    private func handleRideConfirmed(pickup: LocationPoint, destination: LocationPoint, route: RouteInfo?) {
        // In production, you would:
        // 1. Submit ride request to your backend
        // 2. Start driver search
        // 3. Navigate to ride tracking screen

        print("Ride confirmed!")
        print("Pickup: \(pickup.name ?? "Unknown"), \(pickup.coordinate)")
        print("Destination: \(destination.name ?? "Unknown"), \(destination.coordinate)")

        if let route = route {
            let minutes = Int(route.estimatedTravelTime / 60)
            let miles = route.distance / 1609.34
            print("ETA: \(minutes) min, Distance: \(String(format: "%.1f mi", miles))")
        }

        // Save ride to history
        saveRideToHistory(pickup: pickup, destination: destination, route: route)

        // Example: Send to backend
        // Task {
        //     await submitRideRequest(pickup: pickup, destination: destination)
        // }
    }

    private func saveRideToHistory(pickup: LocationPoint, destination: LocationPoint, route: RouteInfo?) {
        // Extract ride details from route
        let distance = route?.distance ?? 0
        let travelTime = route?.estimatedTravelTime ?? 0
        let pickupAddress = pickup.name ?? "Unknown"
        let destinationAddress = destination.name ?? "Unknown"

        // Create ride history entry
        let ride = RideHistory(
            pickupLocation: pickup,
            destinationLocation: destination,
            distance: distance,
            estimatedTravelTime: travelTime,
            pickupAddress: pickupAddress,
            destinationAddress: destinationAddress
        )

        // Save to persistent storage
        RideHistoryStore.shared.addRide(ride)

        print("✅ Ride saved to history: \(ride.formattedDistance), \(ride.formattedTravelTime)")
    }
}

/// Placeholder for main app UI
struct MainAppPlaceholder: View {
    let onRequestRide: () -> Void

    var body: some View {
        VStack {
            Text("Your App")
                .font(.largeTitle)
                .fontWeight(.bold)

            Button("Request a Ride") {
                onRequestRide()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

/// Enhanced RideRequestView that integrates with RideRequestViewModel
/// SIMPLIFIED using RideRequestCoordinator for all business logic
struct RideRequestViewWithViewModel: View {
    @StateObject private var coordinator: RideRequestCoordinator
    @State private var pickupText: String
    @State private var destinationText = ""
    @FocusState private var focusedField: RideLocationCard.LocationField?
    @State private var showRideHistory = false

    var onRideConfirmed: (LocationPoint, LocationPoint, RouteInfo?) -> Void
    var onCancel: () -> Void

    init(
        configuration: RideRequestConfiguration = .default,
        onRideConfirmed: @escaping (LocationPoint, LocationPoint, RouteInfo?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        // Create coordinator with configuration
        self._coordinator = StateObject(wrappedValue: RideRequestCoordinator(configuration: configuration))
        self._pickupText = State(initialValue: configuration.defaultPickupText as String)
        self.onRideConfirmed = onRideConfirmed
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            // Map (managed by coordinator)
            RideMapView(viewModel: coordinator.mapViewModel, configuration: RideRequestConfiguration.default)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Error Banner
                if let error = coordinator.flowController.currentError {
                    ErrorBannerView(error: error, onDismiss: {
                        DispatchQueue.main.async {
                            coordinator.flowController.clearError()
                        }
                    })
                    .padding(.top, 56)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Location Card with Autocomplete - Hide when status banner is showing
                if !shouldShowStatusBanner {
                    RideLocationCardWithSearch(
                        pickupText: $pickupText,
                        destinationText: $destinationText,
                        focusedField: $focusedField,
                        configuration: RideRequestConfiguration.default,
                        userLocation: coordinator.mapViewModel.userLocation?.coordinate,
                        onPickupTap: {
                            focusedField = .pickup
                            coordinator.didFocusPickup()
                        },
                        onDestinationTap: {
                            focusedField = .destination
                            coordinator.didFocusDestination()
                        },
                        onLocationSelected: { coordinate, name, isPickup in
                            // Simplified - just call coordinator
                            Task {
                                await coordinator.selectLocation(coordinate: coordinate, name: name, isPickup: isPickup)
                            }
                        },
                        onUseCurrentLocation: {
                            handleUseCurrentLocation()
                        }
                    )
                    .padding(.top, coordinator.flowController.currentError != nil ? 12 : 56)
                    .transition(.move(edge: .top).combined(with: .opacity))

                    // Route Info
                    if let routeInfo = coordinator.flowController.routeInfo {
                        RouteInfoView(
                            travelTime: formatTravelTime(routeInfo.estimatedTravelTime),
                            distance: formatDistance(routeInfo.distance)
                        )
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                Spacer()
            }

            // Confirm Slider (managed by coordinator)
            if coordinator.shouldShowConfirmSlider {
                VStack {
                    Spacer()

                    RideConfirmSlider(
                        configuration: RideRequestConfiguration.default,
                        onConfirmRide: handleConfirmRide
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Status Banner - Shows different states of ride request
            if shouldShowStatusBanner {
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        // Status Header
                        HStack(spacing: 12) {
                            if coordinator.flowController.legacyState == .searchingForDriver {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.1)
                            } else if coordinator.flowController.legacyState == .driverFound {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 28))
                            } else if coordinator.flowController.legacyState == .driverEnRoute {
                                Image(systemName: "car.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(statusBannerTitle)
                                    .font(.headline)
                                    .foregroundColor(.white)

                                if let subtitle = statusBannerSubtitle {
                                    Text(subtitle)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }

                            Spacer()
                        }

                        // Driver Info (when found)
                        if let driver = coordinator.flowController.driver,
                           coordinator.flowController.legacyState != .searchingForDriver {
                            Divider()
                                .background(Color.white.opacity(0.3))

                            HStack(spacing: 12) {
                                // Driver avatar placeholder
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white.opacity(0.7))
                                            .font(.system(size: 24))
                                    )

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(driver.name)
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    HStack(spacing: 8) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(.yellow)
                                                .font(.system(size: 12))
                                            Text(String(format: "%.1f", driver.rating))
                                                .font(.subheadline)
                                                .foregroundColor(.white.opacity(0.9))
                                        }

                                        Text("•")
                                            .foregroundColor(.white.opacity(0.5))

                                        Text("\(driver.vehicleColor) \(driver.vehicleMake) \(driver.vehicleModel)")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.9))
                                            .lineLimit(1)
                                    }

                                    Text(driver.licensePlate)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white.opacity(0.7))
                                }

                                Spacer()
                            }
                        }

                        // Cancel Button
                        if coordinator.flowController.legacyState == .searchingForDriver ||
                           coordinator.flowController.legacyState == .rideRequested {
                            Button(action: {
                                coordinator.cancelRideRequest()
                            }) {
                                Text("Cancel Request")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.red)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.top, 56)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Loading Overlay
            if coordinator.flowController.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }

            // Floating History Button
            VStack {
                HStack {
                    Spacer()

                    Button(action: {
                        showRideHistory = true
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
                    }
                    .padding(.top, 56)
                    .padding(.trailing, 16)
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showRideHistory) {
            RideHistoryView()
        }
    }

    // MARK: - Actions
    // All complex logic is now in the coordinator - view is just presentation!

    private func handleConfirmRide() {
        // Coordinator handles all validation and state management
        if let result = coordinator.confirmRide() {
            // Get route info from flow controller
            let routeInfo = coordinator.flowController.routeInfo

            onRideConfirmed(result.pickup, result.destination, routeInfo)

            // Start the ride request flow in a detached task (outside view update cycle)
            Task {
                await coordinator.startRideRequest()
            }
        }
    }

    private func handleUseCurrentLocation() {
        guard let userLocation = coordinator.mapViewModel.userLocation else {
            // Location unavailable - user will see it in the UI state
            return
        }

        let coordinate = userLocation.coordinate

        Task {
            await coordinator.selectLocation(
                coordinate: coordinate,
                name: "Current Location",
                isPickup: true
            )

            pickupText = "Current Location"

            let geocodingService = MapServiceFactory.shared.createGeocodingService()
            if let address = try? await geocodingService.reverseGeocode(coordinate: coordinate) {
                pickupText = address
            }
        }
    }

    // MARK: - Status Banner Helpers

    private var shouldShowStatusBanner: Bool {
        coordinator.flowController.legacyState == .rideRequested ||
        coordinator.flowController.legacyState == .searchingForDriver ||
        coordinator.flowController.legacyState == .driverFound ||
        coordinator.flowController.legacyState == .driverEnRoute
    }

    private var statusBannerTitle: String {
        switch coordinator.flowController.legacyState {
        case .rideRequested, .searchingForDriver:
            return "Finding your driver..."
        case .driverFound:
            return "Driver Found!"
        case .driverEnRoute:
            return "Driver is on the way!"
        default:
            return ""
        }
    }

    private var statusBannerSubtitle: String? {
        switch coordinator.flowController.legacyState {
        case .driverFound:
            if let eta = coordinator.flowController.estimatedArrival {
                let minutes = Int(eta / 60)
                return "Arriving in \(minutes) min"
            }
            return nil
        case .driverEnRoute:
            if let eta = coordinator.flowController.estimatedArrival {
                let minutes = Int(eta / 60)
                return "ETA: \(minutes) min"
            }
            return "Your driver is heading to your location"
        default:
            return nil
        }
    }

    // MARK: - Format Helpers

    private func formatTravelTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return "\(minutes) min"
    }

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.34
        return String(format: "%.1f mi", miles)
    }
}

#Preview {
    ProductionExampleView()
}
