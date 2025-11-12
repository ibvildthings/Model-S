# Production Integration Guide

This guide explains how to integrate the RideRequestView component into a production ride-sharing app with all enterprise features enabled.

## Overview

The component now includes production-ready features:
- ✅ **Geocoding**: Convert addresses to coordinates automatically
- ✅ **Real Routing**: Calculate actual routes with MapKit Directions
- ✅ **Error Handling**: Comprehensive error states with user-friendly messages
- ✅ **Validation**: Ensure locations are valid before ride requests
- ✅ **Loading States**: Visual feedback during async operations
- ✅ **Cancellation**: Allow users to cancel requests
- ✅ **Location Permissions**: Proper permission management with Settings integration
- ✅ **Debouncing**: Prevent API spam with configurable delays

## Quick Start

### 1. Basic Production Setup

```swift
import SwiftUI

struct MyApp: View {
    @StateObject private var rideViewModel = RideRequestViewModel()

    var body: some View {
        RideRequestViewWithViewModel(
            viewModel: rideViewModel,
            configuration: .default,
            onRideConfirmed: { pickup, destination in
                // Submit to your backend
                submitRideRequest(pickup, destination)
            },
            onCancel: {
                // Handle cancellation
            }
        )
    }
}
```

### 2. Enable All Production Features

```swift
var config = RideRequestConfiguration.default
config.enableGeocoding = true           // Auto-convert addresses
config.enableRouteCalculation = true    // Real MapKit routing
config.enableValidation = true          // Validate before request
config.showRouteInfo = true            // Show ETA and distance
config.showErrorBanner = true          // User-friendly errors
config.geocodingDebounceDelay = 1.0    // Prevent API spam
```

## Core Components

### RideRequestViewModel

The main business logic controller for production apps.

```swift
@StateObject private var viewModel = RideRequestViewModel()

// Access computed properties
viewModel.pickupLocation        // LocationPoint?
viewModel.destinationLocation   // LocationPoint?
viewModel.route                 // MKRoute?
viewModel.estimatedTravelTime   // TimeInterval?
viewModel.estimatedDistance     // CLLocationDistance?
viewModel.error                 // RideRequestError?
viewModel.isLoading            // Bool

// Formatted display
viewModel.formattedTravelTime() // "15 min"
viewModel.formattedDistance()   // "3.2 mi"

// Operations
await viewModel.geocodeAddress("123 Main St", isPickup: true)
await viewModel.calculateRoute()
viewModel.validateLocations()
viewModel.reset()
viewModel.cancelRideRequest()
```

### Error Handling

All errors are typed and provide user-friendly messages:

```swift
enum RideRequestError {
    case locationPermissionDenied
    case locationServicesDisabled
    case locationUnavailable
    case geocodingFailed
    case routeCalculationFailed
    case invalidPickupLocation
    case invalidDestinationLocation
    case networkUnavailable
    case unknown(Error)
}

// Display errors
if let error = viewModel.error {
    ErrorBannerView(error: error, onDismiss: {
        viewModel.error = nil
    })
}
```

### Geocoding Integration

Automatic address-to-coordinate conversion with debouncing:

```swift
// Forward geocoding (address → coordinates)
await viewModel.geocodeAddress("Apple Park, Cupertino", isPickup: false)

// Reverse geocoding (coordinates → address)
await viewModel.reverseGeocodeLocation(coordinate, isPickup: true)

// Access results
print(viewModel.pickupAddress)     // "1 Apple Park Way"
print(viewModel.destinationAddress) // "Tesla HQ"
```

### Route Calculation

Real routes with ETA and distance:

```swift
// Calculate route between locations
await viewModel.calculateRoute()

// Access route details
if let route = viewModel.route {
    let polyline = route.polyline
    let steps = route.steps
    let time = viewModel.estimatedTravelTime  // seconds
    let distance = viewModel.estimatedDistance // meters
}

// Display on map
mapViewModel.updateRouteFromMKRoute(route)
```

## Backend Integration

### Submitting Ride Requests

```swift
func handleRideConfirmed(pickup: LocationPoint, destination: LocationPoint) {
    Task {
        do {
            let request = RideRequest(
                pickupLat: pickup.coordinate.latitude,
                pickupLng: pickup.coordinate.longitude,
                pickupName: pickup.name,
                destinationLat: destination.coordinate.latitude,
                destinationLng: destination.coordinate.longitude,
                destinationName: destination.name,
                estimatedDistance: viewModel.estimatedDistance,
                estimatedTime: viewModel.estimatedTravelTime
            )

            let response = try await apiClient.submitRideRequest(request)

            // Navigate to ride tracking
            showRideTracking(rideId: response.rideId)

        } catch {
            viewModel.error = .unknown(error)
        }
    }
}
```

