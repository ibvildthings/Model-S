//
//  RideMapView.swift
//  Model S
//
//  Created by Pritesh Desai on 11/12/25.
//

import SwiftUI
import MapKit

struct RideMapView: View {
    @ObservedObject var viewModel: MapViewModel
    @State private var showPickupPin = false
    @State private var showDestinationPin = false

    var body: some View {
        Map(
            coordinateRegion: $viewModel.region,
            showsUserLocation: true,
            annotationItems: annotations
        ) { annotation in
            MapAnnotation(coordinate: annotation.coordinate) {
                PinView(
                    type: annotation.type,
                    isVisible: annotation.type == .pickup ? showPickupPin : showDestinationPin
                )
                .onTapGesture {
                    // Allow tapping the pin to interact
                }
            }
        }
        .overlay(
            // Polyline overlay for route
            RouteOverlay(polyline: viewModel.routePolyline)
        )
        .onTapGesture { location in
            // Handle map taps to place pins
            handleMapTap(at: location)
        }
        .onChange(of: viewModel.pickupLocation) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                showPickupPin = viewModel.pickupLocation != nil
            }
        }
        .onChange(of: viewModel.destinationLocation) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                showDestinationPin = viewModel.destinationLocation != nil
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted))
        .preferredColorScheme(.dark)
    }

    private var annotations: [MapPinAnnotation] {
        var items: [MapPinAnnotation] = []

        if let pickup = viewModel.pickupLocation {
            items.append(MapPinAnnotation(
                id: pickup.id,
                coordinate: pickup.coordinate,
                type: .pickup
            ))
        }

        if let destination = viewModel.destinationLocation {
            items.append(MapPinAnnotation(
                id: destination.id,
                coordinate: destination.coordinate,
                type: .destination
            ))
        }

        return items
    }

    private func handleMapTap(at point: CGPoint) {
        // Note: In a real implementation, you'd convert the tap point to coordinates
        // For now, this is a placeholder for the interaction logic
    }
}

// MARK: - MapPinAnnotation
struct MapPinAnnotation: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let type: PinType

    enum PinType {
        case pickup
        case destination
    }
}

// MARK: - PinView
struct PinView: View {
    let type: MapPinAnnotation.PinType
    let isVisible: Bool

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(pinColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                )
                .shadow(color: pinColor.opacity(0.5), radius: 8, x: 0, y: 4)

            // Pin pointer
            Triangle()
                .fill(pinColor)
                .frame(width: 12, height: 8)
        }
        .scaleEffect(isVisible ? 1.0 : 0.5)
        .opacity(isVisible ? 1.0 : 0.0)
    }

    private var pinColor: Color {
        switch type {
        case .pickup:
            return .green
        case .destination:
            return .blue
        }
    }

    private var iconName: String {
        switch type {
        case .pickup:
            return "location.fill"
        case .destination:
            return "mappin"
        }
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

// MARK: - RouteOverlay
struct RouteOverlay: View {
    let polyline: MKPolyline?

    var body: some View {
        // Placeholder for route visualization
        // In a real implementation, you'd render the polyline using MapKit overlays
        // or convert polyline coordinates to SwiftUI Path
        EmptyView()
    }
}

// MARK: - Preview
#Preview {
    RideMapView(viewModel: MapViewModel())
}
