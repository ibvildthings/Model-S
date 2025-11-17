//
//  GoogleMapViewWrapper.swift
//  Model S
//
//  UIViewRepresentable wrapper for Google Maps (GMSMapView)
//  Provides the same interface as MapViewWrapper but uses Google Maps SDK
//
//  NOTE: To use this, you need to:
//  1. Add Google Maps SDK via CocoaPods or Swift Package Manager
//  2. Add "import GoogleMaps" at the top of Model_SApp.swift
//  3. Initialize with: GMSServices.provideAPIKey("YOUR_API_KEY") in app init
//

import SwiftUI
import MapKit
// import GoogleMaps  // Uncomment when Google Maps SDK is added

/// Google Maps implementation using GMSMapView
/// Falls back to showing a placeholder when Google Maps SDK is not available
struct GoogleMapViewWrapper: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var pickupLocation: CLLocationCoordinate2D?
    var destinationLocation: CLLocationCoordinate2D?
    var driverLocation: CLLocationCoordinate2D?
    var route: Any? // Will be [CLLocationCoordinate2D] from GoogleRouteCalculationService
    var driverRoute: Any?
    var routeDisplayMode: RouteDisplayMode
    var showsUserLocation: Bool
    var routeLineColor: Color
    var routeLineWidth: CGFloat

    func makeUIView(context: Context) -> UIView {
        // Check if Google Maps SDK is available
        #if canImport(GoogleMaps)
        return createGoogleMapView(context: context)
        #else
        return createPlaceholderView()
        #endif
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        #if canImport(GoogleMaps)
        updateGoogleMapView(uiView, context: context)
        #else
        updatePlaceholderView(uiView)
        #endif
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Google Maps Implementation

    #if canImport(GoogleMaps)
    private func createGoogleMapView(context: Context) -> UIView {
        // Create Google Maps view
        let camera = GMSCameraPosition.camera(
            withLatitude: region.center.latitude,
            longitude: region.center.longitude,
            zoom: zoomLevelFromSpan(region.span)
        )
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = showsUserLocation
        mapView.settings.rotateGestures = true
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true

        context.coordinator.mapView = mapView
        return mapView
    }

    private func updateGoogleMapView(_ uiView: UIView, context: Context) {
        guard let mapView = context.coordinator.mapView else { return }

        // Update camera if region changed significantly
        if !context.coordinator.isUserInteracting {
            let camera = GMSCameraPosition.camera(
                withLatitude: region.center.latitude,
                longitude: region.center.longitude,
                zoom: zoomLevelFromSpan(region.span)
            )
            mapView.animate(to: camera)
        }

        // Update markers (annotations)
        context.coordinator.updateMarkers(
            pickup: pickupLocation,
            destination: destinationLocation,
            driver: driverLocation
        )

        // Update route polylines
        context.coordinator.updateRoute(
            mainRoute: route as? [CLLocationCoordinate2D],
            driverRoute: driverRoute as? [CLLocationCoordinate2D],
            displayMode: routeDisplayMode,
            color: UIColor(routeLineColor),
            width: routeLineWidth
        )
    }

    private func zoomLevelFromSpan(_ span: MKCoordinateSpan) -> Float {
        // Convert MKCoordinateSpan to Google Maps zoom level (0-21)
        let latitudeDelta = span.latitudeDelta
        let zoom = log2(360.0 / latitudeDelta)
        return Float(max(0, min(21, zoom)))
    }
    #endif

    // MARK: - Placeholder Implementation

    private func createPlaceholderView() -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let imageView = UIImageView(image: UIImage(systemName: "map.fill"))
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        imageView.widthAnchor.constraint(equalToConstant: 80).isActive = true

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Google Maps Ready"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        // Message
        let messageLabel = UILabel()
        messageLabel.text = "Add Google Maps SDK to see the map here"
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        // Instructions
        let instructionsLabel = UILabel()
        instructionsLabel.text = "1. Add GoogleMaps via CocoaPods/SPM\n2. Add API key in Model_SApp.swift\n3. Rebuild the app"
        instructionsLabel.font = .systemFont(ofSize: 14)
        instructionsLabel.textColor = .tertiaryLabel
        instructionsLabel.textAlignment = .center
        instructionsLabel.numberOfLines = 0

        // Current provider info
        let infoLabel = UILabel()
        infoLabel.text = "Currently using: Google Maps Services\n(Search, Geocoding, Routes)"
        infoLabel.font = .systemFont(ofSize: 12, weight: .medium)
        infoLabel.textColor = .systemGreen
        infoLabel.textAlignment = .center
        infoLabel.numberOfLines = 0

        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)
        stackView.addArrangedSubview(instructionsLabel)
        stackView.addArrangedSubview(infoLabel)

        containerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -40)
        ])

        return containerView
    }

    private func updatePlaceholderView(_ uiView: UIView) {
        // Placeholder doesn't need updates
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var parent: GoogleMapViewWrapper
        var isUserInteracting = false

        #if canImport(GoogleMaps)
        var mapView: GMSMapView?
        private var pickupMarker: GMSMarker?
        private var destinationMarker: GMSMarker?
        private var driverMarker: GMSMarker?
        private var currentPolyline: GMSPolyline?
        private var currentDisplayMode: RouteDisplayMode?

        func updateMarkers(pickup: CLLocationCoordinate2D?, destination: CLLocationCoordinate2D?, driver: CLLocationCoordinate2D?) {
            guard let mapView = mapView else { return }

            // Update pickup marker
            if let pickup = pickup {
                if pickupMarker == nil {
                    pickupMarker = GMSMarker(position: pickup)
                    pickupMarker?.title = "Pickup"
                    pickupMarker?.icon = createMarkerIcon(color: .systemGreen, iconName: "location.fill")
                    pickupMarker?.map = mapView
                } else {
                    pickupMarker?.position = pickup
                }
            } else {
                pickupMarker?.map = nil
                pickupMarker = nil
            }

            // Update destination marker
            if let destination = destination {
                if destinationMarker == nil {
                    destinationMarker = GMSMarker(position: destination)
                    destinationMarker?.title = "Destination"
                    destinationMarker?.icon = createMarkerIcon(color: .systemBlue, iconName: "mappin")
                    destinationMarker?.map = mapView
                } else {
                    destinationMarker?.position = destination
                }
            } else {
                destinationMarker?.map = nil
                destinationMarker = nil
            }

            // Update driver marker with animation
            if let driver = driver {
                if driverMarker == nil {
                    driverMarker = GMSMarker(position: driver)
                    driverMarker?.title = "Driver"
                    driverMarker?.icon = createCarIcon()
                    driverMarker?.map = mapView
                } else {
                    // Animate driver movement
                    CATransaction.begin()
                    CATransaction.setAnimationDuration(0.3)
                    driverMarker?.position = driver
                    CATransaction.commit()
                }
            } else {
                driverMarker?.map = nil
                driverMarker = nil
            }
        }

        func updateRoute(mainRoute: [CLLocationCoordinate2D]?, driverRoute: [CLLocationCoordinate2D]?, displayMode: RouteDisplayMode, color: UIColor, width: CGFloat) {
            guard let mapView = mapView else { return }

            // Determine which route to display
            let routeToDisplay: [CLLocationCoordinate2D]?
            switch displayMode {
            case .approach:
                routeToDisplay = driverRoute ?? mainRoute
            case .activeRide:
                routeToDisplay = mainRoute
            }

            // Check if we need to update
            let needsUpdate = currentDisplayMode != displayMode

            if needsUpdate || currentPolyline == nil {
                // Remove old polyline
                currentPolyline?.map = nil
                currentPolyline = nil

                // Add new polyline
                if let coordinates = routeToDisplay, !coordinates.isEmpty {
                    let path = GMSMutablePath()
                    coordinates.forEach { path.add($0) }

                    let polyline = GMSPolyline(path: path)

                    // Use different colors based on display mode
                    switch displayMode {
                    case .approach:
                        polyline.strokeColor = MapConstants.approachRouteColor
                    case .activeRide:
                        polyline.strokeColor = MapConstants.activeRideRouteColor
                    }

                    polyline.strokeWidth = MapConstants.routeLineWidth
                    polyline.map = mapView

                    currentPolyline = polyline
                    currentDisplayMode = displayMode
                }
            }
        }

        private func createMarkerIcon(color: UIColor, iconName: String) -> UIImage? {
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

        private func createCarIcon() -> UIImage? {
            let size = CGSize(width: 44, height: 44)
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { context in
                let ctx = context.cgContext

                // Draw circular background
                let circleRect = CGRect(x: 0, y: 0, width: 44, height: 44)
                ctx.setFillColor(UIColor.systemBlue.cgColor)
                ctx.fillEllipse(in: circleRect)

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
        #endif

        init(_ parent: GoogleMapViewWrapper) {
            self.parent = parent
        }
    }
}

#if canImport(GoogleMaps)
// MARK: - GMSMapViewDelegate
extension GoogleMapViewWrapper.Coordinator: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
        isUserInteracting = true
    }

    func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
        // Update parent's region when camera stops moving
        let span = MKCoordinateSpan(
            latitudeDelta: 360.0 / pow(2.0, Double(position.zoom)),
            longitudeDelta: 360.0 / pow(2.0, Double(position.zoom))
        )
        let region = MKCoordinateRegion(center: position.target, span: span)

        DispatchQueue.main.async {
            self.parent.region = region
            self.isUserInteracting = false
        }
    }
}
#endif
