/**
 * Ride Offer View
 * Shows ride request details and accept/reject options
 */

import SwiftUI

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

                            Text(rideRequest?.pickup.address ?? "Pickup Location")
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

                            Text(rideRequest?.destination.address ?? "Destination")
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
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RideOfferView(viewModel: DriverViewModel())
}
