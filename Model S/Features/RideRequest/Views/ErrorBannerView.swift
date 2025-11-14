//
//  ErrorBannerView.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI

/// Displays error messages in a dismissible banner
struct ErrorBannerView: View {
    let error: RideRequestError
    let onDismiss: () -> Void
    let onAction: (() -> Void)?

    init(error: RideRequestError, onDismiss: @escaping () -> Void, onAction: (() -> Void)? = nil) {
        self.error = error
        self.onDismiss = onDismiss
        self.onAction = onAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 4) {
                    Text(error.errorDescription ?? "An error occurred")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if needsAction {
                Button(action: {
                    if let url = settingsURL {
                        UIApplication.shared.open(url)
                    }
                    onDismiss()
                }) {
                    Text("Open Settings")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    private var needsAction: Bool {
        switch error {
        case .locationPermissionDenied, .locationServicesDisabled:
            return true
        default:
            return false
        }
    }

    private var settingsURL: URL? {
        URL(string: UIApplication.openSettingsURLString)
    }
}

#Preview {
    VStack {
        ErrorBannerView(
            error: .locationPermissionDenied,
            onDismiss: {},
            onAction: {}
        )

        ErrorBannerView(
            error: .geocodingFailed,
            onDismiss: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
