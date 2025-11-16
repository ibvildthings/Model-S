/**
 * Driver App View
 * Main view for driver application
 * Shows different screens based on driver state
 */

import SwiftUI

struct DriverAppView: View {

    @StateObject private var viewModel = DriverViewModel()

    var body: some View {
        ZStack {
            // Main content based on state
            switch viewModel.driverState {
            case .offline:
                DriverLoginView(viewModel: viewModel)

            case .loggingIn:
                LoadingView(message: "Logging in...")

            case .online:
                DriverHomeView(viewModel: viewModel)

            case .rideOffered:
                RideOfferView(viewModel: viewModel)

            case .headingToPickup, .arrivedAtPickup:
                ActiveRideView(viewModel: viewModel)

            case .rideInProgress, .approachingDestination:
                ActiveRideView(viewModel: viewModel)

            case .rideCompleted:
                RideSummaryView(viewModel: viewModel)

            case .error:
                ErrorView(viewModel: viewModel)
            }

            // Loading overlay
            if viewModel.isLoading {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .animation(.easeInOut, value: viewModel.driverState)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    @ObservedObject var viewModel: DriverViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Error")
                .font(.title)
                .fontWeight(.bold)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            Button(action: {
                viewModel.dismissError()
            }) {
                Text("OK")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    DriverAppView()
}
