//
//  LocationSearchSuggestionsView.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI
import MapKit

/// Displays autocomplete suggestions for address search
struct LocationSearchSuggestionsView: View {
    let results: [MKLocalSearchCompletion]
    let onSelect: (MKLocalSearchCompletion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(results, id: \.self) { result in
                Button(action: {
                    onSelect(result)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                }
                .buttonStyle(.plain)

                if result != results.last {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    LocationSearchSuggestionsView(
        results: [],
        onSelect: { _ in }
    )
    .padding()
}
