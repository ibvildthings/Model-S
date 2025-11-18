//
//  MapProviderSwitcher.swift
//  Model S
//
//  Shared map provider switcher component for both rider and driver apps
//

import SwiftUI

/// Compact floating button to switch between Apple Maps and Google Maps
struct MapProviderSwitcher: View {
    @StateObject private var providerPreference = MapProviderPreference.shared

    var body: some View {
        Menu {
            // Menu options
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    providerPreference.selectedProvider = .apple
                }
                triggerHaptic()
            }) {
                Label("Apple Maps", systemImage: "map.fill")
                if providerPreference.selectedProvider == .apple {
                    Image(systemName: "checkmark")
                }
            }

            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    providerPreference.selectedProvider = .google
                }
                triggerHaptic()
            }) {
                Label("Google Maps", systemImage: "globe")
                if providerPreference.selectedProvider == .google {
                    Image(systemName: "checkmark")
                }
            }
        } label: {
            // Compact button showing current provider
            HStack(spacing: 6) {
                Image(systemName: currentProviderIcon)
                    .font(.system(size: 14, weight: .medium))
                Text(currentProviderName)
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        }
    }

    private var currentProviderName: String {
        providerPreference.selectedProvider == .apple ? "Apple" : "Google"
    }

    private var currentProviderIcon: String {
        providerPreference.selectedProvider == .apple ? "map.fill" : "globe"
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    MapProviderSwitcher()
        .padding()
}
