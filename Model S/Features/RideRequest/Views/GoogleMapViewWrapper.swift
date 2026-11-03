//
//  GoogleMapViewWrapper.swift
//  Model S
//
//  UIViewRepresentable wrapper for Google Maps (GMSMapView)
//  Provides the same interface as MapViewWrapper but uses Google Maps SDK
//
//  NOTE: Requires Google Maps SDK to be installed via SPM or CocoaPods
//  See GOOGLE_MAPS_SETUP.md for installation instructions
//

import SwiftUI
import MapKit

#if canImport(GoogleMaps)
import GoogleMaps

// MARK: - MKPolyline Extension

extension MKPolyline {
    func coordinates() -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - GMSPath Extension

extension GMSPath {
    func toCoordinates() -> [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        for index in 0..<count() {
            coords.append(coordinate(at: index))
        }
        return coords
    }
}

/// Google Maps implementation using GMSMapView
struct GoogleMapViewWrapper: UIViewRepresentable {
    @Binding var region: MapRegion  // Provider-agnostic region type (no more conversion bugs!)
    var pickupLocation: CLLocationCoordinate2D?
    var destinationLocation: CLLocationCoordinate2D?
    var driverLocation: CLLocationCoordinate2D?
    var route: [CLLocationCoordinate2D]?  // Provider-agnostic coordinate array
    var driverRoute: [CLLocationCoordinate2D]?  // Provider-agnostic coordinate array
    var routeDisplayMode: RouteDisplayMode
    var showsUserLocation: Bool
    var routeLineColor: Color
    var routeLineWidth: CGFloat

