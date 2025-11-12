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
                Text("Plan your ride")
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
                    .fill(.green)
                    .frame(width: 12, height: 12)

                TextField("Pickup Location", text: $pickupText)
                    .focused($focusedField, equals: .pickup)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onTapGesture {
                        onPickupTap()
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
                    .fill(.blue)
                    .frame(width: 12, height: 12)

                TextField("Where to?", text: $destinationText)
                    .focused($focusedField, equals: .destination)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onTapGesture {
                        onDestinationTap()
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
        .padding(.horizontal, 16)
        .offset(y: focusedField != nil ? -20 : 0)
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
