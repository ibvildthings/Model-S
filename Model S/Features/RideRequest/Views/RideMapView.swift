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
    var configuration: RideRequestConfiguration = .default

    var body: some View {
        Map(
            coordinateRegion: $viewModel.region,
            showsUserLocation: true,
            annotationItems: annotations
        ) { annotation in
            MapAnnotation(coordinate: annotation.coordinate) {
                PinView(
                    type: annotation.type,
                    isVisible: annotation.type == .pickup ? showPickupPin : showDestinationPin,
                    configuration: configuration
                )
                .onTapGesture {
                    // Allow tapping the pin to interact
                }
            }
        }
        .overlay(
            // Draw route polyline
            GeometryReader { geometry in
                if let polyline = viewModel.routePolyline {
                    RouteLineView(
                        polyline: polyline,
                        region: viewModel.region,
                        size: geometry.size,
                        configuration: configuration
                    )
                }
            }
        )
        .onTapGesture { location in
            // Handle map taps to place pins
            handleMapTap(at: location)
        }
        .onChange(of: viewModel.pickupLocation) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showPickupPin = viewModel.pickupLocation != nil
            }
            if viewModel.pickupLocation != nil {
                hapticFeedback()
            }
        }
        .onChange(of: viewModel.destinationLocation) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showDestinationPin = viewModel.destinationLocation != nil
            }
            if viewModel.destinationLocation != nil {
                hapticFeedback()
            }
        }
        .mapStyle(configuration.mapStyle)
        .accessibilityLabel("Ride request map")
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

    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
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
    var configuration: RideRequestConfiguration = .default

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
        .accessibilityLabel(type == .pickup ? "Pickup location pin" : "Destination location pin")
    }

    private var pinColor: Color {
        switch type {
        case .pickup:
            return configuration.pickupPinColor
        case .destination:
            return configuration.destinationPinColor
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

// MARK: - RouteLineView
struct RouteLineView: View {
    let polyline: MKPolyline
    let region: MKCoordinateRegion
    let size: CGSize
    var configuration: RideRequestConfiguration = .default

    var body: some View {
        Path { path in
            let points = polyline.points()
            let pointCount = polyline.pointCount

            guard pointCount > 0 else { return }

            // Convert MKMapPoints to screen coordinates
            for i in 0..<pointCount {
                let mapPoint = points[i]
                let coordinate = mapPoint.coordinate
                let screenPoint = coordinateToScreen(coordinate: coordinate)

                if i == 0 {
                    path.move(to: screenPoint)
                } else {
                    path.addLine(to: screenPoint)
                }
            }
        }
        .stroke(
            configuration.routeLineColor,
            style: StrokeStyle(
                lineWidth: configuration.routeLineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }

    private func coordinateToScreen(coordinate: CLLocationCoordinate2D) -> CGPoint {
        // Calculate the map's coordinate span
        let mapWidth = region.span.longitudeDelta
        let mapHeight = region.span.latitudeDelta

        // Calculate the position relative to the region center
        let x = (coordinate.longitude - region.center.longitude + mapWidth / 2) / mapWidth
        let y = (region.center.latitude - coordinate.latitude + mapHeight / 2) / mapHeight

        // Convert to screen coordinates
        let screenX = x * size.width
        let screenY = y * size.height

        // Return point even if off-screen - SwiftUI will handle clipping
        return CGPoint(x: screenX, y: screenY)
    }
}

// MARK: - Preview
#Preview {
    RideMapView(viewModel: MapViewModel())
}
