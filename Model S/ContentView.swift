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

    var body: some View {
        ZStack(alignment: .top) {
            // Map Background
            RideMapView(viewModel: mapViewModel)
                .ignoresSafeArea()

            // Location Card Overlay
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

                Spacer()
            }
        }
    }
}

#Preview {
    ContentView()
}
