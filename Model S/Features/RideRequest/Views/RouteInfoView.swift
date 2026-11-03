//
//  RouteInfoView.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI

/// Compact ETA / distance banner shown above the location card once a route is ready
struct RouteInfoView: View {
    let route: RouteInfo

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                Text("\(Int(route.estimatedTravelTime / 60)) min")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Divider()
                .frame(height: 16)

            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                Text(String(format: "%.1f mi", route.distance / 1609.34))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    RouteInfoView(route: RouteInfo(distance: 5150, estimatedTravelTime: 900, polyline: ""))
        .padding()
        .background(Color.gray.opacity(0.2))
}
