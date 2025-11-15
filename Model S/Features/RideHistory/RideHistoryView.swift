//
//  RideHistoryView.swift
//  Model S
//
//  Created by Claude Code
//

import SwiftUI
import CoreLocation

/// View displaying the list of ride history
struct RideHistoryView: View {
    @StateObject private var store = RideHistoryStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearAlert = false
    @State private var selectedRide: RideHistory?

    var body: some View {
        NavigationStack {
            ZStack {
                if store.rides.isEmpty {
                    emptyStateView
                } else {
                    rideListView
                }
            }
            .navigationTitle("Ride History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if !store.rides.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive, action: {
                                showingClearAlert = true
                            }) {
                                Label("Clear All History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("Clear All History?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    withAnimation {
                        store.clearAllRides()
                    }
                }
            } message: {
                Text("This will permanently delete all \(store.totalRidesCount) rides from your history.")
            }
            .sheet(item: $selectedRide) { ride in
                RideDetailView(ride: ride)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.circle")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("No Rides Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Your ride history will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var rideListView: some View {
        VStack(spacing: 0) {
            // Stats Header
            statsHeader

            // Ride List
            List {
                ForEach(store.rides) { ride in
                    RideHistoryItemView(ride: ride)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRide = ride
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    store.removeRide(ride)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
        }
    }

    private var statsHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                StatItem(
                    title: "Total Rides",
                    value: "\(store.totalRidesCount)",
                    icon: "car.fill"
                )

                Divider()
                    .frame(height: 44)

                StatItem(
                    title: "Total Distance",
                    value: formatTotalDistance(store.totalDistance),
                    icon: "map.fill"
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func formatTotalDistance(_ distance: Double) -> String {
        let miles = distance * 0.000621371
        if miles < 100 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }
}

/// Individual stat item in the header
struct StatItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Individual ride item in the list
struct RideHistoryItemView: View {
    let ride: RideHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date
            Text(ride.formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)

            // Locations
            VStack(alignment: .leading, spacing: 8) {
                LocationRow(
                    icon: "location.circle.fill",
                    iconColor: .green,
                    text: ride.pickupAddress
                )

                LocationRow(
                    icon: "mappin.circle.fill",
                    iconColor: .blue,
                    text: ride.destinationAddress
                )
            }

            // Stats
            HStack(spacing: 16) {
                Label(ride.formattedDistance, systemImage: "arrow.left.and.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label(ride.formattedTravelTime, systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Location row component
struct LocationRow: View {
    let icon: String
    let iconColor: Color
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.body)

            Text(text)
                .font(.subheadline)
                .lineLimit(1)
        }
    }
}

/// Detail view for a single ride
struct RideDetailView: View {
    let ride: RideHistory
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Date Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ride Date")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(ride.formattedDate)
                            .font(.title3)
                    }

                    Divider()

                    // Locations Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Trip Details")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 12) {
                            DetailLocationRow(
                                title: "Pickup",
                                icon: "location.circle.fill",
                                iconColor: .green,
                                address: ride.pickupAddress,
                                coordinate: ride.pickupLocation.coordinate
                            )

                            DetailLocationRow(
                                title: "Destination",
                                icon: "mappin.circle.fill",
                                iconColor: .blue,
                                address: ride.destinationAddress,
                                coordinate: ride.destinationLocation.coordinate
                            )
                        }
                    }

                    Divider()

                    // Stats Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Trip Stats")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 20) {
                            StatBox(
                                icon: "arrow.left.and.right",
                                title: "Distance",
                                value: ride.formattedDistance
                            )

                            StatBox(
                                icon: "clock",
                                title: "Est. Time",
                                value: ride.formattedTravelTime
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Ride Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Detail location row component
struct DetailLocationRow: View {
    let title: String
    let icon: String
    let iconColor: Color
    let address: String
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(address)
                        .font(.body)

                    Text(String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospaced()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

/// Stat box component
struct StatBox: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    RideHistoryView()
}
