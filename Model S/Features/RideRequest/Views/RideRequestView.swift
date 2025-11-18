//
//  RideRequestView.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI

/// A reusable SwiftUI component that provides a complete ride request experience
/// with an interactive map, location inputs, and slide-to-confirm interaction.
///
/// Example usage:
/// ```swift
/// RideRequestView(
///     onPickupSelected: { location in
///         print("Pickup: \(location)")
///     },
///     onDestinationSelected: { location in
///         print("Destination: \(location)")
///     },
///     onConfirmRide: {
///         print("Ride confirmed!")
///     }
/// )
/// ```
struct RideRequestView: View {
    @StateObject private var mapViewModel = MapViewModel()
    @State private var pickupText: String
    @State private var destinationText = ""
    @FocusState private var focusedField: RideLocationCard.LocationField?
    @State private var showSlider = false
    @State private var rideState: RideRequestState = .selectingPickup

    var configuration: RideRequestConfiguration = .default
    var onPickupSelected: ((String) -> Void)?
    var onDestinationSelected: ((String) -> Void)?
    var onConfirmRide: (() -> Void)?

    /// Creates a new RideRequestView with optional configuration and callbacks
    ///
    /// - Parameters:
    ///   - configuration: Visual and behavioral configuration options. Defaults to `.default`.
    ///   - onPickupSelected: Called when the pickup location text changes.
    ///   - onDestinationSelected: Called when the destination location text changes.
    ///   - onConfirmRide: Called when the user completes the slide-to-confirm gesture.
    init(
        configuration: RideRequestConfiguration = .default,
        onPickupSelected: ((String) -> Void)? = nil,
        onDestinationSelected: ((String) -> Void)? = nil,
        onConfirmRide: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        self._pickupText = State(initialValue: configuration.defaultPickupText)
        self.onPickupSelected = onPickupSelected
        self.onDestinationSelected = onDestinationSelected
        self.onConfirmRide = onConfirmRide
    }

    var body: some View {
        ZStack {
            // Map Background
            RideMapView(viewModel: mapViewModel, configuration: configuration)
                .ignoresSafeArea()

            // Overlays
            VStack(spacing: 0) {
                // Map provider switcher at the very top
                MapProviderSwitcher()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .background(Color.clear) // Ensure it's not transparent/invisible

                Spacer()
                    .frame(height: 12)

                // Location Card
                RideLocationCard(
                    pickupText: $pickupText,
                    destinationText: $destinationText,
                    focusedField: $focusedField,
                    configuration: configuration,
                    onPickupTap: {
                        focusedField = .pickup
                        rideState = .selectingPickup
                    },
                    onDestinationTap: {
                        focusedField = .destination
                        rideState = .selectingDestination
                    }
                )
                .onChange(of: pickupText) { newValue in
                    onPickupSelected?(newValue)
                    updateSliderVisibility()
                }
                .onChange(of: destinationText) { newValue in
                    onDestinationSelected?(newValue)
                    updateSliderVisibility()

                    // Update ride state
                    if !newValue.isEmpty && !pickupText.isEmpty {
                        rideState = .routeReady
                    }
                }

                Spacer()
            }

            // Confirm Slider (Bottom)
            if showSlider && rideState == .routeReady {
                VStack {
                    Spacer()

                    RideConfirmSlider(
                        configuration: configuration,
                        onConfirmRide: {
                            rideState = .rideRequested
                            onConfirmRide?()
                        }
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Status Banner (when ride is requested)
            if rideState == .rideRequested {
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
        }
    }

    private func updateSliderVisibility() {
        withAnimation(.easeInOut(duration: 0.4)) {
            showSlider = !pickupText.isEmpty && !destinationText.isEmpty
        }
    }
}

// MARK: - Map Provider Switcher

/// Segmented control to switch between Apple Maps and Google Maps
struct MapProviderSwitcher: View {
    // Using @StateObject ensures stable observation of the singleton across view updates
    // This is the correct pattern for observing a singleton in SwiftUI
    @StateObject private var providerPreference = MapProviderPreference.shared

    var body: some View {
        Picker("Map Provider", selection: $providerPreference.selectedProvider) {
            ForEach(MapProvider.allCases, id: \.self) { provider in
                Text(provider == .apple ? "Apple" : "Google")
                    .tag(provider)
            }
        }
        .pickerStyle(.segmented)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red, lineWidth: 3)  // DEBUG: Bright red border so we can see it
        )
    }
}

// MARK: - Preview
#Preview {
    RideRequestView(
        onPickupSelected: { location in
            print("Pickup selected: \(location)")
        },
        onDestinationSelected: { location in
            print("Destination selected: \(location)")
        },
        onConfirmRide: {
            print("Ride confirmed!")
        }
    )
}
