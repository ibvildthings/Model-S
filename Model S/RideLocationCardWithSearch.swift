//
//  RideLocationCardWithSearch.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI
import MapKit

/// Enhanced location card with address autocomplete suggestions
struct RideLocationCardWithSearch: View {
    @Binding var pickupText: String
    @Binding var destinationText: String
    @FocusState.Binding var focusedField: RideLocationCard.LocationField?
    @StateObject private var searchCompleter = LocationSearchCompleter()

    var configuration: RideRequestConfiguration = .default
    var onPickupTap: () -> Void
    var onDestinationTap: () -> Void
    var onLocationSelected: (CLLocationCoordinate2D, String, Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main Card
            VStack(spacing: 0) {
                // Card Header
                HStack {
                    Text(configuration.cardTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Pickup Location Input
                HStack(spacing: 12) {
                    Circle()
                        .fill(configuration.pickupPinColor)
                        .frame(width: 12, height: 12)

                    TextField("Pickup Location", text: $pickupText)
                        .focused($focusedField, equals: .pickup)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .accessibilityLabel("Pickup location")
                        .accessibilityHint("Enter your pickup address")
                        .onChange(of: pickupText) { newValue in
                            if focusedField == .pickup {
                                searchCompleter.search(query: newValue)
                            }
                        }
                        .onTapGesture {
                            onPickupTap()
                            if !pickupText.isEmpty {
                                searchCompleter.search(query: pickupText)
                            }
                        }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)

                // Divider with connecting line
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: 3, height: 3)
                        }
                    }
                    .padding(.leading, 4)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                // Destination Location Input
                HStack(spacing: 12) {
                    Circle()
                        .fill(configuration.destinationPinColor)
                        .frame(width: 12, height: 12)

                    TextField(configuration.destinationPlaceholder, text: $destinationText)
                        .focused($focusedField, equals: .destination)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .accessibilityLabel("Destination")
                        .accessibilityHint("Enter your destination address")
                        .onChange(of: destinationText) { newValue in
                            if focusedField == .destination {
                                searchCompleter.search(query: newValue)
                            }
                        }
                        .onTapGesture {
                            onDestinationTap()
                            if !destinationText.isEmpty {
                                searchCompleter.search(query: destinationText)
                            }
                        }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(28)
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)

            // Search Suggestions (appears below card)
            if focusedField != nil && !searchCompleter.searchResults.isEmpty {
                LocationSearchSuggestionsView(
                    results: searchCompleter.searchResults,
                    onSelect: { completion in
                        handleSelection(completion)
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .onChange(of: focusedField) { newValue in
            if newValue == nil {
                searchCompleter.clearResults()
            }
        }
    }

    private func handleSelection(_ completion: MKLocalSearchCompletion) {
        Task {
            do {
                let (coordinate, name) = try await searchCompleter.getCoordinate(for: completion)

                await MainActor.run {
                    let isPickup = focusedField == .pickup

                    if isPickup {
                        pickupText = name
                    } else {
                        destinationText = name
                    }

                    onLocationSelected(coordinate, name, isPickup)
                    searchCompleter.clearResults()
                    focusedField = nil
                }
            } catch {
                print("Failed to get coordinate: \(error)")
            }
        }
    }
}

#Preview {
    @Previewable @State var pickupText = ""
    @Previewable @State var destinationText = ""
    @Previewable @FocusState var focusedField: RideLocationCard.LocationField?

    ZStack {
        Color.gray.ignoresSafeArea()

        VStack {
            RideLocationCardWithSearch(
                pickupText: $pickupText,
                destinationText: $destinationText,
                focusedField: $focusedField,
                onPickupTap: {
                    focusedField = .pickup
                },
                onDestinationTap: {
                    focusedField = .destination
                },
                onLocationSelected: { coordinate, name, isPickup in
                    print("Selected: \(name) at \(coordinate)")
                }
            )
            .padding(.top, 60)

            Spacer()
        }
    }
}
