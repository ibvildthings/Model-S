/**
 * Ride Summary View
 * Shows ride completion summary and earnings
 */

import SwiftUI

struct RideSummaryView: View {

    @ObservedObject var viewModel: DriverViewModel

    private var rideSummary: RideSummary? {
        if case .rideCompleted(let summary, _) = viewModel.driverState {
            return summary
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
            }

            // Title
            VStack(spacing: 10) {
                Text("Ride Completed!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Great job! Here's your summary")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Earnings Card
            VStack(spacing: 15) {
                Text("You Earned")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(String(format: "$%.2f", rideSummary?.earnings ?? 0))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(Color.green.opacity(0.1))
            .cornerRadius(15)

            // Ride Details
            VStack(spacing: 15) {
                DetailRow(
                    icon: "map.fill",
                    title: "Distance",
                    value: distanceText
                )

                Divider()

                DetailRow(
                    icon: "clock.fill",
                    title: "Duration",
                    value: durationText
                )

                Divider()

                DetailRow(
                    icon: "mappin.circle.fill",
                    iconColor: .green,
                    title: "From",
                    value: rideSummary?.pickup.address ?? "Unknown"
                )

                Divider()

                DetailRow(
                    icon: "mappin.circle.fill",
                    iconColor: .red,
                    title: "To",
                    value: rideSummary?.destination.address ?? "Unknown"
                )
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(15)

            Spacer()

            // Continue Button
            Button(action: {
                viewModel.finishRideSummary()
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding(30)
        .background(Color(UIColor.systemBackground))
    }

    private var distanceText: String {
        guard let distance = rideSummary?.distance else {
            return "0 km"
        }

        let km = distance / 1000
        return String(format: "%.1f km", km)
    }

    private var durationText: String {
        guard let duration = rideSummary?.duration else {
            return "0 min"
        }

        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    var iconColor: Color = .blue
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    RideSummaryView(viewModel: DriverViewModel())
}
