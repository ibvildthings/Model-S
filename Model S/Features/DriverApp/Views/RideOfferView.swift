/**
 * Ride Offer View
 * Shows ride request details and accept/reject options
 */

import SwiftUI
import MapKit

struct RideOfferView: View {

    @ObservedObject var viewModel: DriverViewModel
    @State private var timeRemaining: TimeInterval = 30

    private var rideRequest: RideRequest? {
        if case .rideOffered(let request, _) = viewModel.driverState {
            return request
        }
        return nil
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)

            // Offer Card
            VStack(spacing: 0) {
                // Timer Header
                VStack(spacing: 5) {
                    Text("New Ride Request")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(timeRemainingText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)

                // Map Preview
                if let request = rideRequest {
                    RideOfferMapView(request: request)
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top)
                }

                // Ride Details
                VStack(spacing: 20) {
                    // Earnings
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)

                        VStack(alignment: .leading) {
                            Text("Estimated Earnings")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(String(format: "$%.2f", rideRequest?.estimatedEarnings ?? 0))
                                .font(.title2)
                                .fontWeight(.bold)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)

                    // Distance
                    HStack {
                        Image(systemName: "map.fill")
                            .font(.title)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading) {
                            Text("Distance")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(distanceText)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)

                    // Pickup Location
                    HStack(alignment: .top, spacing: 15) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Pickup")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(rideRequest?.pickup.name ?? "Pickup Location")
                                .font(.body)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)

                    // Destination Location
                    HStack(alignment: .top, spacing: 15) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Destination")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(rideRequest?.destination.name ?? "Destination")
                                .font(.body)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                }
                .padding()

                // Action Buttons
                HStack(spacing: 15) {
                    // Reject Button
                    Button(action: {
                        viewModel.rejectRide()
                    }) {
                        Text("Decline")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(12)
                    }

                    // Accept Button
                    Button(action: {
                        viewModel.acceptRide()
                    }) {
                        Text("Accept")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(30)
        }
        .onAppear {
            startTimer()
        }
    }

    private var timeRemainingText: String {
        let seconds = Int(timeRemaining)
        return "\(seconds)s"
    }

    private var distanceText: String {
        guard let distance = rideRequest?.distance else {
            return "0 km"
        }

        let km = distance / 1000
        return String(format: "%.1f km", km)
    }

    private func startTimer() {
        guard let request = rideRequest else { return }

        timeRemaining = request.timeRemaining

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            timeRemaining -= 1

            if timeRemaining <= 0 {
                timer.invalidate()
                // Auto-reject the offer when timer expires
                Task { @MainActor in
                    viewModel.handleOfferExpiry()
                }
            }
        }
    }
}

// MARK: - Ride Offer Map View

struct RideOfferMapView: View {
    let request: RideRequest

    @State private var region: MapRegion
    @State private var annotations: [RideOfferAnnotation] = []

    init(request: RideRequest) {
        self.request = request

        // Calculate region to show both pickup and destination
        let centerLat = (request.pickup.coordinate.latitude + request.destination.coordinate.latitude) / 2
        let centerLng = (request.pickup.coordinate.longitude + request.destination.coordinate.longitude) / 2

        let latDelta = abs(request.pickup.coordinate.latitude - request.destination.coordinate.latitude) * 2.5
        let lngDelta = abs(request.pickup.coordinate.longitude - request.destination.coordinate.longitude) * 2.5

        _region = State(initialValue: MapRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            latitudeDelta: max(latDelta, 0.02),
            longitudeDelta: max(lngDelta, 0.02)
        ))

        // Create annotations
        var newAnnotations: [RideOfferAnnotation] = []
        newAnnotations.append(RideOfferAnnotation(
            coordinate: request.pickup.coordinate,
            type: .pickup
        ))
        newAnnotations.append(RideOfferAnnotation(
            coordinate: request.destination.coordinate,
            type: .destination
        ))
        _annotations = State(initialValue: newAnnotations)
    }

    var body: some View {
        Map(position: .constant(.region(region.toMKCoordinateRegion))) {
            ForEach(annotations) { annotation in
                Annotation("", coordinate: annotation.coordinate) {
                    ZStack {
                        Circle()
                            .fill(annotation.type == .pickup ? Color.green : Color.red)
                            .frame(width: 30, height: 30)
                            .shadow(radius: 2)

                        Image(systemName: annotation.type == .pickup ? "figure.stand" : "mappin.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .disabled(true) // Disable interaction
    }
}

// MARK: - Ride Offer Annotation

struct RideOfferAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType

    enum AnnotationType {
        case pickup
        case destination
    }
}

// MARK: - Preview

#Preview {
    RideOfferView(viewModel: DriverViewModel())
}
