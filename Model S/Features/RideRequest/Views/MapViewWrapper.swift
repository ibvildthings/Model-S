//
//  MapViewWrapper.swift
//  Model S
//
//  UIViewRepresentable wrapper for MKMapView with proper overlay support
//

import SwiftUI
import MapKit

struct MapViewWrapper: UIViewRepresentable {
    @Binding var region: MapRegion  // Provider-agnostic region type
    var pickupLocation: CLLocationCoordinate2D?
    var destinationLocation: CLLocationCoordinate2D?
    var driverLocation: CLLocationCoordinate2D?
    var route: [CLLocationCoordinate2D]?  // Provider-agnostic coordinate array
    var driverRoute: [CLLocationCoordinate2D]?  // Provider-agnostic coordinate array
    var routeDisplayMode: RouteDisplayMode
    var showsUserLocation: Bool
    var routeLineColor: Color
    var routeLineWidth: CGFloat

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.isRotateEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Convert MapRegion to MKCoordinateRegion for Apple Maps
        let mkRegion = MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: region.span.latitudeDelta,
                longitudeDelta: region.span.longitudeDelta
            )
        )

        // Update region if changed significantly
        let currentRegion = mapView.region
        let regionChanged = abs(currentRegion.center.latitude - mkRegion.center.latitude) > 0.001 ||
                           abs(currentRegion.center.longitude - mkRegion.center.longitude) > 0.001 ||
                           abs(currentRegion.span.latitudeDelta - mkRegion.span.latitudeDelta) > 0.001 ||
                           abs(currentRegion.span.longitudeDelta - mkRegion.span.longitudeDelta) > 0.001

        if regionChanged && !context.coordinator.isUserInteracting {
            mapView.setRegion(mkRegion, animated: true)
        }

        // Update annotations
        context.coordinator.updateAnnotations(
            mapView: mapView,
            pickup: pickupLocation,
            destination: destinationLocation,
            driver: driverLocation
        )

        // Update route overlay based on display mode
        context.coordinator.updateRoute(
            mapView: mapView,
            mainRoute: route,
            driverRoute: driverRoute,
            displayMode: routeDisplayMode
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            self,
            routeLineColor: UIColor(routeLineColor),
            routeLineWidth: routeLineWidth
        )
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewWrapper
        var isUserInteracting = false
        var currentRoute: MKPolyline?
        var currentDisplayMode: RouteDisplayMode?
        let routeLineColor: UIColor
        let routeLineWidth: CGFloat

        // Track last known positions to avoid unnecessary updates
        private var lastPickup: CLLocationCoordinate2D?
        private var lastDestination: CLLocationCoordinate2D?

        init(_ parent: MapViewWrapper, routeLineColor: UIColor, routeLineWidth: CGFloat) {
            self.parent = parent
            self.routeLineColor = routeLineColor
            self.routeLineWidth = routeLineWidth
        }

        func updateAnnotations(mapView: MKMapView, pickup: CLLocationCoordinate2D?, destination: CLLocationCoordinate2D?, driver: CLLocationCoordinate2D?) {
            // Update pickup annotation only if it changed
            if pickup != lastPickup {
                // Remove old pickup
                if let oldPickup = mapView.annotations.first(where: { $0.title == "Pickup" }) {
                    mapView.removeAnnotation(oldPickup)
                }

                // Add new pickup if it exists
                if let pickup = pickup {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = pickup
                    annotation.title = "Pickup"
                    mapView.addAnnotation(annotation)
                }

                lastPickup = pickup
            }

            // Update destination annotation only if it changed
            if destination != lastDestination {
                // Remove old destination
                if let oldDestination = mapView.annotations.first(where: { $0.title == "Destination" }) {
                    mapView.removeAnnotation(oldDestination)
                }

                // Add new destination if it exists
                if let destination = destination {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = destination
                    annotation.title = "Destination"
                    mapView.addAnnotation(annotation)
                }

                lastDestination = destination
            }

            // Update driver annotation with smooth animation
            if let driver = driver {
                // Find existing driver annotation
                if let existingDriver = mapView.annotations.first(where: { $0.title == "Driver" }) as? MKPointAnnotation {
                    // Animate position change
                    UIView.animate(withDuration: 0.3) {
                        existingDriver.coordinate = driver
                    }
                } else {
                    // Create new driver annotation
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = driver
                    annotation.title = "Driver"
                    mapView.addAnnotation(annotation)
                    print("🚗 Added driver annotation at \(driver.latitude), \(driver.longitude)")
                }
            } else {
                // Remove driver annotation if no driver location
                if let existingDriver = mapView.annotations.first(where: { $0.title == "Driver" }) {
                    mapView.removeAnnotation(existingDriver)
                    print("🚗 Removed driver annotation")
                }
            }
        }

        func updateRoute(mapView: MKMapView, mainRoute: [CLLocationCoordinate2D]?, driverRoute: [CLLocationCoordinate2D]?, displayMode: RouteDisplayMode) {
            // Determine which route to display based on mode
            let coordsToDisplay: [CLLocationCoordinate2D]?
            switch displayMode {
            case .approach:
                // Show driver route (driver → pickup) if available, otherwise show main route
                coordsToDisplay = driverRoute ?? mainRoute
            case .activeRide:
                // Show main route (pickup → destination)
                coordsToDisplay = mainRoute
            }

            // Convert coordinates to MKPolyline
            let routeToDisplay: MKPolyline? = coordsToDisplay.map { coords in
                MKPolyline(coordinates: coords, count: coords.count)
            }

            // Check if we need to update the route (compare by coordinates, not reference)
            let needsUpdate = !arePolylinesSame(currentRoute, routeToDisplay) || currentDisplayMode != displayMode

            if needsUpdate {
                // Remove old route overlay
                if let currentRoute = currentRoute {
                    mapView.removeOverlay(currentRoute)
                    self.currentRoute = nil
                }

                // Add new route overlay
                if let newRoute = routeToDisplay {
                    mapView.addOverlay(newRoute)
                    self.currentRoute = newRoute
                    currentDisplayMode = displayMode

                    let routeType = displayMode == .approach ? "approach (driver → pickup)" : "active ride (pickup → destination)"
                    print("🛣️ Displaying \(routeType) route")
                }
            }
        }

        // Helper to compare polylines by coordinate count (avoid unnecessary updates)
        private func arePolylinesSame(_ lhs: MKPolyline?, _ rhs: MKPolyline?) -> Bool {
            switch (lhs, rhs) {
            case (nil, nil):
                return true
            case (nil, _), (_, nil):
                return false
            case (let l?, let r?):
                return l.pointCount == r.pointCount
            }
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // Use different colors based on display mode
                if let displayMode = currentDisplayMode {
                    switch displayMode {
                    case .approach:
                        renderer.strokeColor = MapConstants.approachRouteColor
                    case .activeRide:
                        renderer.strokeColor = MapConstants.activeRideRouteColor
                    }
                } else {
                    // Fallback to configured color if no display mode set
                    renderer.strokeColor = routeLineColor
                }

                renderer.lineWidth = MapConstants.routeLineWidth
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Don't customize user location
            if annotation is MKUserLocation {
                return nil
            }

            let identifier = "CustomPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }

            // Custom pin based on title
            if annotation.title == "Pickup" {
                annotationView?.image = createPinImage(color: .systemGreen, iconName: "location.fill")
            } else if annotation.title == "Destination" {
                annotationView?.image = createPinImage(color: .systemBlue, iconName: "mappin")
            } else if annotation.title == "Driver" {
                print("🚗 Creating view for driver annotation")
                annotationView?.image = createCarImage()
                annotationView?.centerOffset = CGPoint(x: 0, y: 0) // Center the car icon
            }

            return annotationView
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            isUserInteracting = true
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Update parent's region when user pans/zooms (convert to MapRegion)
            DispatchQueue.main.async {
                let mkRegion = mapView.region
                self.parent.region = MapRegion(
                    center: mkRegion.center,
                    span: MapCoordinateSpan(
                        latitudeDelta: mkRegion.span.latitudeDelta,
                        longitudeDelta: mkRegion.span.longitudeDelta
                    )
                )
                self.isUserInteracting = false
            }
        }

        // MARK: - Helper Methods

        private func createPinImage(color: UIColor, iconName: String) -> UIImage? {
            let size = CGSize(width: 40, height: 48)
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { context in
                let ctx = context.cgContext

                // Draw circle
                let circleRect = CGRect(x: 0, y: 0, width: 40, height: 40)
                ctx.setFillColor(color.cgColor)
                ctx.fillEllipse(in: circleRect)

                // Draw triangle pointer
                ctx.beginPath()
                ctx.move(to: CGPoint(x: 20, y: 48))
                ctx.addLine(to: CGPoint(x: 14, y: 40))
                ctx.addLine(to: CGPoint(x: 26, y: 40))
                ctx.closePath()
                ctx.setFillColor(color.cgColor)
                ctx.fillPath()

                // Draw icon
                if let icon = UIImage(systemName: iconName) {
                    let iconSize: CGFloat = 18
                    let iconRect = CGRect(
                        x: (40 - iconSize) / 2,
                        y: (40 - iconSize) / 2,
                        width: iconSize,
                        height: iconSize
                    )
                    icon.withTintColor(.white, renderingMode: .alwaysTemplate).draw(in: iconRect)
                }
            }
        }

        private func createCarImage() -> UIImage? {
            let size = CGSize(width: 44, height: 44)
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { context in
                let ctx = context.cgContext

                // Draw circular background
                let circleRect = CGRect(x: 0, y: 0, width: 44, height: 44)
                ctx.setFillColor(UIColor.systemBlue.cgColor)
                ctx.fillEllipse(in: circleRect)

                // Add shadow effect
                ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.3).cgColor)

                // Draw car icon
                if let carIcon = UIImage(systemName: "car.fill") {
                    let iconSize: CGFloat = 24
                    let iconRect = CGRect(
                        x: (44 - iconSize) / 2,
                        y: (44 - iconSize) / 2,
                        width: iconSize,
                        height: iconSize
                    )
                    carIcon.withTintColor(.white, renderingMode: .alwaysTemplate).draw(in: iconRect)
                }
            }
        }
    }
}
