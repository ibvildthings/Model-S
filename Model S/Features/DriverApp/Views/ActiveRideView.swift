/**
 * Active Ride View
 * Shows active ride information and navigation
 */

import SwiftUI
import MapKit

struct ActiveRideView: View {

    @ObservedObject var viewModel: DriverViewModel

    private var currentRide: ActiveRide? {
        viewModel.currentRide
    }

    private var isHeadingToPickup: Bool {
        if case .headingToPickup = viewModel.driverState {
            return true
        }
        if case .arrivedAtPickup = viewModel.driverState {
            return true
        }
        return false
    }

    private var isRideInProgress: Bool {
        if case .rideInProgress = viewModel.driverState {
            return true
        }
        if case .approachingDestination = viewModel.driverState {
            return true
        }
        return false
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Map View - Takes up 60% of screen for better visibility
                if let ride = currentRide {
                    DriverMapView(
                        currentRide: ride,
                        isHeadingToPickup: isHeadingToPickup
                    )
                    .frame(height: geometry.size.height * 0.6)
                } else {
                    MapPlaceholder()
                        .frame(height: geometry.size.height * 0.6)
                }

                // Ride Info Card - Compact bottom sheet
                rideInfoCard
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(20, corners: [.topLeft, .topRight])
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)

                Spacer(minLength: 0)
            }
            .background(Color(UIColor.systemGray6))
        }
    }

    private var rideInfoCard: some View {
        VStack(spacing: 16) {
            // Status Header - Compact
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                Text(viewModel.statusText)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
            }

            // Passenger Info + Location in one row
            HStack(spacing: 12) {
                // Passenger Avatar
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                    )

                // Passenger + Location Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(currentRide?.passenger.name ?? "Passenger")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", currentRide?.passenger.rating ?? 0))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: isHeadingToPickup ? "mappin.circle.fill" : "location.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(isHeadingToPickup ? .green : .red)

                        Text(isHeadingToPickup ? (currentRide?.pickup.name ?? "Unknown") : (currentRide?.destination.name ?? "Unknown"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Call Button - Compact
                if let phone = currentRide?.passenger.phoneNumber {
                    Button(action: {
                        // Call passenger
                    }) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                }
            }

            // Action Button
            actionButton
        }
        .padding(20)
    }

    private var statusColor: Color {
        switch viewModel.driverState {
        case .headingToPickup:
            return .blue
        case .arrivedAtPickup:
            return .green
        case .rideInProgress:
            return .orange
        case .approachingDestination:
            return .red
        default:
            return .gray
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        Button(action: {
            performAction()
        }) {
            Text(actionButtonText)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(actionButtonColor)
                .cornerRadius(12)
        }
    }

    private var actionButtonText: String {
        switch viewModel.driverState {
        case .headingToPickup:
            return "Arrived at Pickup"
        case .arrivedAtPickup:
            return "Start Ride"
        case .rideInProgress, .approachingDestination:
            return "Complete Ride"
        default:
            return "Continue"
        }
    }

    private var actionButtonColor: Color {
        switch viewModel.driverState {
        case .headingToPickup:
            return .blue
        case .arrivedAtPickup:
            return .green
        case .rideInProgress, .approachingDestination:
            return .red
        default:
            return .gray
        }
    }

    private func performAction() {
        switch viewModel.driverState {
        case .headingToPickup:
            viewModel.arriveAtPickup()
        case .arrivedAtPickup:
            viewModel.pickupPassenger()
        case .rideInProgress, .approachingDestination:
            viewModel.completeRide()
        default:
            break
        }
    }
}

// MARK: - Driver Map View

struct DriverMapView: View {
    let currentRide: ActiveRide
    let isHeadingToPickup: Bool

    @State private var region: MKCoordinateRegion
    @State private var annotations: [DriverMapMarker] = []

    init(currentRide: ActiveRide, isHeadingToPickup: Bool) {
        self.currentRide = currentRide
        self.isHeadingToPickup = isHeadingToPickup

        // Calculate region to show all points
        let targetLocation = isHeadingToPickup ? currentRide.pickup : currentRide.destination

        // Center on midpoint between driver and target
        let centerLat = (currentRide.currentDriverLocation.coordinate.latitude + targetLocation.coordinate.latitude) / 2
        let centerLng = (currentRide.currentDriverLocation.coordinate.longitude + targetLocation.coordinate.longitude) / 2

        // Calculate span to show both points
        let latDelta = abs(currentRide.currentDriverLocation.coordinate.latitude - targetLocation.coordinate.latitude) * 2.5
        let lngDelta = abs(currentRide.currentDriverLocation.coordinate.longitude - targetLocation.coordinate.longitude) * 2.5

        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, 0.01),
                longitudeDelta: max(lngDelta, 0.01)
            )
        ))

        // Initialize annotations
        var newAnnotations: [DriverMapMarker] = []

        // Driver location
        newAnnotations.append(DriverMapMarker(
            coordinate: currentRide.currentDriverLocation.coordinate,
            title: "You",
            type: .driver
        ))

        if isHeadingToPickup {
            // Show pickup location
            newAnnotations.append(DriverMapMarker(
                coordinate: currentRide.pickup.coordinate,
                title: "Pickup",
                subtitle: currentRide.pickup.name,
                type: .pickup
            ))
        } else {
            // Show destination
            newAnnotations.append(DriverMapMarker(
                coordinate: currentRide.destination.coordinate,
                title: "Destination",
                subtitle: currentRide.destination.name,
                type: .destination
            ))
        }

        _annotations = State(initialValue: newAnnotations)
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: annotations) { marker in
            MapAnnotation(coordinate: marker.coordinate) {
                DriverAnnotationView(marker: marker)
            }
        }
    }
}

// MARK: - Driver Map Marker

struct DriverMapMarker: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    var subtitle: String?
    let type: MarkerType

    enum MarkerType {
        case driver
        case pickup
        case destination
    }
}

// MARK: - Driver Annotation View

struct DriverAnnotationView: View {
    let marker: DriverMapMarker

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 40, height: 40)
                    .shadow(radius: 3)

                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }

            // Pointer
            Triangle()
                .fill(backgroundColor)
                .frame(width: 12, height: 8)
                .offset(y: -4)
        }
        .overlay(
            VStack(spacing: 2) {
                Text(marker.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .cornerRadius(4)
                    .shadow(radius: 2)

                Spacer()
                    .frame(height: 50)
            }
            .offset(y: -55)
        )
    }

    private var backgroundColor: Color {
        switch marker.type {
        case .driver:
            return .blue
        case .pickup:
            return .green
        case .destination:
            return .red
        }
    }

    private var iconName: String {
        switch marker.type {
        case .driver:
            return "car.fill"
        case .pickup:
            return "figure.stand"
        case .destination:
            return "mappin.circle.fill"
        }
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Map Placeholder

struct MapPlaceholder: View {
    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)

            VStack(spacing: 10) {
                Image(systemName: "map.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)

                Text("Map View")
                    .font(.headline)
                    .foregroundColor(.gray)

                Text("Navigation would appear here")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
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

// MARK: - Preview

#Preview {
    ActiveRideView(viewModel: DriverViewModel())
}
