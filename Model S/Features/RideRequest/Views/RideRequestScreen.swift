//
//  RideRequestScreen.swift
//  Model S
//
//  The rider's main screen: full-screen map, location card with autocomplete,
//  slide-to-confirm, and a status banner once a ride is requested.
//  All business logic lives in RideRequestCoordinator / RideFlowController;
//  this view only renders state and forwards user intents.
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI
import CoreLocation

struct RideRequestScreen: View {
    @ObservedObject var coordinator: RideRequestCoordinator

    @State private var pickupText = "Current Location"
    @State private var destinationText = ""
    @FocusState private var focusedField: RideLocationField?
    @State private var showRideHistory = false

    private let configuration = RideRequestConfiguration.default

    private var flow: RideFlowController { coordinator.flowController }

    var body: some View {
        ZStack(alignment: .top) {
            // Map - full screen hero element
            RideMapView(viewModel: coordinator.mapViewModel, configuration: configuration)
                .ignoresSafeArea()

            if flow.legacyState.showsStatusBanner {
                VStack(spacing: 8) {
                    providerSwitcher
                    RideStatusBanner(flowController: flow, onCancel: { coordinator.cancelRideRequest() })
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                VStack(spacing: 8) {
                    providerSwitcher

                    if let error = flow.currentError {
                        ErrorBannerView(error: error, onDismiss: {
                            DispatchQueue.main.async {
                                flow.clearError()
                            }
                        })
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()

                    bookingSheet
                }
            }

            // Loading overlay while the request is being submitted
            if flow.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showRideHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
                .accessibilityLabel("Ride history")
            }
        }
        .sheet(isPresented: $showRideHistory) {
            RideHistoryView()
        }
    }

    // MARK: - Subviews

    private var providerSwitcher: some View {
        HStack {
            MapProviderSwitcher()
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// Bottom sheet: route summary, location card, confirm slider
    private var bookingSheet: some View {
        VStack(spacing: 0) {
            if let routeInfo = flow.routeInfo {
                RouteInfoView(route: routeInfo)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            RideLocationCardWithSearch(
                pickupText: $pickupText,
                destinationText: $destinationText,
                focusedField: $focusedField,
                configuration: configuration,
                userLocation: coordinator.mapViewModel.userLocation?.coordinate,
                onPickupTap: { focusedField = .pickup },
                onDestinationTap: { focusedField = .destination },
                onLocationSelected: { coordinate, name, isPickup in
                    coordinator.selectLocation(coordinate: coordinate, name: name, isPickup: isPickup)
                },
                onUseCurrentLocation: handleUseCurrentLocation
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))

            if coordinator.shouldShowConfirmSlider {
                RideConfirmSlider(
                    configuration: configuration,
                    onConfirmRide: handleConfirmRide
                )
                .padding(.horizontal, 32)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                #if DEBUG
                quickTestButton
                #endif
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
        .padding(.bottom, -8) // Extend slightly beyond safe area
    }

    #if DEBUG
    /// Fills a random pair of SF landmarks (debug builds only)
    private var quickTestButton: some View {
        Button(action: fillSampleRide) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13))
                Text("Quick Test")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.orange)
            .cornerRadius(10)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func fillSampleRide() {
        guard let ride = SampleRides.all.randomElement() else { return }
        AppLog.debug("🎲 Sample ride: \(ride.pickup.name ?? "?") → \(ride.destination.name ?? "?")")

        Task {
            coordinator.selectLocation(coordinate: ride.pickup.coordinate, name: ride.pickup.name ?? "", isPickup: true)
            pickupText = ride.pickup.name ?? ""

            // Small delay so the user can see it happening
            try? await Task.sleep(nanoseconds: 300_000_000)

            coordinator.selectLocation(coordinate: ride.destination.coordinate, name: ride.destination.name ?? "", isPickup: false)
            destinationText = ride.destination.name ?? ""
        }
    }
    #endif

    // MARK: - Actions

    private func handleConfirmRide() {
        guard let confirmed = coordinator.confirmRide() else { return }

        saveRideToHistory(pickup: confirmed.pickup, destination: confirmed.destination, route: flow.routeInfo)

        // Start the request outside the view update cycle
        Task {
            await coordinator.startRideRequest()
        }
    }

    private func handleUseCurrentLocation() {
        guard let coordinate = coordinator.mapViewModel.userLocation?.coordinate else { return }

        coordinator.selectLocation(coordinate: coordinate, name: "Current Location", isPickup: true)
        pickupText = "Current Location"

        Task {
            if let address = try? await MapProviderService.shared.currentService.reverseGeocode(coordinate: coordinate) {
                pickupText = address
            }
        }
    }

    private func saveRideToHistory(pickup: LocationPoint, destination: LocationPoint, route: RouteInfo?) {
        let ride = RideHistory(
            pickupLocation: pickup,
            destinationLocation: destination,
            distance: route?.distance ?? 0,
            estimatedTravelTime: route?.estimatedTravelTime ?? 0,
            pickupAddress: pickup.name ?? "Unknown",
            destinationAddress: destination.name ?? "Unknown"
        )
        RideHistoryStore.shared.addRide(ride)
    }
}

#Preview {
    @Previewable @StateObject var coordinator = RideRequestCoordinator()
    NavigationStack {
        RideRequestScreen(coordinator: coordinator)
    }
}
