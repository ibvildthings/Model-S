//
//  RouteInfoView.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI

/// Displays route information like ETA and distance
struct RouteInfoView: View {
    let travelTime: String?
    let distance: String?

    var body: some View {
        HStack(spacing: 16) {
            if let time = travelTime {
                Label(time, systemImage: "clock.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            if let dist = distance {
                Label(dist, systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    VStack {
        RouteInfoView(travelTime: "15 min", distance: "3.2 mi")
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
