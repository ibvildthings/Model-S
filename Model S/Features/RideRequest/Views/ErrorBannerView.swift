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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 20))

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
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.6))
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
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
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
