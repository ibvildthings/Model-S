/**
 * Driver Home View
 * Main view when driver is online and available
 */

import SwiftUI

struct DriverHomeView: View {

    @ObservedObject var viewModel: DriverViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            VStack(spacing: 20) {
                // Status
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)

                    Text("You're Online")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(action: {
                        viewModel.toggleAvailability()
                    }) {
                        Image(systemName: "power")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))

                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        title: "Earnings Today",
                        value: viewModel.earningsText,
                        icon: "dollarsign.circle.fill",
                        color: .green
                    )

                    StatCard(
                        title: "Rides",
                        value: viewModel.completedRidesText,
                        icon: "car.fill",
                        color: .blue
                    )

                    StatCard(
                        title: "Online Time",
                        value: viewModel.onlineTimeText,
                        icon: "clock.fill",
                        color: .orange
                    )

                    StatCard(
                        title: "Rating",
                        value: viewModel.ratingText,
                        icon: "star.fill",
                        color: .yellow
                    )
                }
                .padding(.horizontal)
            }

            Spacer()

            // Waiting for rides message
            VStack(spacing: 20) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Waiting for ride requests...")
                    .font(.title3)
                    .fontWeight(.medium)

                Text("You'll be notified when a nearby passenger requests a ride")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)

                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    DriverHomeView(viewModel: {
        let vm = DriverViewModel()
        // Simulate online state for preview
        return vm
    }())
}
