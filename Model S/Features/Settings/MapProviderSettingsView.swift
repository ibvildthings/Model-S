//
//  MapProviderSettingsView.swift
//  Model S
//
//  Settings view for switching between Apple Maps and Google Maps
//
//  Created by Pritesh Desai on 11/17/25.
//

import SwiftUI

struct MapProviderSettingsView: View {
    @ObservedObject private var providerService = MapProviderService.shared

    var body: some View {
        List {
            Section {
                ForEach(MapProvider.allCases, id: \.self) { provider in
                    ProviderRow(
                        provider: provider,
                        isSelected: providerService.currentProvider == provider,
                        isAvailable: providerService.isProviderAvailable(provider)
                    ) {
                        _ = providerService.switchTo(provider: provider)
                    }
                }
            } header: {
                Text("Map Provider")
            } footer: {
                if !providerService.isGoogleMapsAvailable {
                    Text("To use Google Maps, add GoogleMapsAPIKey to Secrets.plist (see GOOGLE_MAPS_SETUP.md)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Section {
                HStack {
                    Text("Current Provider")
                    Spacer()
                    Label(providerService.currentProvider.displayName, systemImage: providerService.currentProvider.icon)
                        .foregroundColor(.blue)
                }

                if providerService.currentProvider == .google && !providerService.isGoogleMapsAvailable {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Google Maps SDK not configured")
                        Spacer()
                    }
                }
            } header: {
                Text("Status")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(
                        title: "Apple Maps",
                        features: ["Built-in iOS maps", "No API key required", "Always available"]
                    )

                    Divider()

                    InfoRow(
                        title: "Google Maps",
                        features: [
                            "Google Places search",
                            "Google Geocoding",
                            "Google Directions",
                            "Requires API key"
                        ]
                    )
                }
            } header: {
                Text("Features")
            }
        }
        .navigationTitle("Map Settings")
    }
}

// MARK: - Provider Row

struct ProviderRow: View {
    let provider: MapProvider
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: provider.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.headline)
                        .foregroundColor(isAvailable ? .primary : .secondary)

                    if !isAvailable {
                        Text("Not configured")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(!isAvailable)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let title: String
    let features: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(features, id: \.self) { feature in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(feature)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MapProviderSettingsView()
    }
}
