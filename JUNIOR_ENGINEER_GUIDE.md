# Model S - Junior Engineer's Guide

Welcome to the Model S codebase! This guide will help you understand how this iOS ride-sharing app works and how to build upon it. Each section builds on the previous one, starting with the basics and gradually diving deeper.

---

## Table of Contents

1. [What Is This App?](#1-what-is-this-app)
2. [Getting Started](#2-getting-started)
3. [Understanding the Big Picture](#3-understanding-the-big-picture)
4. [Core Architecture Explained](#4-core-architecture-explained)
5. [The State Machine - Heart of the App](#5-the-state-machine---heart-of-the-app)
6. [How Data Flows Through the App](#6-how-data-flows-through-the-app)
7. [Key Components Deep Dive](#7-key-components-deep-dive)
8. [Services and Protocols](#8-services-and-protocols)
9. [Map Features](#9-map-features)
10. [Storage and Persistence](#10-storage-and-persistence)
11. [How to Add New Features](#11-how-to-add-new-features)
12. [Common Development Tasks](#12-common-development-tasks)
13. [Testing Your Changes](#13-testing-your-changes)
14. [Best Practices](#14-best-practices)
15. [Troubleshooting](#15-troubleshooting)
16. [Resources for Learning](#16-resources-for-learning)

---

## 1. What Is This App?

**Model S** is a production-ready iOS ride-sharing application, similar to Uber or Lyft. It's built entirely with modern Swift and SwiftUI.

### Key Features:
- Request a ride by selecting pickup and destination locations
- See your route on an interactive map with ETA and distance
- Watch a simulated driver travel to pick you up
- View your ride history with all past trips

### Technology Stack:
- **Language:** Swift 5.x
- **UI Framework:** SwiftUI (iOS 14+)
- **State Management:** Combine framework
- **Maps:** Apple MapKit
- **Persistence:** UserDefaults
- **No third-party dependencies!** Everything uses Apple's native frameworks.

### Current Status:
The app is fully functional with a **mock backend**. All the UI, state management, and map features work perfectly. You just need to connect it to a real API to make it production-ready.

---

## 2. Getting Started

### Running the App

1. **Open the project:**
   ```bash
   open "Model S.xcodeproj"
   ```

2. **Select a simulator:** iPhone 14 or newer recommended

3. **Run the app:** Press `⌘R` or click the Run button

4. **Try the features:**
   - Tap "Order a ride"
   - Type an address or tap the map to select pickup location
   - Do the same for destination
   - Slide to confirm
   - Watch the driver animation!

### Project Structure at a Glance

```
Model S/
├── App/                  # App entry point
├── Core/                 # Shared code used everywhere
│   ├── Models/          # Data structures
│   ├── Services/        # Business logic (maps, rides, storage)
│   └── Utilities/       # Helper functions and constants
└── Features/            # User-facing features
    ├── Home/           # Home screen
    ├── RideRequest/    # Main ride request feature
    └── RideHistory/    # Past rides list
```

**Golden Rule:**
- **Core** = Shared utilities and business logic
- **Features** = User-facing screens and flows

---

## 3. Understanding the Big Picture

### The User's Journey

Let's follow what happens when a user requests a ride:

```
User opens app
    ↓
Taps "Order a ride"
    ↓
Enters pickup location → App geocodes address to coordinates
    ↓
Enters destination → App calculates route and shows ETA
    ↓
Slides to confirm → Request sent to backend
    ↓
"Finding driver..." → App polls for driver assignment
    ↓
Driver found! → Shows driver info and location
    ↓
Driver travels to pickup → Animated on map
    ↓
Driver arrives → User gets in car
    ↓
Ride in progress → Shows ETA to destination
    ↓
Ride completed → Saved to history
```

### Three Main Layers

Think of the app as having three layers, like a cake:

```
┌─────────────────────────────────────┐
│  VIEWS (SwiftUI)                    │  ← What the user sees
│  RideRequestView, MapView, etc.     │
└─────────────────────────────────────┘
            ↕ Observes
┌─────────────────────────────────────┐
│  COORDINATOR & VIEWMODELS (Logic)   │  ← The brain
│  RideRequestCoordinator             │
│  RideFlowController (State Machine) │
└─────────────────────────────────────┘
            ↕ Calls
┌─────────────────────────────────────┐
│  SERVICES (Data Access)             │  ← External interactions
│  Maps, Geocoding, Ride API          │
└─────────────────────────────────────┘
```

**Views** display information and respond to user taps. They're "dumb" - they don't contain logic.

**Coordinator/ViewModels** contain all the logic. They process user actions and update state.

**Services** handle external stuff like talking to Apple Maps or the backend API.

---

## 4. Core Architecture Explained

This app uses **MVVM (Model-View-ViewModel)** combined with two powerful patterns:
- **Coordinator Pattern** for complex flows
- **State Machine** for managing ride states

### What is MVVM?

**Model:** Your data structures (`LocationPoint`, `RideHistory`)
```swift
struct LocationPoint {
    let coordinate: CLLocationCoordinate2D
    let name: String?
}
```

**View:** What the user sees (SwiftUI views)
```swift
struct RideRequestView: View {
    @ObservedObject var coordinator: RideRequestCoordinator

    var body: some View {
        // UI code only - no logic!
    }
}
```

**ViewModel:** The logic that prepares data for the view
```swift
class MapViewModel: ObservableObject {
    @Published var pickupLocation: LocationPoint?
    @Published var destinationLocation: LocationPoint?
    // Logic for updating map display
}
```

### The Magic: `@Published` and `@ObservedObject`

When the ViewModel updates a `@Published` property:
```swift
@Published var pickupLocation: LocationPoint?
```

Any view observing it automatically re-renders:
```swift
@ObservedObject var viewModel: MapViewModel

var body: some View {
    // This updates automatically when viewModel.pickupLocation changes!
    if let pickup = viewModel.pickupLocation {
        Text(pickup.name)
    }
}
```

**No need to manually refresh the UI!** This is the power of Combine and SwiftUI working together.

### Why Use a Coordinator?

Coordinators handle complex user flows. Instead of each view knowing about navigation and business logic, the **Coordinator orchestrates everything**.

**Without Coordinator** (messy):
```swift
// View has to know too much!
Button("Confirm") {
    // Geocode addresses
    // Calculate route
    // Validate locations
    // Submit request
    // Handle errors
    // Update map
}
```

**With Coordinator** (clean):
```swift
// View just tells coordinator what happened
Button("Confirm") {
    coordinator.startRideRequest()
}
```

The coordinator handles all the steps internally!

---

## 5. The State Machine - Heart of the App

### Why a State Machine?

Imagine trying to track a ride with individual boolean flags:

```swift
// BAD: Easy to get into invalid states
var hasPickup = false
var hasDestination = false
var isSearchingForDriver = false
var hasDriver = false
var driverInfo: DriverInfo? = nil
// What if hasDriver = true but driverInfo = nil? 💥
```

With a state machine, **invalid states are impossible**:

```swift
// GOOD: Each state is explicit
enum RideState {
    case idle
    case selectingLocations(pickup: LocationPoint?, destination: LocationPoint?)
    case searchingForDriver(rideId: String, pickup: LocationPoint, destination: LocationPoint)
    case driverAssigned(rideId: String, driver: DriverInfo, pickup: LocationPoint, destination: LocationPoint)
    // ... more states
}
```

**Key insight:** You can ONLY be in one state at a time, and each state has exactly the data it needs.

### The States Explained

Here are all possible states a ride can be in:

1. **idle** - Starting point, nothing selected
2. **selectingLocations** - User is choosing pickup/destination
3. **routeReady** - Both locations set, route calculated
4. **submittingRequest** - Sending request to server
5. **searchingForDriver** - Waiting for driver assignment
6. **driverAssigned** - Driver found! Showing info
7. **driverEnRoute** - Driver traveling to pickup
8. **driverArriving** - Driver close to pickup (< 100m)
9. **rideInProgress** - User in car, traveling to destination
10. **approachingDestination** - Almost there!
11. **rideCompleted** - Trip finished
12. **error** - Something went wrong

### State Transitions

The `RideStateMachine` validates that transitions make sense:

```swift
// Valid: idle → selectingLocations
✅ User starts selecting locations

// Valid: routeReady → submittingRequest
✅ User confirms ride

// Invalid: idle → rideInProgress
❌ Can't be in a ride without selecting locations!
```

This prevents bugs where the app gets into a weird state.

### Accessing State Data

Each state carries relevant data as **associated values**:

```swift
switch currentState {
case .idle:
    // No data needed

case .selectingLocations(let pickup, let destination):
    // Access optional pickup/destination

case .driverAssigned(let rideId, let driver, let pickup, let destination):
    // Access driver info, ride ID, and locations

case .error(let error, let previousState):
    // Access error and what state we came from
}
```

**Tip for beginners:** Think of associated values as parameters that come with each state. Different states need different data!

---

## 6. How Data Flows Through the App

Let's trace what happens when a user selects a pickup location:

### Step-by-Step Flow

```
1. User Types Address in TextField
   ↓
   TextField(text: $pickupAddress)
   onChange { address in
       coordinator.addressTextChanged(address, isPickup: true)
   }

2. Coordinator Debounces the Input
   ↓
   func addressTextChanged(_ address: String, isPickup: Bool) {
       geocodingDebouncer.debounce {
           // Wait 1 second after user stops typing
           await geocodeAddress(address, isPickup: isPickup)
       }
   }

3. Coordinator Calls Geocoding Service
   ↓
   let (coordinate, name) = try await geocodingService.geocode(address: address)

4. Coordinator Updates State Machine
   ↓
   await flowController.updatePickup(LocationPoint(coordinate: coordinate, name: name))

5. State Machine Updates State
   ↓
   currentState = .selectingLocations(pickup: newPickup, destination: currentDestination)

6. State Machine Notifies via @Published
   ↓
   @Published private(set) var currentState: RideState

7. Coordinator Updates Map ViewModel
   ↓
   mapViewModel.updatePickupLocation(coordinate, name: name)

8. MapViewModel Publishes Change
   ↓
   @Published var pickupLocation: LocationPoint?

9. Views Automatically Re-render
   ↓
   Any view observing coordinator or mapViewModel updates!
```

### Key Concept: Reactive Programming

The app uses **Combine** for reactive data flow:

```swift
// When this changes...
@Published var pickupLocation: LocationPoint?

// This automatically updates...
var body: some View {
    if let pickup = viewModel.pickupLocation {
        Text(pickup.name)  // ← Renders new value
    }
}
```

No manual "refresh" needed! The framework handles it.

### Understanding Async/Await

Many operations are asynchronous:

```swift
// OLD WAY (callbacks - messy!)
geocodingService.geocode(address: "123 Main St") { result in
    switch result {
    case .success(let location):
        updateLocation(location)
    case .failure(let error):
        handleError(error)
    }
}

// NEW WAY (async/await - clean!)
do {
    let location = try await geocodingService.geocode(address: "123 Main St")
    updateLocation(location)
} catch {
    handleError(error)
}
```

**Why `await`?** It tells Swift "this might take time, let other code run while waiting."

---

## 7. Key Components Deep Dive

### 7.1 RideRequestCoordinator

**File:** `Features/RideRequest/Coordinators/RideRequestCoordinator.swift`

**Role:** The "conductor" that orchestrates the entire ride request flow.

```swift
@MainActor
class RideRequestCoordinator: ObservableObject {
    @Published var flowController: RideFlowController  // State machine
    @Published var mapViewModel: MapViewModel          // Map display

    // Main methods you'll use:

    func selectLocation(coordinate:, name:, isPickup:) async {
        // User selected a location (tap on map or autocomplete)
    }

    func addressTextChanged(_ address: String, isPickup: Bool) {
        // User typed in address field
        // Debounces and geocodes
    }

    func startRideRequest() async {
        // User confirmed ride
        // Submits request and starts driver search
    }

    func cancelCurrentRide() async {
        // User canceled
        // Resets state
    }
}
```

**When to modify:** When adding new user actions or orchestrating new flows.

### 7.2 RideFlowController

**File:** `Features/RideRequest/Controllers/RideFlowController.swift`

**Role:** Manages the ride state machine.

```swift
@MainActor
class RideFlowController: ObservableObject {
    @Published private(set) var currentState: RideState = .idle

    // State updates:

    func updatePickup(_ location: LocationPoint?) {
        // Updates pickup in current state
    }

    func updateDestination(_ location: LocationPoint?) {
        // Updates destination in current state
    }

    func calculateRoute(from: LocationPoint, to: LocationPoint) async {
        // Calls route service and transitions to routeReady
    }

    func requestRide() async {
        // Submits ride request and transitions to searchingForDriver
    }

    // Computed properties for easy access:

    var pickupLocation: LocationPoint? {
        // Extracts pickup from current state
    }

    var shouldShowConfirmSlider: Bool {
        // True when in routeReady state
    }
}
```

**When to modify:** When adding new states or changing state transition logic.

### 7.3 MapViewModel

**File:** `Features/RideRequest/ViewModels/MapViewModel.swift`

**Role:** Manages what displays on the map.

```swift
@MainActor
class MapViewModel: NSObject, ObservableObject {
    @Published var pickupLocation: LocationPoint?
    @Published var destinationLocation: LocationPoint?
    @Published var routePolyline: MKPolyline?  // The blue line showing route
    @Published var driverLocation: CLLocationCoordinate2D?
    @Published var region: MKCoordinateRegion  // What area of map to show

    // Map updates:

    func updatePickupLocation(_ coordinate:, name:) {
        pickupLocation = LocationPoint(coordinate: coordinate, name: name)
        updateMapRegion()  // Auto-zoom to show relevant area
    }

    func updateRouteFromMKRoute(_ route: MKRoute) {
        routePolyline = route.polyline
        updateMapRegion()  // Zoom to show entire route
    }

    // Driver animation:

    func startDriverAnimation(from startPoint:) {
        // Smoothly animates driver along route
        // Updates driverLocation every 0.1 seconds
    }

    func stopDriverAnimation() {
        animationTimer?.invalidate()
    }
}
```

**When to modify:** When adding new map features (e.g., multiple drivers, traffic overlays).

### 7.4 RideStateMachine

**File:** `Features/RideRequest/Models/RideStateMachine.swift`

**Role:** Validates state transitions.

```swift
struct RideStateMachine {
    func canTransition(from current: RideState, to next: RideState) -> Bool {
        let validNext = validNextStates(from: current)
        return validNext.contains(where: { statesMatch($0, next) })
    }

    private func validNextStates(from state: RideState) -> [RideState] {
        switch state {
        case .idle:
            return [.selectingLocations()]

        case .selectingLocations:
            return [.idle, .routeReady(), .selectingLocations()]

        case .routeReady:
            return [.selectingLocations(), .submittingRequest()]

        // ... more rules
        }
    }
}
```

**When to modify:** When adding new states or changing which transitions are allowed.

---

## 8. Services and Protocols

### Why Use Protocols?

Protocols define **what** a service can do, without specifying **how** it does it. This app has been refactored to use a **unified service interface** for all map operations, making it incredibly simple and maintainable.

### The Modern Map Service Architecture

**Before Refactoring:**
- 3 separate protocols (LocationSearchService, GeocodingService, RouteCalculationService)
- 2 state managers (confusing!)
- Complex factory pattern

**After Refactoring:**
- 1 unified `MapService` protocol (simple!)
- 1 state manager (`MapProviderService`)
- Clean composition pattern

### 8.1 The Unified MapService Protocol

All map operations now go through a single, elegant interface:

```swift
@MainActor
protocol MapService: ObservableObject {
    // Search operations
    var searchResults: [LocationSearchResult] { get }
    var isSearching: Bool { get }
    func search(query: String)
    func getCoordinate(for result: LocationSearchResult) async throws -> (CLLocationCoordinate2D, String)

    // Geocoding operations
    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String)
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String

    // Routing operations
    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult

    // Provider info
    var provider: MapProvider { get }
}
```

**Why is this better?**
- **Simpler:** Learn one interface instead of three
- **Extensible:** Add new map providers by implementing just this one protocol
- **Consistent:** All operations use the same error handling
- **Testable:** Easy to create mock services

### 8.2 Using the Map Service

**Get the current map service:**
```swift
// The easy way - always use the current provider
let mapService = MapProviderService.shared.currentService

// Now use it for any map operation!
mapService.search(query: "Coffee shops")
let (coord, name) = try await mapService.geocode(address: "123 Main St")
let route = try await mapService.calculateRoute(from: pickup, to: destination)
```

**All operations in one place!** No more juggling multiple services.

### 8.3 Map Provider Management

The `MapProviderService` is your single source of truth for managing map providers:

```swift
@MainActor
class MapProviderService: ObservableObject {
    static let shared = MapProviderService()

    // Current provider (Apple or Google)
    @Published private(set) var currentProvider: MapProvider

    // Current service instance (auto-updates when provider changes!)
    @Published private(set) var currentService: AnyMapService

    // Check what's available
    var isAppleMapsAvailable: Bool { true }  // Always available
    var isGoogleMapsAvailable: Bool { /* checks API key */ }
    var availableProviders: [MapProvider] { /* returns available ones */ }

    // Switch providers
    func useAppleMaps() -> Result<Void, MapServiceError>
    func useGoogleMaps() -> Result<Void, MapServiceError>
    func toggleProvider()
}
```

**Key features:**
- Automatically saves your choice to UserDefaults
- Validates that provider is available before switching
- Updates `currentService` automatically when you switch
- Returns `Result` for proper error handling (no crashes!)

**Example - Switching providers:**
```swift
// Try to use Google Maps
let result = MapProviderService.shared.useGoogleMaps()

switch result {
case .success:
    print("✅ Now using Google Maps")
case .failure(let error):
    print("❌ Can't use Google Maps: \(error.localizedDescription)")
    // Maybe show alert: "Google Maps requires an API key"
}
```

### 8.4 Complete Usage Examples

#### Example 1: Search for Locations

```swift
// Get the service
let mapService = MapProviderService.shared.currentService

// Start searching (results update automatically via @Published)
mapService.search(query: "Starbucks")

// Display results in your view
List(mapService.searchResults) { result in
    Text(result.title)  // "Starbucks"
    Text(result.subtitle)  // "123 Main St, San Francisco"
}

// User selects a result
let (coordinate, name) = try await mapService.getCoordinate(for: result)
// You now have the exact location!
```

#### Example 2: Geocode an Address

```swift
// User typed an address
let userAddress = "1 Apple Park Way, Cupertino, CA"

do {
    let (coord, formattedAddress) = try await mapService.geocode(address: userAddress)
    print("Found: \(formattedAddress)")
    print("At: \(coord.latitude), \(coord.longitude)")
    // Show pin on map at this coordinate
} catch {
    print("Couldn't find that address: \(error)")
    // Show error to user
}
```

#### Example 3: Calculate a Route

```swift
let pickupCoord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
let destinationCoord = CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)

do {
    let route = try await mapService.calculateRoute(from: pickupCoord, to: destinationCoord)

    // Show route info
    let miles = route.distance / 1609.34
    let minutes = route.expectedTravelTime / 60
    print("Route: \(miles) miles, \(minutes) minutes")

    // Draw route on map
    mapViewModel.routePolyline = route.coordinates  // Provider-agnostic!
} catch {
    print("Couldn't calculate route: \(error)")
}
```

### 8.5 Map Service Implementations

Behind the scenes, there are two implementations:

**AppleMapService:**
```swift
@MainActor
class AppleMapService: MapService {
    let provider: MapProvider = .apple

    // Composes existing Apple services
    private let searchService: AppleLocationSearchService
    private let geocodingService: AppleGeocodingService
    private let routeService: AppleRouteCalculationService

    // Implements all MapService methods by delegating
}
```

**GoogleMapService:**
```swift
@MainActor
class GoogleMapService: MapService {
    let provider: MapProvider = .google

    // Composes existing Google services
    private let searchService: GoogleLocationSearchService
    private let geocodingService: GoogleGeocodingService
    private let routeService: GoogleRouteCalculationService

    // Implements all MapService methods by delegating
}
```

**You don't create these directly!** Always use `MapProviderService.shared.currentService`.

### 8.6 Error Handling

The new architecture has proper error types:

```swift
enum MapServiceError: Error {
    case apiKeyMissing(provider: MapProvider)
    case networkError(underlying: Error)
    case invalidResponse
    case noResultsFound
    case geocodingFailed
    case routeCalculationFailed

    var localizedDescription: String {
        // User-friendly error messages
    }
}
```

**Handle errors gracefully:**
```swift
do {
    let route = try await mapService.calculateRoute(from: pickup, to: destination)
    // Success!
} catch let error as MapServiceError {
    // Specific map error
    showAlert(title: "Map Error", message: error.localizedDescription)
} catch {
    // Unexpected error
    showAlert(title: "Error", message: "Something went wrong")
}
```

### 8.7 RideRequestService

**Purpose:** Communicate with ride backend (unchanged from refactoring)

```swift
protocol RideRequestService {
    func requestRide(pickup: LocationPoint, destination: LocationPoint) async throws -> RideRequestResult
    func getRideStatus(rideId: String) async throws -> RideRequestResult
    func cancelRide(rideId: String) async throws
}

struct RideRequestResult {
    let rideId: String
    let driver: DriverInfo?
    let status: RideRequestStatus
    let estimatedArrival: TimeInterval?
}
```

**Current Implementation:** Uses `MockRideRequestService` which simulates a backend.

**To connect to real API:**
```swift
class RealRideRequestService: RideRequestService {
    func requestRide(pickup: LocationPoint, destination: LocationPoint) async throws -> RideRequestResult {
        // Make HTTP request to your backend
        let url = URL(string: "https://yourapi.com/rides")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // ... set body, headers

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(RideRequestResult.self, from: data)
    }
}
```

### Quick Reference

**Old way (before refactoring):**
```swift
// Had to juggle multiple services
let searchService = MapServiceFactory.shared.createLocationSearchService()
let geocodingService = MapServiceFactory.shared.createGeocodingService()
let routeService = MapServiceFactory.shared.createRouteCalculationService()

// Use different services for different operations
searchService.search(query: "Coffee")
let (coord, name) = try await geocodingService.geocode(address: "Main St")
let route = try await routeService.calculateRoute(from: pickup, to: destination)
```

**New way (after refactoring):**
```swift
// One service does everything!
let mapService = MapProviderService.shared.currentService

mapService.search(query: "Coffee")
let (coord, name) = try await mapService.geocode(address: "Main St")
let route = try await mapService.calculateRoute(from: pickup, to: destination)
```

**Much simpler!** 🎉

---

## 9. Map Features

### 9.1 Map Display Basics

The map is a `UIViewRepresentable` wrapper around `MKMapView`:

```swift
struct MapViewWrapper: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update pins, route, etc. when viewModel changes
    }
}
```

**Why `UIViewRepresentable`?** SwiftUI doesn't have a native map view yet, so we wrap UIKit's `MKMapView`.

### 9.2 Showing Pins

Pins are managed by `MKAnnotation`:

```swift
class LocationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let type: LocationType  // .pickup or .destination
}
```

**Adding a pin:**
```swift
let annotation = LocationAnnotation(
    coordinate: pickupCoord,
    title: "Pickup",
    type: .pickup
)
mapView.addAnnotation(annotation)
```

**Customizing pin appearance:**
```swift
func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    if let locationAnnotation = annotation as? LocationAnnotation {
        switch locationAnnotation.type {
        case .pickup:
            view.markerTintColor = .systemGreen
        case .destination:
            view.markerTintColor = .systemBlue
        }
    }
}
```

### 9.3 Drawing Routes

Routes are drawn using `MKPolyline`:

```swift
// After calculating route
mapViewModel.routePolyline = route.polyline

// In MapViewWrapper
if let polyline = viewModel.routePolyline {
    mapView.addOverlay(polyline)
}

// Customize appearance
func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    let renderer = MKPolylineRenderer(overlay: overlay)
    renderer.strokeColor = .systemBlue
    renderer.lineWidth = 4
    return renderer
}
```

### 9.4 Driver Animation

The driver is animated along the route:

```swift
func startDriverAnimation(from startPoint: CLLocationCoordinate2D?) {
    guard let polyline = routePolyline else { return }

    // Get all points in the route
    let points = polyline.points()
    let totalPoints = polyline.pointCount

    // Set starting position
    currentDriverLocation = startPoint ?? pickupLocation?.coordinate
    routeProgress = 0.0  // 0 = start, 1 = end

    // Update position every 0.1 seconds
    animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        guard let self = self else { return }

        // Move along route
        self.routeProgress += 0.008  // Speed of animation

        if self.routeProgress >= 1.0 {
            // Reached destination
            self.stopDriverAnimation()
            return
        }

        // Calculate new position on route
        let index = Int(Double(totalPoints - 1) * self.routeProgress)
        let newLocation = points[index].coordinate

        self.driverLocation = newLocation

        // Check if approaching pickup
        if self.isDriverNearPickup() {
            self.onDriverApproaching?()  // Notify coordinator
        }
    }
}
```

**Key concepts:**
- `routeProgress` goes from 0.0 to 1.0
- Every 0.1s, progress increases by 0.008 (controls speed)
- New position calculated by indexing into polyline points
- Callbacks notify coordinator of events (approaching, arrived)

### 9.5 Auto-Zooming the Map

The map automatically adjusts to show all relevant points:

```swift
func updateMapRegion() {
    var coordinates: [CLLocationCoordinate2D] = []

    // Add all points we want to show
    if let pickup = pickupLocation {
        coordinates.append(pickup.coordinate)
    }
    if let destination = destinationLocation {
        coordinates.append(destination.coordinate)
    }
    if let driver = driverLocation {
        coordinates.append(driver)
    }

    guard !coordinates.isEmpty else { return }

    // Calculate bounding box
    let mapRect = coordinates.reduce(MKMapRect.null) { rect, coord in
        let point = MKMapPoint(coord)
        let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
        return rect.union(pointRect)
    }

    // Add padding and animate
    let padding = UIEdgeInsets(top: 100, left: 50, bottom: 100, right: 50)
    region = MKCoordinateRegion(mapRect.insetBy(dx: -padding.left, dy: -padding.top))
}
```

**When called:** Anytime pickup, destination, or driver location changes.

---

## 10. Storage and Persistence

### 10.1 Ride History Storage

**File:** `Core/Services/Storage/RideHistoryStore.swift`

The app saves completed rides using `UserDefaults`:

```swift
@MainActor
class RideHistoryStore: ObservableObject {
    static let shared = RideHistoryStore()  // Singleton

    @Published var rides: [RideHistory] = []

    private let userDefaultsKey = "com.modelS.rideHistory"
    private let maxRides = 100  // Keep most recent 100

    init() {
        loadRides()
    }

    func addRide(_ ride: RideHistory) {
        rides.insert(ride, at: 0)  // Add to beginning

        // Trim if too many
        if rides.count > maxRides {
            rides = Array(rides.prefix(maxRides))
        }

        saveRides()
    }

    private func saveRides() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(rides) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadRides() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([RideHistory].self, from: data) {
            rides = decoded
        }
    }
}
```

**Key points:**
- Singleton pattern: `RideHistoryStore.shared`
- `@Published var rides` allows views to observe changes
- JSON encoding/decoding for easy storage
- Automatic save on every change

### 10.2 The RideHistory Model

```swift
struct RideHistory: Identifiable, Codable, Equatable {
    let id: UUID
    let pickupLocation: LocationPoint
    let destinationLocation: LocationPoint
    let distance: Double  // Meters
    let estimatedTravelTime: TimeInterval  // Seconds
    let timestamp: Date
    let pickupAddress: String
    let destinationAddress: String

    // Computed properties for display
    var formattedDistance: String {
        let miles = distance / 1609.34
        return String(format: "%.1f mi", miles)
    }

    var formattedTravelTime: String {
        let minutes = Int(estimatedTravelTime / 60)
        return "\(minutes) min"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
```

### 10.3 Adding a Ride

When a ride completes:

```swift
// In RideFlowController
case .rideCompleted(let rideId, let driver, let pickup, let destination):
    // Create history entry
    let ride = RideHistory(
        id: UUID(),
        pickupLocation: pickup,
        destinationLocation: destination,
        distance: routeInfo.distance,
        estimatedTravelTime: routeInfo.expectedTravelTime,
        timestamp: Date(),
        pickupAddress: pickup.name ?? "Unknown",
        destinationAddress: destination.name ?? "Unknown"
    )

    // Save to history
    RideHistoryStore.shared.addRide(ride)
```

### 10.4 Displaying History

```swift
struct RideHistoryView: View {
    @ObservedObject var store = RideHistoryStore.shared

    var body: some View {
        List(store.rides) { ride in
            VStack(alignment: .leading) {
                Text(ride.pickupAddress)
                Text("→ \(ride.destinationAddress)")
                HStack {
                    Text(ride.formattedDistance)
                    Text("•")
                    Text(ride.formattedTravelTime)
                    Text("•")
                    Text(ride.formattedDate)
                }
            }
        }
    }
}
```

**Automatic updates:** When `store.rides` changes, the List automatically re-renders!

---

## 11. How to Add New Features

Let's walk through adding a new feature: **Estimated Ride Cost**

### Step 1: Update the Data Model

Add cost to `RouteResult`:

```swift
// In RouteCalculationService protocol
struct RouteResult {
    let route: MKRoute
    let distance: Double
    let expectedTravelTime: TimeInterval
    let polyline: MKPolyline
    let estimatedCost: Double?  // ← NEW
}
```

### Step 2: Calculate in Service

Update the service implementation:

```swift
// In AppleRouteCalculationService
func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult {
    // ... existing route calculation ...

    // Calculate cost: $2 base + $1.50 per mile
    let miles = route.distance / 1609.34
    let cost = 2.0 + (miles * 1.50)

    return RouteResult(
        route: route,
        distance: route.distance,
        expectedTravelTime: route.expectedTravelTime,
        polyline: route.polyline,
        estimatedCost: cost  // ← NEW
    )
}
```

### Step 3: Update State

Add cost to `RideState`:

```swift
case routeReady(
    pickup: LocationPoint,
    destination: LocationPoint,
    route: RouteInfo,
    estimatedCost: Double  // ← NEW
)
```

Update `RideFlowController.calculateRoute()`:

```swift
func calculateRoute(from pickup: LocationPoint, to destination: LocationPoint) async {
    do {
        let result = try await routeService.calculateRoute(from: pickup.coordinate, to: destination.coordinate)

        currentState = .routeReady(
            pickup: pickup,
            destination: destination,
            route: RouteInfo(from: result),
            estimatedCost: result.estimatedCost ?? 0  // ← NEW
        )
    } catch {
        // Handle error
    }
}
```

### Step 4: Display in View

Update the UI to show cost:

```swift
// In RouteInfoView.swift
if case .routeReady(_, _, let route, let cost) = coordinator.flowController.currentState {
    VStack {
        HStack {
            Image(systemName: "clock")
            Text(route.formattedTravelTime)
        }
        HStack {
            Image(systemName: "map")
            Text(route.formattedDistance)
        }
        HStack {
            Image(systemName: "dollarsign.circle")  // ← NEW
            Text(String(format: "$%.2f", cost))     // ← NEW
        }
    }
}
```

### Step 5: Test

1. Run the app
2. Select pickup and destination
3. See estimated cost displayed!

**That's it!** Notice how:
- The service calculates the cost
- The state machine stores it
- The view automatically displays it
- No need to manually update the UI

---

## 12. Common Development Tasks

### Task 1: Changing Map Provider from Apple to Google

**Step 1:** Create Google service implementations:

```swift
// Create new file: GoogleMapServices.swift
import GoogleMaps

class GoogleGeocodingService: GeocodingService {
    private let geocoder = GMSGeocoder()

    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String) {
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(address) { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let location = response?.firstResult()?.geometry.location else {
                    continuation.resume(throwing: RideRequestError.geocodingFailed)
                    return
                }

                let coord = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                continuation.resume(returning: (coord, address))
            }
        }
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String {
        // Similar implementation using GMSGeocoder
    }
}

// Do the same for GoogleRouteCalculationService and GoogleLocationSearchService
```

**Step 2:** Update the factory:

```swift
// In MapServiceFactory.swift
enum MapProvider {
    case apple
    case google
}

class MapServiceFactory {
    static let shared = MapServiceFactory()
    private var provider: MapProvider = .apple  // ← Change this

    func configure(with provider: MapProvider) {
        self.provider = provider
    }

    func createGeocodingService() -> GeocodingService {
        switch provider {
        case .apple:
            return AppleGeocodingService()
        case .google:
            return GoogleGeocodingService()  // ← NEW
        }
    }

    // Do the same for other services
}
```

**Step 3:** Configure on app start:

```swift
// In Model_SApp.swift or ProductionExampleView
init() {
    MapServiceFactory.shared.configure(with: .google)
}
```

**That's it!** The rest of the app doesn't change because it uses protocols.

### Task 2: Adding a Favorite Locations Feature

**Step 1:** Create data model:

```swift
// Core/Models/FavoriteLocation.swift
struct FavoriteLocation: Identifiable, Codable {
    let id: UUID
    let name: String  // "Home", "Work", etc.
    let location: LocationPoint
}
```

**Step 2:** Create storage:

```swift
// Core/Services/Storage/FavoriteLocationsStore.swift
@MainActor
class FavoriteLocationsStore: ObservableObject {
    static let shared = FavoriteLocationsStore()

    @Published var favorites: [FavoriteLocation] = []

    func add(_ location: FavoriteLocation) {
        favorites.append(location)
        save()
    }

    func remove(_ location: FavoriteLocation) {
        favorites.removeAll { $0.id == location.id }
        save()
    }

    private func save() {
        // Save to UserDefaults (same as RideHistoryStore)
    }
}
```

**Step 3:** Add UI in RideLocationCard:

```swift
// Features/RideRequest/Views/RideLocationCardWithSearch.swift
var body: some View {
    VStack {
        // Existing search field

        // Add favorites section
        if !FavoriteLocationsStore.shared.favorites.isEmpty {
            VStack {
                Text("Favorites")
                ForEach(FavoriteLocationsStore.shared.favorites) { fav in
                    Button(action: {
                        coordinator.selectLocation(
                            coordinate: fav.location.coordinate,
                            name: fav.name,
                            isPickup: isPickup
                        )
                    }) {
                        HStack {
                            Image(systemName: "star.fill")
                            Text(fav.name)
                        }
                    }
                }
            }
        }
    }
}
```

**Step 4:** Add "Save as Favorite" button:

```swift
// After selecting a location
Button("Save as Favorite") {
    let favorite = FavoriteLocation(
        id: UUID(),
        name: "Saved Location",
        location: selectedLocation
    )
    FavoriteLocationsStore.shared.add(favorite)
}
```

### Task 3: Fixing a Bug

**Scenario:** User reported that the map doesn't center correctly when both locations are selected.

**Step 1:** Reproduce the bug
- Run app
- Select pickup
- Select destination
- Observe map not showing both points

**Step 2:** Find the relevant code
```bash
# Search for map centering logic
grep -r "updateMapRegion" .
```

**Step 3:** Set breakpoint
- Open `MapViewModel.swift`
- Set breakpoint in `updateMapRegion()`
- Run app and trigger bug

**Step 4:** Debug
```swift
func updateMapRegion() {
    var coordinates: [CLLocationCoordinate2D] = []

    if let pickup = pickupLocation {
        coordinates.append(pickup.coordinate)
        print("DEBUG: Added pickup: \(pickup.coordinate)")  // ← Add logging
    }
    if let destination = destinationLocation {
        coordinates.append(destination.coordinate)
        print("DEBUG: Added destination: \(destination.coordinate)")  // ← Add logging
    }

    print("DEBUG: Total coordinates: \(coordinates.count)")  // ← Add logging

    // ... rest of function
}
```

**Step 5:** Find the issue
- Notice that `updateMapRegion()` is called before `destinationLocation` is set!
- The coordinator sets pickup, calls update, then sets destination

**Step 6:** Fix
```swift
// In RideRequestCoordinator
func selectLocation(...) async {
    // OLD:
    mapViewModel.updatePickupLocation(...)
    mapViewModel.updateMapRegion()  // Too early!
    await flowController.updatePickup(...)

    // NEW:
    mapViewModel.updatePickupLocation(...)
    await flowController.updatePickup(...)
    mapViewModel.updateMapRegion()  // After both locations set
}
```

**Step 7:** Test
- Run app again
- Verify map now shows both points
- Remove debug print statements

---

## 13. Testing Your Changes

### 13.1 Manual Testing Checklist

Before considering a feature complete:

- [ ] Happy path works (normal usage)
- [ ] Error cases handled (no internet, invalid location, etc.)
- [ ] UI updates correctly
- [ ] No crashes or console errors
- [ ] Works on different screen sizes (iPhone SE, iPhone 14 Pro Max)
- [ ] Works in light and dark mode
- [ ] Location permissions handled gracefully

### 13.2 Unit Testing

Example test for RideFlowController:

```swift
// Create test file: RideFlowControllerTests.swift
import XCTest
@testable import Model_S

@MainActor
class RideFlowControllerTests: XCTestCase {
    var controller: RideFlowController!
    var mockRideService: MockRideRequestService!

    override func setUp() {
        super.setUp()
        mockRideService = MockRideRequestService()
        controller = RideFlowController(rideService: mockRideService)
    }

    func testInitialState() {
        XCTAssertEqual(controller.currentState, .idle)
        XCTAssertNil(controller.pickupLocation)
        XCTAssertNil(controller.destinationLocation)
    }

    func testUpdatePickup() {
        let pickup = LocationPoint(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            name: "San Francisco"
        )

        controller.updatePickup(pickup)

        XCTAssertEqual(controller.pickupLocation?.name, "San Francisco")

        if case .selectingLocations(let p, _) = controller.currentState {
            XCTAssertEqual(p?.name, "San Francisco")
        } else {
            XCTFail("Expected selectingLocations state")
        }
    }

    func testCalculateRoute() async {
        let pickup = LocationPoint(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), name: "SF")
        let destination = LocationPoint(coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094), name: "Oakland")

        controller.updatePickup(pickup)
        controller.updateDestination(destination)

        await controller.calculateRoute(from: pickup, to: destination)

        if case .routeReady = controller.currentState {
            // Success
        } else {
            XCTFail("Expected routeReady state")
        }
    }
}
```

**Run tests:**
- Press `⌘U` in Xcode
- Or: Product → Test

### 13.3 UI Testing with Previews

SwiftUI previews are perfect for visual testing:

```swift
#Preview {
    RideRequestView(coordinator: RideRequestCoordinator())
}

#Preview("With Locations Selected") {
    let coordinator = RideRequestCoordinator()
    coordinator.flowController.updatePickup(LocationPoint(coordinate: ..., name: "Pickup"))
    coordinator.flowController.updateDestination(LocationPoint(coordinate: ..., name: "Destination"))
    return RideRequestView(coordinator: coordinator)
}

#Preview("Error State") {
    let coordinator = RideRequestCoordinator()
    coordinator.flowController.currentState = .error(.networkUnavailable, previousState: .idle)
    return RideRequestView(coordinator: coordinator)
}
```

**Use previews to test:**
- Different states
- Error conditions
- Various screen sizes
- Light/dark mode

### 13.4 Mock Services for Testing

Create test doubles:

```swift
class MockGeocodingService: GeocodingService {
    var shouldFail = false
    var delay: TimeInterval = 0

    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String) {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw RideRequestError.geocodingFailed
        }

        // Return predetermined result
        return (CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), address)
    }
}
```

Use in tests:

```swift
func testGeocodingError() async {
    let mockService = MockGeocodingService()
    mockService.shouldFail = true

    let coordinator = RideRequestCoordinator(geocodingService: mockService)

    await coordinator.addressTextChanged("Invalid Address", isPickup: true)

    // Verify error state
    if case .error(.geocodingFailed, _) = coordinator.flowController.currentState {
        // Success - error was handled
    } else {
        XCTFail("Expected error state")
    }
}
```

---

## 14. Best Practices

### 14.1 Code Organization

**DO:**
```swift
// Group related code
class RideFlowController {
    // MARK: - Properties
    @Published private(set) var currentState: RideState

    // MARK: - Public Methods
    func updatePickup(_ location: LocationPoint?) { }

    // MARK: - Private Methods
    private func validateLocations() { }
}
```

**DON'T:**
```swift
// Random order, no organization
class RideFlowController {
    private func validateLocations() { }
    @Published private(set) var currentState: RideState
    func updatePickup(_ location: LocationPoint?) { }
}
```

### 14.2 Naming Conventions

**DO:**
```swift
// Clear, descriptive names
func calculateRouteFromPickupToDestination()
var isSearchingForDriver: Bool
let estimatedArrivalTime: TimeInterval
```

**DON'T:**
```swift
// Vague or abbreviated
func calc()
var searching: Bool
let eta: TimeInterval
```

### 14.3 Error Handling

**DO:**
```swift
// Specific error types
enum RideRequestError: LocalizedError {
    case geocodingFailed
    case routeCalculationFailed

    var errorDescription: String? {
        switch self {
        case .geocodingFailed:
            return "Unable to find that address. Please try again."
        case .routeCalculationFailed:
            return "Couldn't calculate route. Check your connection."
        }
    }
}

// Use do-catch
do {
    let result = try await service.geocode(address: address)
    handleSuccess(result)
} catch let error as RideRequestError {
    handleError(error)
} catch {
    handleError(.unknown(error))
}
```

**DON'T:**
```swift
// Swallow errors
try? service.geocode(address: address)

// Force unwrap
let result = try! service.geocode(address: address)
```

### 14.4 Memory Management

**DO:**
```swift
// Use weak self in closures to prevent retain cycles
geocodingDebouncer.debounce { [weak self] in
    guard let self = self else { return }
    await self.geocodeAddress(address, isPickup: isPickup)
}

// Cancel tasks properly
override func onDisappear() {
    mapViewModel.stopDriverAnimation()
    cancellables.removeAll()
}
```

**DON'T:**
```swift
// Create retain cycle
geocodingDebouncer.debounce {
    await self.geocodeAddress(address, isPickup: isPickup)  // self captured strongly
}
```

### 14.5 State Management

**DO:**
```swift
// Single source of truth
@Published private(set) var currentState: RideState  // Only controller can update

// Computed properties for derived state
var shouldShowConfirmSlider: Bool {
    if case .routeReady = currentState {
        return true
    }
    return false
}
```

**DON'T:**
```swift
// Duplicate state
@Published var currentState: RideState
@Published var isRouteReady: Bool  // Duplicate - can get out of sync!
```

### 14.6 Documentation

**DO:**
```swift
/// Geocodes an address string to coordinates
/// - Parameter address: The address to geocode (e.g., "123 Main St, SF, CA")
/// - Returns: Tuple of (coordinate, formatted address)
/// - Throws: RideRequestError.geocodingFailed if address not found
func geocode(address: String) async throws -> (CLLocationCoordinate2D, String)
```

**DON'T:**
```swift
// No documentation
func geocode(address: String) async throws -> (CLLocationCoordinate2D, String)
```

### 14.7 Async/Await Best Practices

**DO:**
```swift
// Use async/await
func loadData() async {
    do {
        let result = try await service.fetchData()
        await processResult(result)
    } catch {
        handleError(error)
    }
}

// Use Task for calling async from sync
Button("Load") {
    Task {
        await loadData()
    }
}
```

**DON'T:**
```swift
// Old callback style (harder to read)
func loadData(completion: @escaping (Result<Data, Error>) -> Void) {
    service.fetchData { result in
        switch result {
        case .success(let data):
            self.processResult(data) { processedResult in
                completion(.success(processedResult))
            }
        case .failure(let error):
            completion(.failure(error))
        }
    }
}
```

---

## 15. Troubleshooting

### Common Issues and Solutions

#### Issue 1: "Cannot find 'coordinator' in scope"

**Cause:** Forgot to pass coordinator to view

**Fix:**
```swift
// DON'T:
var body: some View {
    RideRequestView()  // ← No coordinator!
}

// DO:
@StateObject private var coordinator = RideRequestCoordinator()

var body: some View {
    RideRequestView(coordinator: coordinator)
}
```

#### Issue 2: Map not updating when locations change

**Cause:** Forgot to call `updateMapRegion()` after changing locations

**Fix:**
```swift
func updatePickupLocation(_ coordinate: CLLocationCoordinate2D, name: String?) {
    pickupLocation = LocationPoint(coordinate: coordinate, name: name)
    updateMapRegion()  // ← Don't forget this!
}
```

#### Issue 3: "Publishing changes from background threads is not allowed"

**Cause:** Updating `@Published` property from background thread

**Fix:**
```swift
// DON'T:
func updateLocation() {
    DispatchQueue.global().async {
        self.location = newLocation  // ← Crash!
    }
}

// DO:
func updateLocation() {
    Task { @MainActor in
        self.location = newLocation  // ← On main thread
    }
}

// OR mark class with @MainActor:
@MainActor
class MapViewModel: ObservableObject {
    // All methods run on main thread automatically
}
```

#### Issue 4: State machine won't transition

**Cause:** Invalid transition according to `RideStateMachine`

**Debug:**
```swift
let stateMachine = RideStateMachine()
let canTransition = stateMachine.canTransition(from: currentState, to: nextState)
print("Can transition from \(currentState) to \(nextState): \(canTransition)")
```

**Fix:** Check `RideStateMachine.validNextStates()` to see allowed transitions

#### Issue 5: Geocoding not working

**Possible causes:**
1. No internet connection
2. Invalid address format
3. Rate limiting from Apple

**Debug:**
```swift
do {
    let result = try await geocodingService.geocode(address: "123 Main St")
    print("Geocoded: \(result)")
} catch {
    print("Geocoding failed: \(error)")  // See what error you get
}
```

#### Issue 6: Memory leak / app slowing down

**Cause:** Retain cycle or not canceling timers

**Fix:**
```swift
// Check for retain cycles
deinit {
    print("MapViewModel deallocated")  // Should print when view closes
}

// Always use [weak self]
timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
    self?.updateLocation()
}

// Cancel timers
override func onDisappear() {
    timer?.invalidate()
    timer = nil
}
```

---

## 16. Resources for Learning

### Apple Documentation

**Swift Language:**
- [The Swift Programming Language](https://docs.swift.org/swift-book/)
- [Swift by Sundell](https://www.swiftbysundell.com/) - Great blog

**SwiftUI:**
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Hacking with Swift SwiftUI](https://www.hackingwithswift.com/quick-start/swiftui)

**Combine:**
- [Combine Framework](https://developer.apple.com/documentation/combine)
- [Using Combine](https://heckj.github.io/swiftui-notes/)

**MapKit:**
- [MapKit Documentation](https://developer.apple.com/documentation/mapkit)
- [Location and Maps Programming Guide](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/LocationAwarenessPG/Introduction/Introduction.html)

**Async/Await:**
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Meet async/await in Swift](https://developer.apple.com/videos/play/wwdc2021/10132/)

### Architecture Patterns

**MVVM:**
- [MVVM in SwiftUI](https://www.hackingwithswift.com/books/ios-swiftui/introducing-mvvm-into-your-swiftui-project)
- [SwiftUI Architecture](https://www.swiftbysundell.com/articles/swiftui-architecture/)

**Coordinator Pattern:**
- [Coordinators in SwiftUI](https://www.hackingwithswift.com/articles/216/complete-guide-to-navigation-in-swiftui)

**State Machines:**
- [Enums as State Machines](https://www.swiftbysundell.com/articles/using-state-machines-in-swift/)

### Design Patterns

**Dependency Injection:**
- [Dependency Injection in Swift](https://www.swiftbysundell.com/articles/dependency-injection-using-factories-in-swift/)

**Protocol-Oriented Programming:**
- [Protocol-Oriented Programming in Swift](https://developer.apple.com/videos/play/wwdc2015/408/)

### Courses

- [Stanford CS193p - SwiftUI](https://cs193p.sites.stanford.edu/)
- [100 Days of SwiftUI](https://www.hackingwithswift.com/100/swiftui)

### Community

- [Swift Forums](https://forums.swift.org/)
- [r/swift](https://www.reddit.com/r/swift/)
- [r/iOSProgramming](https://www.reddit.com/r/iOSProgramming/)
- [Stack Overflow - SwiftUI tag](https://stackoverflow.com/questions/tagged/swiftui)

---

## Quick Reference

### File Structure Cheat Sheet

```
Need to modify...                    Look in...
─────────────────────────────────────────────────────────────
App entry point                       App/Model_SApp.swift
Home screen                           Features/Home/HomeView.swift
Ride request orchestration            Features/RideRequest/Coordinators/RideRequestCoordinator.swift
State machine logic                   Features/RideRequest/Controllers/RideFlowController.swift
State definitions                     Features/RideRequest/Models/RideState.swift
State transition rules                Features/RideRequest/Models/RideStateMachine.swift
Map display logic                     Features/RideRequest/ViewModels/MapViewModel.swift
Main ride UI                          Features/RideRequest/Views/RideRequestView.swift
Map wrapper (Apple)                   Features/RideRequest/Views/MapViewWrapper.swift
Map wrapper (Google)                  Features/RideRequest/Views/GoogleMapViewWrapper.swift
Map provider switcher                 Features/RideRequest/Views/MapProviderSwitcher.swift
Location input UI                     Features/RideRequest/Views/RideLocationCardWithSearch.swift
Confirm slider                        Features/RideRequest/Views/RideConfirmSlider.swift
Error display                         Features/RideRequest/Views/ErrorBannerView.swift

MAP SERVICES (NEW REFACTORED ARCHITECTURE):
Unified map service protocol          Core/Services/Map/MapService.swift
Map provider state management         Core/Services/Map/MapProviderService.swift
Apple Maps unified service            Core/Services/Map/AppleMapService.swift
Google Maps unified service           Core/Services/Map/GoogleMapService.swift

MAP SERVICES (LEGACY - STILL USED INTERNALLY):
Old service protocols                 Core/Services/Map/MapServiceProtocols.swift
Apple Maps implementations            Core/Services/Map/AppleMapServices.swift
Google Maps implementations           Core/Services/Map/GoogleMapServices.swift

OTHER SERVICES:
Ride backend service                  Core/Services/RideRequest/RideRequestService.swift
Ride history storage                  Core/Services/Storage/RideHistoryStore.swift
Data models                           Core/Models/
Constants & config                    Core/Utilities/Constants.swift
Error types                           Core/Utilities/RideRequestError.swift
```

### Common Code Snippets

**Observe state changes:**
```swift
@ObservedObject var coordinator: RideRequestCoordinator

var body: some View {
    switch coordinator.flowController.currentState {
    case .idle:
        Text("Ready to ride")
    case .selectingLocations:
        Text("Select locations")
    case .routeReady:
        Text("Route ready")
    // ... etc
    }
}
```

**Call async function from button:**
```swift
Button("Do Something") {
    Task {
        await coordinator.startRideRequest()
    }
}
```

**Add new @Published property:**
```swift
@MainActor
class MyViewModel: ObservableObject {
    @Published var myProperty: String = ""
}
```

**Create and use map service (modern way):**
```swift
// Get current map service (works with any provider!)
let mapService = MapProviderService.shared.currentService

// Use it for any operation
mapService.search(query: "Coffee")
let (coord, name) = try await mapService.geocode(address: "123 Main St")
let route = try await mapService.calculateRoute(from: pickup, to: destination)
```

**Switch map providers:**
```swift
// Switch to Google Maps
MapProviderService.shared.useGoogleMaps()

// Switch to Apple Maps
MapProviderService.shared.useAppleMaps()

// Toggle between providers
MapProviderService.shared.toggleProvider()
```

---

## Conclusion

You now have a comprehensive understanding of the Model S codebase! Here's what we covered:

1. **What the app does** - iOS ride-sharing app with mock backend
2. **Architecture** - MVVM + Coordinator + State Machine
3. **State management** - Single source of truth with Combine
4. **Key components** - Coordinator, FlowController, ViewModels
5. **Services** - Protocol-based abstraction for maps and rides
6. **Map features** - Pins, routes, driver animation
7. **Persistence** - UserDefaults for ride history
8. **Adding features** - Step-by-step process
9. **Common tasks** - Practical examples
10. **Testing** - Unit tests, previews, mocks
11. **Best practices** - Code quality guidelines
12. **Troubleshooting** - Common issues and fixes
13. **Resources** - Where to learn more

### Next Steps

1. **Explore the code** - Open the project and navigate through the files
2. **Run the app** - See it in action
3. **Make a small change** - Try adding the estimated cost feature
4. **Read the existing docs** - Check `ARCHITECTURE.md` and related files
5. **Experiment** - Break things and fix them (best way to learn!)

### Remember

- The state machine prevents bugs
- Services abstract implementation details
- ViewModels manage state, Coordinators manage logic
- Views are dumb - they just display data
- Use protocols for flexibility
- Test your changes
- Ask questions when stuck!

Happy coding! 🚀
