# Model S - Project Structure

A clean, modular architecture for a ride-sharing iOS app built with SwiftUI.

## 📁 Architecture Overview

```
Model S/
├── App/                          # Application entry point
├── Core/                         # Shared core functionality
│   ├── Models/                  # Data models
│   ├── Services/                # Business logic services
│   ├── Extensions/              # Swift extensions
│   └── Utilities/               # Helper utilities
├── Features/                     # Feature modules
│   ├── Home/                    # Home screen
│   ├── RideRequest/             # Ride request feature
│   └── RideHistory/             # Ride history feature
└── ContentView.swift            # Root view
```

## 🏗️ Detailed Structure

### App/
Entry point and app configuration.
- `Model_SApp.swift` - App lifecycle and root scene

### Core/

#### Models/
Domain models and data structures.
- `Models.swift` - Core models (LocationPoint, RideRequestState)
- `RideHistory.swift` - Ride history model
- `RideRequestConfiguration.swift` - Configuration for ride requests

#### Services/
Business logic and external service integrations.

**Map/** - Map and location services
- `MapServiceProtocols.swift` - Service protocols (geocoding, routing, search)
- `AppleMapServices.swift` - Apple Maps implementation

**RideRequest/** - Ride request services
- `RideRequestService.swift` - Ride request protocol and mock implementation

**Storage/** - Data persistence
- `RideHistoryStore.swift` - Persistent storage for ride history

#### Extensions/
Swift type extensions.
- `CLLocationCoordinate2D+Equatable.swift` - Equatable conformance for coordinates

#### Utilities/
Helper classes and constants.
- `Constants.swift` - App-wide constants
- `Debounce.swift` - Debouncing utility
- `RideRequestError.swift` - Error types for ride requests

### Features/

#### Home/
Home screen feature.
- `HomeView.swift` - Main home screen with navigation

#### RideRequest/
Complete ride request feature with MVVM + Coordinator pattern.

**Coordinators/**
- `RideRequestCoordinator.swift` - Orchestrates ViewModels and services

**ViewModels/**
- `RideRequestViewModel.swift` - Ride request business logic
- `MapViewModel.swift` - Map presentation logic

**Views/**
- `ProductionExampleView.swift` - Production-ready ride request integration
- `RideRequestView.swift` - Basic ride request view
- `RideMapView.swift` - Map view component
- `RideLocationCard.swift` - Location input card (basic)
- `RideLocationCardWithSearch.swift` - Location card with autocomplete
- `RideConfirmSlider.swift` - Slide-to-confirm component
- `RouteInfoView.swift` - Route information display
- `ErrorBannerView.swift` - Error message banner
- `LocationSearchSuggestionsView.swift` - Search suggestions list

#### RideHistory/
Ride history feature.
- `RideHistoryView.swift` - List of past rides

## 🎯 Architecture Pattern: MVVM + Coordinator

### Why This Pattern?

**MVVM (Model-View-ViewModel)**
- Clear separation of concerns
- Testable business logic
- Reactive UI updates with Combine

**Coordinator**
- Orchestrates complex flows
- Manages multiple ViewModels
- Handles navigation and dependencies

### Data Flow

```
User Action → View → Coordinator → ViewModel → Service → ViewModel → View
```

Example: Requesting a ride
1. User slides to confirm (View)
2. View calls `coordinator.confirmRide()` (Coordinator)
3. Coordinator validates and starts `viewModel.requestRide()` (ViewModel)
4. ViewModel calls `rideRequestService.requestRide()` (Service)
5. Service updates trigger ViewModel @Published properties
6. SwiftUI automatically updates the View

## 🔄 Ride Request Flow

### States
1. **Selecting Pickup** - User enters pickup location
2. **Selecting Destination** - User enters destination
3. **Route Ready** - Route calculated, ready to request
4. **Ride Requested** - Initial request submitted
5. **Searching for Driver** - Looking for available driver (~3 sec)
6. **Driver Found** - Driver assigned, showing details (~2 sec)
7. **Driver En Route** - Driver heading to pickup

### Mock vs Real API

The app uses a mock service by default:
```swift
// In RideRequestViewModel.swift
self.rideRequestService = RideRequestServiceFactory.shared
    .createRideRequestService(useMock: true)
```

To integrate real API:
1. Create a class implementing `RideRequestService` protocol
2. Update factory to return your implementation
3. No other code changes needed!

## 🧪 Testing Strategy

### Unit Tests
- Test ViewModels in isolation
- Mock service layer
- Test state transitions

### Integration Tests
- Test Coordinator orchestration
- Test service integrations
- Test error handling

### UI Tests
- Test complete user flows
- Test accessibility
- Test edge cases

## 📱 Key Features

✅ **Location Services**
- Geocoding and reverse geocoding
- Location search with autocomplete
- Route calculation

✅ **Ride Request**
- Multi-step ride request flow
- Driver assignment simulation
- Real-time status updates

✅ **Ride History**
- Persistent storage of past rides
- View ride details (distance, time, locations)

✅ **Error Handling**
- User-friendly error messages
- Recovery suggestions
- Graceful degradation

## 🔧 Configuration

Customize ride request behavior:
```swift
var config = RideRequestConfiguration.default
config.enableGeocoding = true
config.enableRouteCalculation = true
config.showRouteInfo = true
```

## 🚀 Adding New Features

### 1. Create Feature Folder
```
Features/
└── YourFeature/
    ├── ViewModels/
    ├── Views/
    └── Models/ (if needed)
```

### 2. Follow MVVM Pattern
- Create ViewModel for business logic
- Create Views for UI
- Use Coordinator if complex navigation needed

### 3. Add Services to Core/
If your feature needs services:
```
Core/Services/YourFeature/
└── YourFeatureService.swift
```

## 📚 Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Combine Framework](https://developer.apple.com/documentation/combine)
- [MapKit](https://developer.apple.com/documentation/mapkit)

---

**Architecture Date:** November 2025
**Pattern:** MVVM + Coordinator
**Language:** Swift 5.x
**Framework:** SwiftUI
