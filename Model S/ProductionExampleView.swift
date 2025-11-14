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
    @StateObject private var rideViewModel = RideRequestViewModel()
    @State private var showRideRequest = true

    var body: some View {
        ZStack {
            if showRideRequest {
                // Production-ready RideRequestView with full integration
                RideRequestViewWithViewModel(
                    viewModel: rideViewModel,
                    configuration: productionConfig,
                    onRideConfirmed: handleRideConfirmed,
                    onCancel: {
                        showRideRequest = false
                    }
                )
            } else {
                // Your main app UI
                MainAppPlaceholder(onRequestRide: {
                    rideViewModel.reset()
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

    private func handleRideConfirmed(pickup: LocationPoint, destination: LocationPoint) {
        // In production, you would:
        // 1. Submit ride request to your backend
        // 2. Start driver search
        // 3. Navigate to ride tracking screen

        print("Ride confirmed!")
        print("Pickup: \(pickup.name ?? "Unknown"), \(pickup.coordinate)")
        print("Destination: \(destination.name ?? "Unknown"), \(destination.coordinate)")

        if let eta = rideViewModel.formattedTravelTime(),
           let distance = rideViewModel.formattedDistance() {
            print("ETA: \(eta), Distance: \(distance)")
        }

        // Save ride to history
        saveRideToHistory(pickup: pickup, destination: destination)

        // Example: Send to backend
        // Task {
        //     await submitRideRequest(pickup: pickup, destination: destination)
        // }
    }

    private func saveRideToHistory(pickup: LocationPoint, destination: LocationPoint) {
        // Extract ride details from viewModel
        let distance = rideViewModel.estimatedDistance ?? 0
        let travelTime = rideViewModel.estimatedTravelTime ?? 0
        let pickupAddress = rideViewModel.pickupAddress.isEmpty ? (pickup.name ?? "Unknown") : rideViewModel.pickupAddress
        let destinationAddress = rideViewModel.destinationAddress.isEmpty ? (destination.name ?? "Unknown") : rideViewModel.destinationAddress

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

    var onRideConfirmed: (LocationPoint, LocationPoint) -> Void
    var onCancel: () -> Void

    init(
        viewModel: RideRequestViewModel,
        configuration: RideRequestConfiguration = .default,
        onRideConfirmed: @escaping (LocationPoint, LocationPoint) -> Void,
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

            VStack {
                // Error Banner
                if let error = coordinator.viewModel.error {
                    ErrorBannerView(error: error, onDismiss: {
                        coordinator.viewModel.error = nil
                    })
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Location Card with Autocomplete
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
                .padding(.top, coordinator.viewModel.error != nil ? 8 : 60)

                // Route Info
                if coordinator.viewModel.route != nil {
                    RouteInfoView(
                        travelTime: coordinator.viewModel.formattedTravelTime(),
                        distance: coordinator.viewModel.formattedDistance()
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Cancel Button
                if coordinator.viewModel.rideState != .rideRequested {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.red)
                    .padding(.bottom, 8)
                }
            }

            // Confirm Slider (managed by coordinator)
            if coordinator.showConfirmSlider {
                VStack {
                    Spacer()

                    RideConfirmSlider(
                        configuration: RideRequestConfiguration.default,
                        onConfirmRide: handleConfirmRide
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Status Banner - Shows different states of ride request
            if shouldShowStatusBanner {
                VStack {
                    VStack(spacing: 16) {
                        // Status Header
                        HStack {
                            if coordinator.viewModel.rideState == .searchingForDriver {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else if coordinator.viewModel.rideState == .driverFound {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 24))
                            } else if coordinator.viewModel.rideState == .driverEnRoute {
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
                        }

                        // Driver Info (when found)
                        if let driver = coordinator.viewModel.currentDriver,
                           coordinator.viewModel.rideState != .searchingForDriver {
                            Divider()
                                .background(Color.white.opacity(0.3))

                            HStack(spacing: 12) {
                                // Driver avatar placeholder
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white.opacity(0.7))
                                    )

                                VStack(alignment: .leading, spacing: 4) {
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
                                        .foregroundColor(.white.opacity(0.7))
                                }

                                Spacer()
                            }
                        }

                        // Cancel Button
                        if coordinator.viewModel.rideState == .searchingForDriver ||
                           coordinator.viewModel.rideState == .rideRequested {
                            Button(action: {
                                coordinator.cancelRideRequest()
                            }) {
                                Text("Cancel Request")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .padding(.top, 60)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Loading Overlay
            if coordinator.viewModel.isLoading {
                Color.black.opacity(0.2)
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
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 60)
                    .padding(.trailing, 16)
                }

                Spacer()
            }
        }
        .onChange(of: pickupText) { newValue in
            coordinator.viewModel.pickupAddress = newValue
        }
        .onChange(of: destinationText) { newValue in
            coordinator.viewModel.destinationAddress = newValue
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
            onRideConfirmed(result.pickup, result.destination)

            // Start the ride request flow in a detached task (outside view update cycle)
            Task {
                await coordinator.startRideRequest()
            }
        }
    }

    private func handleUseCurrentLocation() {
        guard let userLocation = coordinator.mapViewModel.userLocation else {
            coordinator.viewModel.error = .locationUnavailable
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
        coordinator.viewModel.rideState == .rideRequested ||
        coordinator.viewModel.rideState == .searchingForDriver ||
        coordinator.viewModel.rideState == .driverFound ||
        coordinator.viewModel.rideState == .driverEnRoute
    }

    private var statusBannerTitle: String {
        switch coordinator.viewModel.rideState {
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
        switch coordinator.viewModel.rideState {
        case .driverFound:
            if let eta = coordinator.viewModel.estimatedDriverArrival {
                let minutes = Int(eta / 60)
                return "Arriving in \(minutes) min"
            }
            return nil
        case .driverEnRoute:
            if let eta = coordinator.viewModel.estimatedDriverArrival {
                let minutes = Int(eta / 60)
                return "ETA: \(minutes) min"
            }
            return "Your driver is heading to your location"
        default:
            return nil
        }
    }
}

#Preview {
    ProductionExampleView()
}
