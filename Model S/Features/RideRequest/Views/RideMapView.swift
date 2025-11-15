//
//  RideMapView.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI
import MapKit

struct RideMapView: View {
    @ObservedObject var viewModel: MapViewModel
    var configuration: RideRequestConfiguration = .default

    var body: some View {
        MapViewWrapper(
            region: $viewModel.region,
            pickupLocation: viewModel.pickupLocation?.coordinate,
            destinationLocation: viewModel.destinationLocation?.coordinate,
            route: viewModel.routePolyline as? MKPolyline,
            showsUserLocation: true,
            routeLineColor: configuration.routeLineColor,
            routeLineWidth: configuration.routeLineWidth
        )
        .onChange(of: viewModel.pickupLocation) { _ in
            if viewModel.pickupLocation != nil {
                hapticFeedback()
            }
        }
        .onChange(of: viewModel.destinationLocation) { _ in
            if viewModel.destinationLocation != nil {
                hapticFeedback()
            }
        }
        .accessibilityLabel("Ride request map")
    }

    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Preview
#Preview {
    RideMapView(viewModel: MapViewModel())
}
