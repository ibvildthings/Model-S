//
//  MapViewWrapper.swift
//  Model S
//
//  UIViewRepresentable wrapper for MKMapView with proper overlay support
//

import SwiftUI
import MapKit

struct MapViewWrapper: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var pickupLocation: CLLocationCoordinate2D?
    var destinationLocation: CLLocationCoordinate2D?
    var driverLocation: CLLocationCoordinate2D?
    var route: MKPolyline?
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
        // Update region if changed significantly
        let currentRegion = mapView.region
        let regionChanged = abs(currentRegion.center.latitude - region.center.latitude) > 0.001 ||
                           abs(currentRegion.center.longitude - region.center.longitude) > 0.001 ||
                           abs(currentRegion.span.latitudeDelta - region.span.latitudeDelta) > 0.001 ||
                           abs(currentRegion.span.longitudeDelta - region.span.longitudeDelta) > 0.001

        if regionChanged && !context.coordinator.isUserInteracting {
            mapView.setRegion(region, animated: true)
        }

        // Update annotations
        context.coordinator.updateAnnotations(
            mapView: mapView,
            pickup: pickupLocation,
            destination: destinationLocation,
            driver: driverLocation
        )

        // Update route overlay
        context.coordinator.updateRoute(mapView: mapView, route: route)
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
        let routeLineColor: UIColor
        let routeLineWidth: CGFloat

        init(_ parent: MapViewWrapper, routeLineColor: UIColor, routeLineWidth: CGFloat) {
            self.parent = parent
            self.routeLineColor = routeLineColor
            self.routeLineWidth = routeLineWidth
        }

        func updateAnnotations(mapView: MKMapView, pickup: CLLocationCoordinate2D?, destination: CLLocationCoordinate2D?, driver: CLLocationCoordinate2D?) {
            // Remove old annotations (except user location and driver - we'll update driver)
            let oldAnnotations = mapView.annotations.filter { annotation in
                guard !(annotation is MKUserLocation) else { return false }
                // Keep driver annotation if it exists, we'll update its position
                return annotation.title != "Driver"
            }
            mapView.removeAnnotations(oldAnnotations)

            // Add or update driver annotation with smooth animation
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

            // Add pickup annotation
            if let pickup = pickup {
                let annotation = MKPointAnnotation()
                annotation.coordinate = pickup
                annotation.title = "Pickup"
                mapView.addAnnotation(annotation)
            }

            // Add destination annotation
            if let destination = destination {
                let annotation = MKPointAnnotation()
                annotation.coordinate = destination
                annotation.title = "Destination"
                mapView.addAnnotation(annotation)
            }
        }

        func updateRoute(mapView: MKMapView, route: MKPolyline?) {
            // Remove old route overlay
            if let currentRoute = currentRoute {
                mapView.removeOverlay(currentRoute)
                self.currentRoute = nil
            }

            // Add new route overlay
            if let route = route {
                mapView.addOverlay(route)
                self.currentRoute = route
            }
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = routeLineColor
                renderer.lineWidth = routeLineWidth
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
            // Update parent's region when user pans/zooms
            DispatchQueue.main.async {
                self.parent.region = mapView.region
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