### Analytics Integration

```swift
// Track key events
func trackRideRequest() {
    analytics.track("Ride Requested", properties: [
        "pickup_lat": pickup.coordinate.latitude,
        "pickup_lng": pickup.coordinate.longitude,
        "destination_lat": destination.coordinate.latitude,
        "destination_lng": destination.coordinate.longitude,
        "estimated_distance": viewModel.estimatedDistance,
        "estimated_time": viewModel.estimatedTravelTime,
        "timestamp": Date()
    ])
}
```

## Advanced Configuration

### Custom Error Handling

```swift
// Override default error handling
if let error = viewModel.error {
    switch error {
    case .locationPermissionDenied:
        showPermissionAlert()
    case .geocodingFailed:
        showAddressInputHelper()
    case .routeCalculationFailed:
        fallbackToManualInput()
    default:
        showGenericError()
    }
}
```

### Network Monitoring

```swift
import Network

class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
}

// Use in view
@StateObject private var networkMonitor = NetworkMonitor()

if !networkMonitor.isConnected {
    viewModel.error = .networkUnavailable
}
```

### Debouncing Best Practices

```swift
// Adjust debounce delay based on use case
var config = RideRequestConfiguration.default

// Fast typing users
config.geocodingDebounceDelay = 0.8

// Reduce API calls
config.geocodingDebounceDelay = 1.5

// Real-time search
config.geocodingDebounceDelay = 0.5
```

## Performance Optimization

### Memory Management

```swift
class RideCoordinator {
    private var viewModel: RideRequestViewModel?

    func showRideRequest() {
        viewModel = RideRequestViewModel()
        // Use viewModel
    }

    func cleanup() {
        viewModel?.reset()
        viewModel = nil
    }
}
```

### Location Updates

```swift
// Stop updates when not needed
func pauseLocationTracking() {
    mapViewModel.stopUpdatingLocation()
}

// Resume when needed
func resumeLocationTracking() {
    mapViewModel.requestLocationPermission()
}
```

## Testing

### Unit Testing ViewModels

```swift
@Test
func testGeocodingSuccess() async throws {
    let viewModel = RideRequestViewModel()

    await viewModel.geocodeAddress("Apple Park", isPickup: true)

    #expect(viewModel.pickupLocation != nil)
    #expect(viewModel.error == nil)
}

@Test
func testValidationFailure() {
    let viewModel = RideRequestViewModel()

    let isValid = viewModel.validateLocations()

    #expect(!isValid)
    #expect(viewModel.error == .invalidPickupLocation)
}
```

### UI Testing

```swift
@Test
func testErrorBannerDisplay() {
    let app = XCUIApplication()
    app.launch()

    // Deny location permissions
    app.alerts.buttons["Don't Allow"].tap()

    // Verify error banner appears
    XCTAssertTrue(app.staticTexts["Location access denied"].exists)
    XCTAssertTrue(app.buttons["Open Settings"].exists)
}
```

## Migration Guide

### From Basic to Production

If you're using the basic `RideRequestView`, migrate to production:

**Before:**
```swift
RideRequestView(
    onPickupSelected: { text in print(text) },
    onDestinationSelected: { text in print(text) },
    onConfirmRide: { print("Confirmed") }
)
```

**After:**
```swift
@StateObject private var viewModel = RideRequestViewModel()

RideRequestViewWithViewModel(
    viewModel: viewModel,
    configuration: productionConfig,
    onRideConfirmed: { pickup, destination in
        submitToBackend(pickup, destination)
    },
    onCancel: { dismissView() }
)
```

## Production Checklist

Before deploying to production, ensure:

- [x] Location permissions configured in Info.plist
- [x] Error handling implemented for all cases
- [x] Backend API integration tested
- [x] Analytics tracking added
- [x] Network connectivity monitoring
- [x] Loading states visible to users
- [x] Cancellation flow tested
- [x] Memory leaks checked
- [x] Performance profiling done
- [x] Accessibility verified
- [x] Dark mode tested
- [x] Edge cases handled (no GPS, poor network, invalid addresses)

## Support

For production issues or questions:
1. Check error logs from `RideRequestError`
2. Verify configuration flags
3. Test with `ProductionExampleView`
4. Review backend integration

## Example Apps

See `ProductionExampleView.swift` for a complete reference implementation with:
- Full error handling
- Backend submission pattern
- State management
- Loading indicators
- Cancellation flow

---

**Ready for Production** ✅

This component has been engineered for real-world ride-sharing apps with all the features needed for a production deployment.
