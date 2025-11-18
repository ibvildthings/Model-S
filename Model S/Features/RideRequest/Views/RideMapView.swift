//
//  RideMapView.swift
//  Model S
//
//  Universal map view that switches between Apple Maps and Google Maps
//  based on the configured map provider.
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI
import MapKit

struct RideMapView: View {
    @ObservedObject var viewModel: MapViewModel
    var configuration: RideRequestConfiguration = .default

    // Observe map provider preference for dynamic switching
    @StateObject private var providerPreference = MapProviderPreference.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Map view
            Group {
                switch providerPreference.selectedProvider {
                case .apple:
                    appleMapView
                case .google:
                    googleMapView
                }
            }
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
            .onChange(of: viewModel.driverLocation) { _ in
                if viewModel.driverLocation != nil {
                    hapticFeedback()
                }
            }
            .accessibilityLabel("Ride request map - \(providerPreference.selectedProvider == .apple ? "Apple Maps" : "Google Maps")")

            // Map provider switcher control
            mapProviderSwitcher
                .padding(.top, 50) // Below status bar
                .padding(.trailing, 16)
        }
    }

    // MARK: - Map Provider Switcher

    private var mapProviderSwitcher: some View {
        Picker("Map Provider", selection: $providerPreference.selectedProvider) {
            ForEach(MapProvider.allCases, id: \.id) { provider in
                Text(provider == .apple ? "Apple" : "Google")
                    .tag(provider)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 160)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
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
