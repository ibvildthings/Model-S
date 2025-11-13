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

        // Example: Send to backend
        // Task {
        //     await submitRideRequest(pickup: pickup, destination: destination)
        // }
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
        self._pickupText = State(initialValue: configuration.defaultPickupText)
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

            // Status Banner
            if coordinator.viewModel.rideState == .rideRequested {
                VStack {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))

                        Text("Finding your driver...")
                            .font(.headline)
                            .foregroundColor(.white)
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
        }
        .onChange(of: pickupText) { newValue in
            coordinator.viewModel.pickupAddress = newValue
        }
        .onChange(of: destinationText) { newValue in
            coordinator.viewModel.destinationAddress = newValue
        }
    }

    // MARK: - Actions
    // All complex logic is now in the coordinator - view is just presentation!

    private func handleConfirmRide() {
        // Coordinator handles all validation and state management
        if let result = coordinator.confirmRide() {
            onRideConfirmed(result.pickup, result.destination)
        }
    }
}

#Preview {
    ProductionExampleView()
}
