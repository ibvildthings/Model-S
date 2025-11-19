//
//  MapProviderSwitcher.swift
//  Model S
//
//  Shared map provider switcher component for both rider and driver apps
//  Refactored to use unified MapProviderService architecture
//

import SwiftUI

/// Compact floating button to switch between Apple Maps and Google Maps
struct MapProviderSwitcher: View {
    @ObservedObject private var providerService = MapProviderService.shared

    var body: some View {
        Menu {
            // Menu options - show only available providers
            ForEach(providerService.availableProviders, id: \.self) { provider in
                Button(action: {
                    _ = withAnimation(.spring(response: 0.3)) {
                        providerService.switchTo(provider: provider)
                    }
                    triggerHaptic()
                }) {
                    Label(provider.displayName, systemImage: provider.icon)
                    if providerService.currentProvider == provider {
                        Image(systemName: "checkmark")
                    }
                }
            }

            // Show unavailable providers with info
            ForEach(MapProvider.allCases.filter { !providerService.isProviderAvailable($0) }, id: \.self) { provider in
                Button(action: {}) {
                    Label(provider.displayName, systemImage: provider.icon)
                    Image(systemName: "exclamationmark.triangle")
                }
                .disabled(true)
            }
        } label: {
            // Compact button showing current provider
            HStack(spacing: 6) {
                Image(systemName: providerService.currentProvider.icon)
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
        providerService.currentProvider == .apple ? "Apple" : "Google"
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
