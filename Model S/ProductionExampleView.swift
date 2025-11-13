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
struct RideRequestViewWithViewModel: View {
    @ObservedObject var viewModel: RideRequestViewModel
    @StateObject private var mapViewModel = MapViewModel()
    @State private var pickupText: String
    @State private var destinationText = ""
    @FocusState private var focusedField: RideLocationCard.LocationField?
    @State private var showSlider = false
    @State private var debounceTask: Task<Void, Never>?

    var configuration: RideRequestConfiguration
    var onRideConfirmed: (LocationPoint, LocationPoint) -> Void
    var onCancel: () -> Void

    init(
        viewModel: RideRequestViewModel,
        configuration: RideRequestConfiguration = .default,
        onRideConfirmed: @escaping (LocationPoint, LocationPoint) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.configuration = configuration
        self._pickupText = State(initialValue: configuration.defaultPickupText)
        self.onRideConfirmed = onRideConfirmed
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            // Map
            RideMapView(viewModel: mapViewModel, configuration: configuration)
                .ignoresSafeArea()

            VStack {
                // Error Banner
                if configuration.showErrorBanner,
                   let error = viewModel.error {
                    ErrorBannerView(error: error, onDismiss: {
                        viewModel.error = nil
                    })
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Location Card with Autocomplete
                RideLocationCardWithSearch(
                    pickupText: $pickupText,
                    destinationText: $destinationText,
                    focusedField: $focusedField,
                    configuration: configuration,
                    onPickupTap: {
                        focusedField = .pickup
                        viewModel.rideState = .selectingPickup
                    },
                    onDestinationTap: {
                        focusedField = .destination
                        viewModel.rideState = .selectingDestination
                    },
                    onLocationSelected: { coordinate, name, isPickup in
                        handleLocationSelection(coordinate: coordinate, name: name, isPickup: isPickup)
                    }
                )
                .padding(.top, configuration.showErrorBanner && viewModel.error != nil ? 8 : 60)

                // Route Info
                if configuration.showRouteInfo,
                   viewModel.route != nil {
                    RouteInfoView(
                        travelTime: viewModel.formattedTravelTime(),
                        distance: viewModel.formattedDistance()
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Cancel Button
                if viewModel.rideState != .rideRequested {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.red)
                    .padding(.bottom, 8)
                }
            }

            // Confirm Slider
            if showSlider {
                VStack {
                    Spacer()

                    RideConfirmSlider(
                        configuration: configuration,
                        onConfirmRide: handleConfirmRide
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Status Banner
            if viewModel.rideState == .rideRequested {
                VStack {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))

                        Text(configuration.findingDriverText)
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
            if viewModel.isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()

                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .onChange(of: viewModel.route) { route in
            if let route = route {
                mapViewModel.updateRouteFromMKRoute(route)
            }
        }
        .task {
            // Setup location callback
            mapViewModel.onLocationUpdate = { location in
                if configuration.autoSetPickupLocation,
                   viewModel.pickupLocation == nil {
                    Task {
                        await viewModel.reverseGeocodeLocation(location.coordinate, isPickup: true)
                        pickupText = viewModel.pickupAddress
                    }
                }
            }
        }
    }

    private func handleLocationSelection(coordinate: CLLocationCoordinate2D, name: String, isPickup: Bool) {
        // Cancel any pending geocoding
        debounceTask?.cancel()

        // Update ViewModels directly with the selected location
        let locationPoint = LocationPoint(coordinate: coordinate, name: name)

        if isPickup {
            viewModel.pickupLocation = locationPoint
            viewModel.pickupAddress = name
            mapViewModel.updatePickupLocation(coordinate, name: name)
        } else {
            viewModel.destinationLocation = locationPoint
            viewModel.destinationAddress = name
            mapViewModel.updateDestinationLocation(coordinate, name: name)
        }

        // Calculate route if both locations are set
        if configuration.enableRouteCalculation,
           viewModel.pickupLocation != nil,
           viewModel.destinationLocation != nil {
            Task {
                await viewModel.calculateRoute()
                if let route = viewModel.route {
                    mapViewModel.updateRouteFromMKRoute(route)
                }
            }
        }

        updateSliderVisibility()
    }

    private func debounceGeocoding(_ text: String, isPickup: Bool) {
        debounceTask?.cancel()

        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(configuration.geocodingDebounceDelay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await viewModel.geocodeAddress(text, isPickup: isPickup)

            if let location = isPickup ? viewModel.pickupLocation : viewModel.destinationLocation {
                if isPickup {
                    mapViewModel.updatePickupLocation(location.coordinate, name: location.name)
                } else {
                    mapViewModel.updateDestinationLocation(location.coordinate, name: location.name)
                }
            }

            updateSliderVisibility()
        }
    }

    private func updateSliderVisibility() {
        withAnimation(.easeInOut(duration: 0.4)) {
            showSlider = !pickupText.isEmpty && !destinationText.isEmpty
        }
    }

    private func handleConfirmRide() {
        // If geocoding is still in progress, wait for it
        if configuration.enableGeocoding {
            if viewModel.pickupLocation == nil || viewModel.destinationLocation == nil {
                viewModel.error = .geocodingFailed
                return
            }
        }

        guard configuration.enableValidation else {
            proceedWithRideRequest()
            return
        }

        if viewModel.validateLocations() {
            proceedWithRideRequest()
        }
    }

    private func proceedWithRideRequest() {
        guard let pickup = viewModel.pickupLocation,
              let destination = viewModel.destinationLocation else {
            viewModel.error = .invalidPickupLocation
            return
        }

        viewModel.rideState = .rideRequested
        onRideConfirmed(pickup, destination)
    }
}

#Preview {
    ProductionExampleView()
}
