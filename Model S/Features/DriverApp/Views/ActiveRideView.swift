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
        VStack(spacing: 0) {
            // Map (placeholder for now)
            MapPlaceholder()
                .frame(height: 400)

            // Ride Info Card
            VStack(spacing: 20) {
                // Status Header
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)

                    Text(viewModel.statusText)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Spacer()
                }

                Divider()

                // Passenger Info (if available)
                HStack(spacing: 15) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(currentRide?.passenger.name ?? "Passenger")
                            .font(.headline)

                        HStack {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)

                            Text(String(format: "%.1f", currentRide?.passenger.rating ?? 0))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if let phone = currentRide?.passenger.phoneNumber {
                        Button(action: {
                            // Call passenger
                        }) {
                            Image(systemName: "phone.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                                .frame(width: 44, height: 44)
                                .background(Color(UIColor.systemGray6))
                                .clipShape(Circle())
                        }
                    }
                }

                Divider()

                // Location Info
                if isHeadingToPickup {
                    DriverLocationRow(
                        icon: "mappin.circle.fill",
                        iconColor: .green,
                        title: "Pickup Location",
                        address: currentRide?.pickup.name ?? "Unknown"
                    )
                } else {
                    DriverLocationRow(
                        icon: "mappin.circle.fill",
                        iconColor: .red,
                        title: "Destination",
                        address: currentRide?.destination.name ?? "Unknown"
                    )
                }

                // Action Button
                actionButton
            }
            .padding()
            .background(Color(UIColor.systemBackground))

            Spacer()
        }
        .background(Color(UIColor.systemGray6))
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

// MARK: - Driver Location Row

struct DriverLocationRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let address: String

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(address)
                    .font(.body)
            }

            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Preview

#Preview {
    ActiveRideView(viewModel: DriverViewModel())
}
