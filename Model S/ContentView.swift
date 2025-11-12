//
//  ContentView.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var mapViewModel = MapViewModel()
    @State private var pickupText = "Current Location"
    @State private var destinationText = ""
    @FocusState private var focusedField: RideLocationCard.LocationField?
    @State private var showSlider = false

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
                    },
                    onDestinationTap: {
                        focusedField = .destination
                    }
                )
                .padding(.top, 60)
                .onChange(of: destinationText) { _ in
                    // Show slider when both locations are set
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showSlider = !pickupText.isEmpty && !destinationText.isEmpty
                    }
                }

                Spacer()
            }

            // Confirm Slider (Bottom)
            if showSlider {
                VStack {
                    Spacer()

                    RideConfirmSlider(onConfirmRide: {
                        print("Ride requested!")
                        // Handle ride request
                    })
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
