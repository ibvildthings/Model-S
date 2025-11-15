//
//  RideLocationCard.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI

struct RideLocationCard: View {
    @Binding var pickupText: String
    @Binding var destinationText: String
    @FocusState.Binding var focusedField: LocationField?

    var configuration: RideRequestConfiguration = .default
    var onPickupTap: () -> Void
    var onDestinationTap: () -> Void

    enum LocationField {
        case pickup
        case destination
    }

    var body: some View {
        VStack(spacing: 0) {
            // Card Header
            HStack {
                Text(configuration.cardTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Pickup Location Input
            HStack(spacing: 12) {
                Circle()
                    .fill(configuration.pickupPinColor)
                    .frame(width: 10, height: 10)

                TextField("Pickup Location", text: $pickupText)
                    .focused($focusedField, equals: .pickup)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .accessibilityLabel("Pickup location")
                    .accessibilityHint("Enter your pickup address")
                    .onTapGesture {
                        onPickupTap()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 18)

            // Divider with connecting line
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 3, height: 3)
                    }
                }
                .padding(.leading, 3)

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)

            // Destination Location Input
            HStack(spacing: 12) {
                Circle()
                    .fill(configuration.destinationPinColor)
                    .frame(width: 10, height: 10)

                TextField(configuration.destinationPlaceholder, text: $destinationText)
                    .focused($focusedField, equals: .destination)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .accessibilityLabel("Destination")
                    .accessibilityHint("Enter your destination address")
                    .onTapGesture {
                        onDestinationTap()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
        .padding(.horizontal, 16)
        .offset(y: focusedField != nil ? -12 : 0)
        .animation(.easeInOut(duration: 0.3), value: focusedField)
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var pickupText = "Current Location"
    @Previewable @State var destinationText = ""
    @Previewable @FocusState var focusedField: RideLocationCard.LocationField?

    ZStack {
        Color.gray.ignoresSafeArea()

        VStack {
            RideLocationCard(
                pickupText: $pickupText,
                destinationText: $destinationText,
                focusedField: $focusedField,
                onPickupTap: {
                    print("Pickup tapped")
                },
                onDestinationTap: {
                    print("Destination tapped")
                }
            )
            .padding(.top, 60)

            Spacer()
        }
    }
}
