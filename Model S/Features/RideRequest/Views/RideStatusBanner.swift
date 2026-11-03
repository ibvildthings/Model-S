//
//  RideStatusBanner.swift
//  Model S
//
//  Compact banner shown at the top of the rider screen once a ride has been
//  requested: status, ETA, driver summary and a cancel button while searching.
//

import SwiftUI

extension RideRequestState {
    /// Whether the rider screen should replace the booking sheet with the status banner
    var showsStatusBanner: Bool {
        switch self {
        case .rideRequested, .searchingForDriver, .driverFound, .driverEnRoute,
             .driverArriving, .rideInProgress, .approachingDestination, .rideCompleted:
            return true
        default:
            return false
        }
    }
}

struct RideStatusBanner: View {
    @ObservedObject var flowController: RideFlowController
    var onCancel: () -> Void

    private var state: RideRequestState { flowController.legacyState }

    var body: some View {
        HStack(spacing: 12) {
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let driver = flowController.driver, state != .searchingForDriver {
                driverSummary(driver)
            }

            if state == .searchingForDriver || state == .rideRequested {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Cancel ride request")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Pieces

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
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

    private func driverSummary(_ driver: DriverInfo) -> some View {
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

    // MARK: - Copy

    private var title: String {
        switch state {
        case .rideRequested, .searchingForDriver: return "Finding your driver..."
        case .driverFound: return "Driver Found!"
        case .driverEnRoute: return "Driver is on the way!"
        case .driverArriving: return "Driver is arriving!"
        case .rideInProgress: return "Ride in progress"
        case .approachingDestination: return "Approaching destination"
        case .rideCompleted: return "Ride completed!"
        default: return ""
        }
    }

    private var subtitle: String? {
        let etaMinutes = flowController.estimatedArrival.map { Int($0 / 60) }

        switch state {
        case .driverFound:
            return etaMinutes.map { "Arriving in \($0) min" }
        case .driverEnRoute:
            return etaMinutes.map { "ETA: \($0) min" } ?? "Your driver is heading to your location"
        case .driverArriving:
            return "Your driver will arrive in less than a minute"
        case .rideInProgress:
            return etaMinutes.map { "ETA to destination: \($0) min" } ?? "En route to destination"
        case .approachingDestination:
            return "You'll arrive in less than a minute"
        case .rideCompleted:
            return "Thank you for riding with us!"
        default:
            return nil
        }
    }
}
