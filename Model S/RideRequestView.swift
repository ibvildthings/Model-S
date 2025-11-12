//
//  RideRequestView.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI

struct RideRequestView: View {
    @StateObject private var mapViewModel = MapViewModel()
    @State private var pickupText = "Current Location"
    @State private var destinationText = ""
    @FocusState private var focusedField: RideLocationCard.LocationField?
    @State private var showSlider = false
    @State private var rideState: RideRequestState = .selectingPickup

    var onPickupSelected: ((String) -> Void)?
    var onDestinationSelected: ((String) -> Void)?
    var onConfirmRide: (() -> Void)?

    var body: some View {
        ZStack {
            // Map Background
            RideMapView(viewModel: mapViewModel)
                .ignoresSafeArea()

            // Location Card Overlay (Top)
            VStack {
                RideLocationCard(
                    pickupText: $pickupText,
                    destinationText: $destinationText,
                    focusedField: $focusedField,
                    onPickupTap: {
                        focusedField = .pickup
                        rideState = .selectingPickup
                    },
                    onDestinationTap: {
                        focusedField = .destination
                        rideState = .selectingDestination
                    }
                )
                .padding(.top, 60)
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

                    RideConfirmSlider(onConfirmRide: {
                        rideState = .rideRequested
                        onConfirmRide?()
                    })
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
        }
    }

    private func updateSliderVisibility() {
        withAnimation(.easeInOut(duration: 0.4)) {
            showSlider = !pickupText.isEmpty && !destinationText.isEmpty
        }
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
