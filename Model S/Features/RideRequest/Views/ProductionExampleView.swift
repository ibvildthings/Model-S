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
    @State private var showRideRequest = true

    var body: some View {
        ZStack {
            if showRideRequest {
                // Production-ready RideRequestView with full integration
                RideRequestViewWithViewModel(
                    configuration: productionConfig,
                    onRideConfirmed: handleRideConfirmed,
                    onCancel: {
                        showRideRequest = false
                    }
                )
            } else {
                // Your main app UI
                MainAppPlaceholder(onRequestRide: {
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

    private func handleRideConfirmed(pickup: LocationPoint, destination: LocationPoint, route: RouteInfo?) {
        // In production, you would:
        // 1. Submit ride request to your backend
        // 2. Start driver search
        // 3. Navigate to ride tracking screen

        print("Ride confirmed!")
        print("Pickup: \(pickup.name ?? "Unknown"), \(pickup.coordinate)")
        print("Destination: \(destination.name ?? "Unknown"), \(destination.coordinate)")

        if let route = route {
            let minutes = Int(route.estimatedTravelTime / 60)
            let miles = route.distance / 1609.34
            print("ETA: \(minutes) min, Distance: \(String(format: "%.1f mi", miles))")
        }

        // Save ride to history
        saveRideToHistory(pickup: pickup, destination: destination, route: route)

        // Example: Send to backend
        // Task {
        //     await submitRideRequest(pickup: pickup, destination: destination)
        // }
    }

    private func saveRideToHistory(pickup: LocationPoint, destination: LocationPoint, route: RouteInfo?) {
        // Extract ride details from route
        let distance = route?.distance ?? 0
        let travelTime = route?.estimatedTravelTime ?? 0
        let pickupAddress = pickup.name ?? "Unknown"
        let destinationAddress = destination.name ?? "Unknown"

        // Create ride history entry
        let ride = RideHistory(
            pickupLocation: pickup,
            destinationLocation: destination,
            distance: distance,
            estimatedTravelTime: travelTime,
            pickupAddress: pickupAddress,
            destinationAddress: destinationAddress
        )

        // Save to persistent storage
        RideHistoryStore.shared.addRide(ride)

        print("✅ Ride saved to history: \(ride.formattedDistance), \(ride.formattedTravelTime)")
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
    @State private var showRideHistory = false

    var onRideConfirmed: (LocationPoint, LocationPoint, RouteInfo?) -> Void
    var onCancel: () -> Void

    init(
        configuration: RideRequestConfiguration = .default,
        onRideConfirmed: @escaping (LocationPoint, LocationPoint, RouteInfo?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        // Create coordinator with configuration
        self._coordinator = StateObject(wrappedValue: RideRequestCoordinator(configuration: configuration))
        self._pickupText = State(initialValue: configuration.defaultPickupText as String)
        self.onRideConfirmed = onRideConfirmed
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            // Map (managed by coordinator) - Full screen hero element
            RideMapView(viewModel: coordinator.mapViewModel, configuration: RideRequestConfiguration.default)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Error Banner - Compact top banner
                if let error = coordinator.flowController.currentError {
                    ErrorBannerView(error: error, onDismiss: {
                        DispatchQueue.main.async {
                            coordinator.flowController.clearError()
                        }
                    })
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Bottom Sheet - Main interaction area
                if !shouldShowStatusBanner {
                    VStack(spacing: 0) {
                        // Route Info - Compact banner above card when available
                        if let routeInfo = coordinator.flowController.routeInfo {
                            HStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                    Text(formatTravelTime(routeInfo.estimatedTravelTime))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }

                                Divider()
                                    .frame(height: 16)

                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.swap")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                    Text(formatDistance(routeInfo.distance))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        // Location Card - Now at bottom
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
                                Task {
                                    await coordinator.selectLocation(coordinate: coordinate, name: name, isPickup: isPickup)
                                }
                            },
                            onUseCurrentLocation: {
                                handleUseCurrentLocation()
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        // Confirm Slider - Integrated into bottom card
                        if coordinator.shouldShowConfirmSlider {
                            RideConfirmSlider(
                                configuration: RideRequestConfiguration.default,
                                onConfirmRide: handleConfirmRide
                            )
                            .padding(.horizontal, 32)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        // TEMPORARY: Quick Test Button
                        if !coordinator.shouldShowConfirmSlider {
                            Button(action: fillTestLocations) {
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
                    }
                    .background(.ultraThinMaterial)
                    .cornerRadius(20, corners: [.topLeft, .topRight])
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
                    .padding(.bottom, -8) // Extend slightly beyond safe area
                }
            }

            // Compact Status Banner at Top
            if shouldShowStatusBanner {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Status Icon
                        Group {
                            switch coordinator.flowController.legacyState {
                            case .searchingForDriver, .rideRequested:
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.9)
                            case .driverFound, .rideCompleted:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 20))
                            case .driverEnRoute, .driverArriving:
                                Image(systemName: "car.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 18))
                            case .rideInProgress, .approachingDestination:
                                Image(systemName: "figure.walk")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 18))
                            default:
                                EmptyView()
                            }
                        }

                        // Status Text
                        VStack(alignment: .leading, spacing: 2) {
                            Text(statusBannerTitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            if let subtitle = statusBannerSubtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Driver Info - Compact
                        if let driver = coordinator.flowController.driver,
                           coordinator.flowController.legacyState != .searchingForDriver {
                            HStack(spacing: 8) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(driver.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    HStack(spacing: 3) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(.system(size: 10))
                                        Text(String(format: "%.1f", driver.rating))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 16))
                                    )
                            }
                        }

                        // Cancel Button - Icon only
                        if coordinator.flowController.legacyState == .searchingForDriver ||
                           coordinator.flowController.legacyState == .rideRequested {
                            Button(action: {
                                coordinator.cancelRideRequest()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Loading Overlay
            if coordinator.flowController.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showRideHistory = true
                }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showRideHistory) {
            RideHistoryView()
        }
    }

    // MARK: - Actions
    // All complex logic is now in the coordinator - view is just presentation!

    // TEMPORARY: Quick test locations - Remove before production
    private func fillTestLocations() {
        // Define 10 different test location pairs in Cupertino/San Jose area
        let testLocationPairs: [(pickup: (coord: CLLocationCoordinate2D, name: String), destination: (coord: CLLocationCoordinate2D, name: String))] = [
            // Pair 1: Apple Park to Izumi Matcha
            (
                pickup: (CLLocationCoordinate2D(latitude: 37.3323, longitude: -122.0312), "Apple Park Visitor Center"),
                destination: (CLLocationCoordinate2D(latitude: 37.3218, longitude: -122.0182), "Izumi Matcha")
            ),
            // Pair 2: De Anza College to Valley Fair Mall
            (
                pickup: (CLLocationCoordinate2D(latitude: 37.3197, longitude: -122.0450), "De Anza College"),
                destination: (CLLocationCoordinate2D(latitude: 37.3238, longitude: -121.9950), "Westfield Valley Fair")
            ),
            // Pair 3: Cupertino Library to Main Street Cupertino
            (
                pickup: (CLLocationCoordinate2D(latitude: 37.3230, longitude: -122.0416), "Cupertino Library"),
                destination: (CLLocationCoordinate2D(latitude: 37.3226, longitude: -122.0310), "Main Street Cupertino")
            ),
            // Pair 4: Santana Row to San Jose Airport
            (
                pickup: (CLLocationCoordinate2D(latitude: 37.3213, longitude: -121.9488), "Santana Row"),
                destination: (CLLocationCoordinate2D(latitude: 37.3639, longitude: -121.9289), "San Jose Airport")
            ),
            // Pair 5: Stevens Creek Trail to Whole Foods
            (
                pickup: (CLLocationCoordinate2D(latitude: 37.3234, longitude: -122.0086), "Stevens Creek Trail"),
                destination: (CLLocationCoordinate2D(latitude: 37.3315, longitude: -122.0297), "Whole Foods Cupertino")
            ),
            // Pair 6: Sunnyvale Caltrain to Murphy Avenue
            (
                pickup: (CLLocationCoordinate2D(latitude: 37.3782, longitude: -122.0306), "Sunnyvale Caltrain Station"),
                destination: (CLLocationCoordinate2D(latitude: 37.3876, longitude: -122.0309), "Murphy Avenue")
            ),
            // Pair 7: San Jose State to SAP Center
            (
                pickup: (CLLocationCoordinate2D(latitude: 37.3352, longitude: -121.8811), "San Jose State University"),
                destination: (CLLocationCoordinate2D(latitude: 37.3329, longitude: -121.9010), "SAP Center")
            ),
            // Pair 8: Los Gatos Creek Trail to Downtown Los Gatos
            (
                pickup: (CLLocationCoordinate2D(latitude: 37.2358, longitude: -121.9623), "Los Gatos Creek Trail"),
                destination: (CLLocationCoordinate2D(latitude: 37.2271, longitude: -121.9752), "Downtown Los Gatos")
            ),
            // Pair 9: Rancho San Antonio to Foothill College
            (
                pickup: (CLLocationCoordinate2D(latitude: 37.3237, longitude: -122.0799), "Rancho San Antonio Preserve"),
                destination: (CLLocationCoordinate2D(latitude: 37.3606, longitude: -122.1262), "Foothill College")
            ),
            // Pair 10: Campbell Park to The Pruneyard
            (
                pickup: (CLLocationCoordinate2D(latitude: 37.2871, longitude: -121.9500), "Campbell Park"),
                destination: (CLLocationCoordinate2D(latitude: 37.2931, longitude: -121.9751), "The Pruneyard Shopping Center")
            )
        ]

        // Randomly select one pair
        let selectedPair = testLocationPairs.randomElement()!
        print("🎲 Randomly selected test locations: \(selectedPair.pickup.name) → \(selectedPair.destination.name)")

        Task {
            // Fill pickup
            await coordinator.selectLocation(
                coordinate: selectedPair.pickup.coord,
                name: selectedPair.pickup.name,
                isPickup: true
            )
            pickupText = selectedPair.pickup.name

            // Small delay so user can see it happening
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            // Fill destination
            await coordinator.selectLocation(
                coordinate: selectedPair.destination.coord,
                name: selectedPair.destination.name,
                isPickup: false
            )
            destinationText = selectedPair.destination.name
        }
    }

    private func handleConfirmRide() {
        // Coordinator handles all validation and state management
        if let result = coordinator.confirmRide() {
            // Get route info from flow controller
            let routeInfo = coordinator.flowController.routeInfo

            onRideConfirmed(result.pickup, result.destination, routeInfo)

            // Start the ride request flow in a detached task (outside view update cycle)
            Task {
                await coordinator.startRideRequest()
            }
        }
    }

    private func handleUseCurrentLocation() {
        guard let userLocation = coordinator.mapViewModel.userLocation else {
            // Location unavailable - user will see it in the UI state
            return
        }

        let coordinate = userLocation.coordinate

        Task {
            await coordinator.selectLocation(
                coordinate: coordinate,
                name: "Current Location",
                isPickup: true
            )

            pickupText = "Current Location"

            let geocodingService = MapServiceFactory.shared.createGeocodingService()
            if let address = try? await geocodingService.reverseGeocode(coordinate: coordinate) {
                pickupText = address
            }
        }
    }

    // MARK: - Status Banner Helpers

    private var shouldShowStatusBanner: Bool {
        coordinator.flowController.legacyState == .rideRequested ||
        coordinator.flowController.legacyState == .searchingForDriver ||
        coordinator.flowController.legacyState == .driverFound ||
        coordinator.flowController.legacyState == .driverEnRoute ||
        coordinator.flowController.legacyState == .driverArriving ||
        coordinator.flowController.legacyState == .rideInProgress ||
        coordinator.flowController.legacyState == .approachingDestination ||
        coordinator.flowController.legacyState == .rideCompleted
    }

    private var statusBannerTitle: String {
        switch coordinator.flowController.legacyState {
        case .rideRequested, .searchingForDriver:
            return "Finding your driver..."
        case .driverFound:
            return "Driver Found!"
        case .driverEnRoute:
            return "Driver is on the way!"
        case .driverArriving:
            return "Driver is arriving!"
        case .rideInProgress:
            return "Ride in progress"
        case .approachingDestination:
            return "Approaching destination"
        case .rideCompleted:
            return "Ride completed!"
        default:
            return ""
        }
    }

    private var statusBannerSubtitle: String? {
        switch coordinator.flowController.legacyState {
        case .driverFound:
            if let eta = coordinator.flowController.estimatedArrival {
                let minutes = Int(eta / 60)
                return "Arriving in \(minutes) min"
            }
            return nil
        case .driverEnRoute:
            if let eta = coordinator.flowController.estimatedArrival {
                let minutes = Int(eta / 60)
                return "ETA: \(minutes) min"
            }
            return "Your driver is heading to your location"
        case .driverArriving:
            return "Your driver will arrive in less than a minute"
        case .rideInProgress:
            if let eta = coordinator.flowController.estimatedArrival {
                let minutes = Int(eta / 60)
                return "ETA to destination: \(minutes) min"
            }
            return "En route to destination"
        case .approachingDestination:
            return "You'll arrive in less than a minute"
        case .rideCompleted:
            return "Thank you for riding with us!"
        default:
            return nil
        }
    }

    // MARK: - Format Helpers

    private func formatTravelTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return "\(minutes) min"
    }

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.34
        return String(format: "%.1f mi", miles)
    }
}

// MARK: - View Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ProductionExampleView()
}
