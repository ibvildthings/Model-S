//
//  RideMapView.swift
//  Model S
//
//  Universal map view that switches between Apple Maps and Google Maps
//  based on the configured map provider.
//  Refactored to use unified MapProviderService architecture
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI
import MapKit

struct RideMapView: View {
    @ObservedObject var viewModel: MapViewModel
    var configuration: RideRequestConfiguration = .default

    // Observe map provider service for dynamic switching
    @StateObject private var providerService = MapProviderService.shared

    var body: some View {
        // Map view - switches based on current provider
        Group {
            switch providerService.currentProvider {
            case .apple:
                appleMapView
            case .google:
                googleMapView
            }
        }
        .onChange(of: viewModel.pickupLocation) {
            if viewModel.pickupLocation != nil {
                hapticFeedback()
            }
        }
        .onChange(of: viewModel.destinationLocation) {
            if viewModel.destinationLocation != nil {
                hapticFeedback()
            }
        }
        .onChange(of: viewModel.driverLocation) {
            if viewModel.driverLocation != nil {
                hapticFeedback()
            }
        }
        .accessibilityLabel("Ride request map - \(providerService.currentProvider.displayName)")
    }

    // MARK: - Apple Maps View

    private var appleMapView: some View {
        MapViewWrapper(
            region: $viewModel.region,
            pickupLocation: viewModel.pickupLocation?.coordinate,
            destinationLocation: viewModel.destinationLocation?.coordinate,
            driverLocation: viewModel.driverLocation,
            route: viewModel.routePolyline,  // Now provider-agnostic [CLLocationCoordinate2D]
            driverRoute: viewModel.driverRoutePolyline,  // Now provider-agnostic [CLLocationCoordinate2D]
            routeDisplayMode: viewModel.routeDisplayMode,
            showsUserLocation: true,
            routeLineColor: configuration.routeLineColor,
            routeLineWidth: configuration.routeLineWidth
        )
    }

    // MARK: - Google Maps View

    private var googleMapView: some View {
        GoogleMapViewWrapper(
            region: $viewModel.region,
            pickupLocation: viewModel.pickupLocation?.coordinate,
            destinationLocation: viewModel.destinationLocation?.coordinate,
            driverLocation: viewModel.driverLocation,
            route: viewModel.routePolyline,  // Provider-agnostic [CLLocationCoordinate2D]
            driverRoute: viewModel.driverRoutePolyline,  // Provider-agnostic [CLLocationCoordinate2D]
            routeDisplayMode: viewModel.routeDisplayMode,
            showsUserLocation: true,
            routeLineColor: configuration.routeLineColor,
            routeLineWidth: configuration.routeLineWidth
        )
    }

    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Preview
#Preview("Apple Maps") {
    RideMapView(viewModel: MapViewModel())
}

#Preview("Google Maps") {
    let _ = MapServiceFactory.shared.configure(with: .google)
    return RideMapView(viewModel: MapViewModel())
}