    func makeUIView(context: Context) -> GMSMapView {
        // Create camera position using MapRegion's built-in zoom level (no conversion needed!)
        let camera = GMSCameraPosition.camera(
            withLatitude: region.center.latitude,
            longitude: region.center.longitude,
            zoom: region.span.zoomLevel
        )

        // Create Google Maps view using options initializer
        let options = GMSMapViewOptions()
        options.camera = camera
        options.frame = .zero
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator

        // Explicitly set map type to ensure tiles load
        mapView.mapType = .normal

        // Enable location if requested
        mapView.isMyLocationEnabled = showsUserLocation

        // Enable gestures
        mapView.settings.rotateGestures = true
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.myLocationButton = true

        // Debug logging
        AppLog.debug("🗺️ Google Maps view created")
        AppLog.debug("   📍 Location: \(region.center.latitude), \(region.center.longitude)")
        AppLog.debug("   🔍 Zoom: \(region.span.zoomLevel)")
        AppLog.debug("   🗺️ Map type: normal")
        AppLog.debug("")
        AppLog.debug("⏳ Waiting for map tiles to load...")
        AppLog.debug("   If tiles don't load, check Google Cloud Console:")
        AppLog.debug("   1. Billing enabled? (MOST COMMON ISSUE)")
        AppLog.debug("   2. 'Maps SDK for iOS' enabled? (not just 'Maps SDK')")
        AppLog.debug("   3. API key restrictions correct?")

        context.coordinator.mapView = mapView

        // Set a timer to check if tiles loaded after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak coordinator = context.coordinator] in
            guard let coordinator = coordinator else { return }

            if !coordinator.tilesLoaded {
                AppLog.debug("")
                AppLog.warning("⚠️ WARNING: Map tiles have NOT loaded after 3 seconds")
                AppLog.debug("   You should only see a blue dot (your location)")
                AppLog.debug("   No map tiles = Google Cloud Console issue")
                AppLog.debug("")
                AppLog.debug("🔧 SOLUTION - Go to Google Cloud Console:")
                AppLog.debug("")
                AppLog.debug("   Step 1: Enable Billing (99% of the time this is the issue)")
                AppLog.debug("   https://console.cloud.google.com/billing")
                AppLog.debug("   Even the free tier requires a billing account!")
                AppLog.debug("")
                AppLog.debug("   Step 2: Enable 'Maps SDK for iOS' API")
                AppLog.debug("   https://console.cloud.google.com/apis/library/maps-ios-backend.googleapis.com")
                AppLog.debug("   Click 'Enable' button")
                AppLog.debug("")
                AppLog.debug("   Step 3: Check API Key Restrictions")
                AppLog.debug("   https://console.cloud.google.com/apis/credentials")
                AppLog.debug("   Set to 'None' for testing")
                AppLog.debug("")
            }
        }

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Update region if changed significantly (using MapRegion's zoom level directly - no conversion!)
        let currentCenter = mapView.camera.target
        let currentZoom = mapView.camera.zoom
        let targetZoom = region.span.zoomLevel  // Direct access, no lossy conversion!

        let centerChanged = abs(currentCenter.latitude - region.center.latitude) > 0.001 ||
                           abs(currentCenter.longitude - region.center.longitude) > 0.001
        let zoomChanged = abs(Double(currentZoom) - Double(targetZoom)) > 0.5

        if (centerChanged || zoomChanged) && !context.coordinator.isUserInteracting {
            let camera = GMSCameraPosition.camera(
                withLatitude: region.center.latitude,
                longitude: region.center.longitude,
                zoom: targetZoom
            )
            mapView.animate(to: camera)
        }

        // Update annotations (markers)
        context.coordinator.updateMarkers(
            pickup: pickupLocation,
            destination: destinationLocation,
            driver: driverLocation
        )

        // Routes are already in the correct format ([CLLocationCoordinate2D])
        // No type conversion needed - pass directly!
        context.coordinator.updateRoute(
            mapView: mapView,
            mainRoute: route,
            driverRoute: driverRoute,
            displayMode: routeDisplayMode
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapViewWrapper
        var isUserInteracting = false
        var mapView: GMSMapView?
        private var pickupMarker: GMSMarker?
        private var destinationMarker: GMSMarker?
        private var driverMarker: GMSMarker?
        private var currentPolyline: GMSPolyline?
        private var currentDisplayMode: RouteDisplayMode?
        fileprivate var tilesLoaded = false

        // Track last known marker positions to avoid unnecessary updates
        private var lastPickup: CLLocationCoordinate2D?
        private var lastDestination: CLLocationCoordinate2D?

        init(_ parent: GoogleMapViewWrapper) {
            self.parent = parent
        }

        func updateMarkers(pickup: CLLocationCoordinate2D?, destination: CLLocationCoordinate2D?, driver: CLLocationCoordinate2D?) {
            guard let mapView = mapView else { return }

            // Update pickup marker only if it changed (matches Apple Maps)
            if pickup != lastPickup {
                // Remove old pickup
                pickupMarker?.map = nil
                pickupMarker = nil

                // Add new pickup if it exists
                if let pickup = pickup {
                    pickupMarker = GMSMarker(position: pickup)
                    pickupMarker?.title = "Pickup"
                    pickupMarker?.icon = createMarkerIcon(color: .systemGreen, iconName: "location.fill")
                    pickupMarker?.map = mapView
                }

                lastPickup = pickup
            }

            // Update destination marker only if it changed (matches Apple Maps)
            if destination != lastDestination {
                // Remove old destination
                destinationMarker?.map = nil
                destinationMarker = nil

                // Add new destination if it exists
                if let destination = destination {
                    destinationMarker = GMSMarker(position: destination)
                    destinationMarker?.title = "Destination"
                    destinationMarker?.icon = createMarkerIcon(color: .systemBlue, iconName: "mappin")
                    destinationMarker?.map = mapView
                }

                lastDestination = destination
            }

            // Update driver marker with smooth animation (matches Apple Maps)
            if let driver = driver {
                if let existingDriver = driverMarker {
                    // Animate position change
                    CATransaction.begin()
                    CATransaction.setAnimationDuration(0.3)
                    existingDriver.position = driver
                    CATransaction.commit()
                } else {
                    // Create new driver marker
                    driverMarker = GMSMarker(position: driver)
                    driverMarker?.title = "Driver"
                    driverMarker?.icon = createCarIcon()
                    driverMarker?.map = mapView
                }
            } else {
                // Remove driver marker if no driver location
                driverMarker?.map = nil
                driverMarker = nil
            }
        }

        func updateRoute(mapView: GMSMapView, mainRoute: [CLLocationCoordinate2D]?, driverRoute: [CLLocationCoordinate2D]?, displayMode: RouteDisplayMode) {
            // Determine which route to display based on mode (matches Apple Maps)
            let routeToDisplay: [CLLocationCoordinate2D]?
            switch displayMode {
            case .approach:
                // Show driver route (driver → pickup) if available, otherwise show main route
                routeToDisplay = driverRoute ?? mainRoute
            case .activeRide:
                // Show main route (pickup → destination)
                routeToDisplay = mainRoute
            }

            // Check if we need to update the route (matches Apple Maps logic)
            let needsUpdate = !areCoordinatesEqual(currentPolyline?.path?.toCoordinates(), routeToDisplay) ||
                             currentDisplayMode != displayMode

            if needsUpdate {
                // Remove old route polyline
                if let currentPolyline = currentPolyline {
                    currentPolyline.map = nil
                    self.currentPolyline = nil
                }

                // Add new route polyline
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

                    self.currentPolyline = polyline
                    currentDisplayMode = displayMode

                    let routeType = displayMode == .approach ? "approach (driver → pickup)" : "active ride (pickup → destination)"
                    AppLog.debug("🛣️ Displaying \(routeType) route")
                }
            }
        }

        private func areCoordinatesEqual(_ lhs: [CLLocationCoordinate2D]?, _ rhs: [CLLocationCoordinate2D]?) -> Bool {
            guard let lhs = lhs, let rhs = rhs else {
                return lhs == nil && rhs == nil
            }
            guard lhs.count == rhs.count else { return false }
            return zip(lhs, rhs).allSatisfy { $0 == $1 }
        }

        // MARK: - GMSMapViewDelegate

        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            isUserInteracting = true
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            // Update parent's region when camera stops moving
            // Use MapRegion's zoom-based initializer - no lossy conversions!
            let region = MapRegion(
                center: position.target,
                zoom: position.zoom
            )

            DispatchQueue.main.async {
                self.parent.region = region
                self.isUserInteracting = false
            }
        }

