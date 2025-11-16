/**
 * Driver Login View
 * Login screen for drivers
 */

import SwiftUI

struct DriverLoginView: View {

    @ObservedObject var viewModel: DriverViewModel
    @State private var selectedDriverId: String = "driver_1"

    // Available test drivers
    private let testDrivers = [
        ("driver_1", "Michael Chen"),
        ("driver_2", "Sarah Johnson"),
        ("driver_3", "David Martinez"),
        ("driver_4", "Emily Rodriguez"),
        ("driver_5", "James Wilson")
    ]

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // App Title
            VStack(spacing: 10) {
                Image(systemName: "car.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Model S Driver")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Start driving and earning")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Driver Selection
            VStack(alignment: .leading, spacing: 10) {
                Text("Select Driver")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Picker("Driver", selection: $selectedDriverId) {
                    ForEach(testDrivers, id: \.0) { driver in
                        Text(driver.1).tag(driver.0)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            .padding(.horizontal, 40)

            // Login Button
            Button(action: {
                viewModel.login(driverId: selectedDriverId)
            }) {
                HStack {
                    Image(systemName: "person.fill")
                    Text("Go Online")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Info text
            Text("By going online, you agree to receive ride requests")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Preview

#Preview {
    DriverLoginView(viewModel: DriverViewModel())
}