        func mapViewDidFinishTileRendering(_ mapView: GMSMapView) {
            if !tilesLoaded {
                tilesLoaded = true
                AppLog.debug("")
                AppLog.debug("✅ Google Maps tiles finished rendering successfully!")
                AppLog.debug("   Map is now fully loaded and visible")
            }
        }

        func mapView(_ mapView: GMSMapView, didFailLoadingMapWithError error: Error) {
            AppLog.debug("")
            AppLog.error("❌ Google Maps FAILED to load map tiles")
            AppLog.debug("   Error: \(error.localizedDescription)")
            AppLog.debug("")
            AppLog.debug("🔧 How to fix this:")
            AppLog.debug("   1. Go to: https://console.cloud.google.com/billing")
            AppLog.debug("      ➜ Enable billing for your project (REQUIRED even for free tier)")
            AppLog.debug("")
            AppLog.debug("   2. Go to: https://console.cloud.google.com/apis/library")
            AppLog.debug("      ➜ Search: 'Maps SDK for iOS'")
            AppLog.debug("      ➜ Click: Enable (make sure it's iOS, not JavaScript)")
            AppLog.debug("")
            AppLog.debug("   3. Go to: https://console.cloud.google.com/apis/credentials")
            AppLog.debug("      ➜ Click your API key")
            AppLog.debug("      ➜ Application restrictions: Set to 'None' for testing")
            AppLog.debug("      ➜ Or add bundle ID: com.degenrides.Model-S")
            AppLog.debug("")
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            if !tilesLoaded {
                AppLog.debug("")
                AppLog.warning("⚠️ Map tapped but tiles haven't loaded yet")
                AppLog.debug("   This confirms tiles are not loading from Google")
            }
        }

        // MARK: - Icon Creation

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
    }
}

#else

/// Fallback when Google Maps SDK is not installed
/// Shows informative placeholder and uses Apple Maps
struct GoogleMapViewWrapper: UIViewRepresentable {
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

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
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
        titleLabel.text = "Google Maps SDK Required"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        // Message
        let messageLabel = UILabel()
        messageLabel.text = "To see Google Maps, install the SDK"
        messageLabel.font = .systemFont(ofSize: 18)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        // Instructions
        let instructionsLabel = UILabel()
        instructionsLabel.text = "See GOOGLE_MAPS_SETUP.md for instructions"
        instructionsLabel.font = .systemFont(ofSize: 14)
        instructionsLabel.textColor = .systemBlue
        instructionsLabel.textAlignment = .center
        instructionsLabel.numberOfLines = 0

        // Current status
        let statusLabel = UILabel()
        statusLabel.text = "Currently using: Apple Maps\n(Google services still active)"
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .systemGreen
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)
        stackView.addArrangedSubview(instructionsLabel)
        stackView.addArrangedSubview(statusLabel)

        containerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -40)
        ])

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Placeholder doesn't need updates
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
    }
}

#endif
