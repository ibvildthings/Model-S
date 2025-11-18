# Phase 1 Implementation Guide

> Foundation architecture implementation for scalable iOS rideshare app

## What We've Built

Phase 1 establishes the **foundational architecture** for the production rideshare app, implementing:

1. ✅ **Global AppStateStore** - Single source of truth for app-wide state
2. ✅ **DependencyContainer** - Centralized service injection and lifecycle management
3. ✅ **AppCoordinator** - Root navigation coordinator with child coordinator support
4. ✅ **Service Protocols** - Unified interfaces for all shared services
5. ✅ **Integration** - Connected RideFlowController with global state

---

## 1. Global AppStateStore

**Location:** `Core/State/AppStateStore.swift`

### Purpose

Single source of truth for all app-wide state using a Redux-like pattern.

### Key Features

- **Centralized State**: User, location, ride, configuration all in one place
- **Action-Based Mutations**: All state changes go through explicit actions
- **Observable**: SwiftUI views can observe any part of the state
- **Persistence**: Automatically saves/loads user preferences

### State Categories

```swift
// User State
@Published private(set) var currentUser: User?
@Published private(set) var isAuthenticated: Bool

// Location State
@Published private(set) var currentLocation: CLLocationCoordinate2D?
@Published private(set) var locationAuthorized: Bool

// Ride State
@Published private(set) var currentRideState: RideState

// Configuration
@Published private(set) var mapProvider: MapProvider
@Published private(set) var isDriverMode: Bool

// Network State
@Published private(set) var isNetworkAvailable: Bool
```

### Usage Example

```swift
// Access global state
let stateStore = AppStateStore.shared

// Observe state changes
@ObservedObject var stateStore: AppStateStore

// Dispatch actions to modify state
stateStore.dispatch(.setUser(user))
stateStore.dispatch(.updateRideState(.driverEnRoute(...)))
stateStore.dispatch(.setMapProvider(.google))
stateStore.dispatch(.updateLocation(coordinate))
```

### Available Actions

```swift
enum AppAction {
    // User actions
    case setUser(User?)
    case logout

    // Location actions
    case updateLocation(CLLocationCoordinate2D?)
    case setLocationAuthorization(Bool)

    // Ride actions
    case updateRideState(RideState)

    // Configuration actions
    case setMapProvider(MapProvider)
    case setDriverMode(Bool)

    // Network actions
    case setNetworkAvailability(Bool)
}
```

### Convenience Properties

```swift
// Check if user has active ride
if stateStore.hasActiveRide { ... }

// Get current ride ID
if let rideId = stateStore.currentRideId { ... }

// Get current driver
if let driver = stateStore.currentDriver { ... }
```

---

## 2. DependencyContainer

**Location:** `Core/DI/DependencyContainer.swift`

### Purpose

Centralized container for creating and managing all app dependencies (services).

### Key Features

- **Service Locator Pattern**: One place to get any service
- **Lazy Initialization**: Services created only when needed
- **Configuration**: Easy to switch between mock/production services
- **Testing Support**: Easy to inject mock services for tests

### Available Services

```swift
let dependencies = DependencyContainer.shared

// Core Services
dependencies.stateStore          // AppStateStore
dependencies.locationService     // LocationService
dependencies.mapService          // AnyMapService (uses MapProviderService)
dependencies.rideRequestService  // RideRequestService (Mock/Real)

// Utility Services
dependencies.notificationService // NotificationService
dependencies.analyticsService    // AnalyticsService
dependencies.loggingService      // LoggingService
```

### Service Protocols

#### LocationService

```swift
protocol LocationService {
    var currentLocation: CLLocationCoordinate2D? { get }
    var isAuthorized: Bool { get }

    func requestAuthorization() async -> Bool
    func startTracking()
    func stopTracking()
    func getCurrentLocation() async throws -> CLLocationCoordinate2D
}
```

**Implementation:** `CoreLocationService` (wraps CLLocationManager)

#### NotificationService

```swift
protocol NotificationService {
    func showNotification(title: String, body: String)
    func requestAuthorization() async -> Bool
}
```

**Implementation:** `LocalNotificationService` (console-based for now)

#### AnalyticsService

```swift
protocol AnalyticsService {
    func track(event: String, properties: [String: Any]?)
    func identify(userId: String, traits: [String: Any]?)
}
```

**Implementation:** `ConsoleAnalyticsService` (console-based for development)

#### LoggingService

```swift
protocol LoggingService {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String, error: Error?)
}
```

**Implementation:** `ConsoleLoggingService` (console-based for development)

### Configuration

```swift
// Use production services
let container = DependencyContainer.shared

// Use mock services for testing
let mockContainer = DependencyContainer.mock(
    useMockRideService: true,
    useMockLocation: true
)
```

### Service Configuration

```swift
// Ride service configuration
struct RideServiceConfiguration {
    let useMock: Bool
    let baseURL: String

    static let production = RideServiceConfiguration(
        useMock: false,
        baseURL: "http://localhost:3000"
    )

    static let mock = RideServiceConfiguration(
        useMock: true,
        baseURL: ""
    )
}
```

---

## 3. AppCoordinator

**Location:** `Core/Coordination/AppCoordinator.swift`

### Purpose

Root coordinator that manages app-level navigation and child coordinators.

### Key Features

- **Coordinator Pattern**: Separates navigation from business logic
- **State-Driven Navigation**: Observes app state and navigates accordingly
- **Child Coordinators**: Delegates to feature-specific coordinators
- **SwiftUI Integration**: Provides `CoordinatedAppView` for easy integration

### Coordinator Hierarchy

```
AppCoordinator (Root)
├── AuthCoordinator (Authentication flow)
└── MainCoordinator (Main app)
    ├── RiderCoordinator (Rider features)
    └── DriverCoordinator (Driver features)
```

### State-Driven Navigation

```swift
// Observes authentication state
stateStore.$isAuthenticated
    .sink { isAuthenticated in
        if isAuthenticated {
            showMainApp()
        } else {
            showAuth()
        }
    }

// Observes ride state for analytics/notifications
stateStore.$currentRideState
    .sink { rideState in
        handleRideStateChange(rideState)
    }
```

### Usage

```swift
// In Model_SApp.swift
@main
struct Model_SApp: App {
    var body: some Scene {
        WindowGroup {
            CoordinatedAppView()  // Uses AppCoordinator
        }
    }
}
```

### Child Coordinators

#### AuthCoordinator

Handles authentication flow (login, signup, password reset).

```swift
class AuthCoordinator: Coordinator {
    func start() {
        // Show login screen
        // For now: auto-login with mock user
    }

    func stop() {
        // Cleanup
    }
}
```

#### MainCoordinator

Handles main app flow, observes driver mode and ride state.

```swift
class MainCoordinator: Coordinator {
    func start() {
        // Observe driver mode
        // Observe ride state
        // Send analytics events
        // Show notifications
    }
}
```

---

## 4. Integration with RideFlowController

**Location:** `Features/RideRequest/Controllers/RideFlowController.swift`

### What Changed

Added optional `stateStore` parameter to sync ride state with global app state.

### Before

```swift
class RideFlowController: ObservableObject {
    @Published private(set) var currentState: RideState = .idle

    private func transition(to newState: RideState) {
        currentState = stateMachine.transition(from: currentState, to: newState)
    }
}
```

### After

```swift
class RideFlowController: ObservableObject {
    @Published private(set) var currentState: RideState = .idle
    private let stateStore: AppStateStore?  // NEW

    init(stateStore: AppStateStore? = nil) {  // NEW
        self.stateStore = stateStore
    }

    private func transition(to newState: RideState) {
        currentState = stateMachine.transition(from: currentState, to: newState)

        // Sync with global state  // NEW
        stateStore?.dispatch(.updateRideState(currentState))
    }
}
```

### Usage

```swift
// Without global state (backward compatible)
let controller = RideFlowController()

// With global state (recommended)
let controller = RideFlowController(
    stateStore: AppStateStore.shared
)
```

---

## How to Use Phase 1

### 1. Access Global State Anywhere

```swift
import SwiftUI

struct MyView: View {
    @ObservedObject var stateStore = AppStateStore.shared

    var body: some View {
        if stateStore.isAuthenticated {
            Text("Welcome, \(stateStore.currentUser?.name ?? "User")")
        }

        if stateStore.hasActiveRide {
            Text("Ride in progress: \(stateStore.currentRideId ?? "")")
        }
    }
}
```

### 2. Inject Dependencies

```swift
import SwiftUI

struct MyFeatureView: View {
    let dependencies = DependencyContainer.shared

    var body: some View {
        VStack {
            // Use services
            Button("Track Event") {
                dependencies.analyticsService.track(
                    event: "button_tapped",
                    properties: ["button": "my_button"]
                )
            }

            Button("Show Notification") {
                dependencies.notificationService.showNotification(
                    title: "Test",
                    body: "This is a test notification"
                )
            }
        }
    }
}
```

### 3. Create Feature Coordinators

```swift
// Create a coordinator for your feature
@MainActor
class MyFeatureCoordinator: Coordinator {
    private let stateStore: AppStateStore
    private let dependencies: DependencyContainer

    init(stateStore: AppStateStore, dependencies: DependencyContainer) {
        self.stateStore = stateStore
        self.dependencies = dependencies
    }

    func start() {
        // Show feature screens
        // Observe state changes
        // Handle navigation
    }

    func stop() {
        // Cleanup
    }
}
```

### 4. Dispatch Actions to Change State

```swift
// Modify state through actions
let stateStore = AppStateStore.shared

// User actions
stateStore.dispatch(.setUser(mockUser))
stateStore.dispatch(.logout)

// Location actions
stateStore.dispatch(.updateLocation(coordinate))
stateStore.dispatch(.setLocationAuthorization(true))

// Ride actions
stateStore.dispatch(.updateRideState(.driverEnRoute(...)))

// Configuration
stateStore.dispatch(.setMapProvider(.google))
stateStore.dispatch(.setDriverMode(true))
```

---

## Testing with Phase 1

### Test with Mock Services

```swift
class MyFeatureTests: XCTestCase {
    func testMyFeature() async {
        // Create mock dependencies
        let mockContainer = DependencyContainer.mock(
            useMockRideService: true,
            useMockLocation: true
        )

        // Create test state
        let testStore = AppStateStore()
        testStore.dispatch(.setUser(mockUser))

        // Test your feature
        let controller = RideFlowController(
            rideService: mockContainer.rideRequestService,
            mapService: mockContainer.mapService,
            stateStore: testStore
        )

        await controller.requestRide()

        XCTAssertTrue(controller.isActiveRide)
    }
}
```

---

## What's Next: Phase 2-4

### Phase 2: Feature Extraction (Week 3-4)

- Extract Authentication module with protocols
- Extract Map module with clean boundaries
- Extract Ride Request module interface
- Define public APIs for each module

### Phase 3: Coordinators (Week 5-6)

- Implement RiderCoordinator for rider features
- Implement DriverCoordinator for driver features
- Migrate all navigation logic out of views
- Complete coordinator hierarchy

### Phase 4: Testing & Refinement (Week 7-8)

- Write unit tests for state machine
- Write integration tests for features
- Performance optimization
- Documentation updates

---

## Key Benefits of Phase 1

✅ **Single Source of Truth** - AppStateStore eliminates state synchronization issues

✅ **Clean Dependencies** - DependencyContainer makes service management easy

✅ **Testable** - Mock services and state for easy testing

✅ **Scalable** - Foundation ready for feature modules

✅ **Maintainable** - Clear boundaries and responsibilities

✅ **Observable** - SwiftUI views automatically update with state changes

✅ **Type-Safe** - Compiler enforces correct usage

---

## Files Created

```
Model S/
├── Core/
│   ├── State/
│   │   └── AppStateStore.swift           ✨ NEW
│   ├── DI/
│   │   └── DependencyContainer.swift     ✨ NEW
│   └── Coordination/
│       └── AppCoordinator.swift          ✨ NEW
│
└── Features/
    └── RideRequest/
        └── Controllers/
            └── RideFlowController.swift  ✏️ UPDATED
```

---

## Migration Guide

### For Existing Views

**Before:**
```swift
struct MyView: View {
    @StateObject private var controller = RideFlowController()
}
```

**After (Recommended):**
```swift
struct MyView: View {
    @StateObject private var controller = RideFlowController(
        stateStore: AppStateStore.shared
    )
    @ObservedObject var stateStore = AppStateStore.shared
}
```

### For Services

**Before:**
```swift
let mapService = MapServiceFactory.shared.createRouteCalculationService()
let rideService = RideRequestServiceFactory.shared.createRideRequestService()
```

**After:**
```swift
let dependencies = DependencyContainer.shared
let mapService = dependencies.mapService
let rideService = dependencies.rideRequestService
```

---

## Summary

Phase 1 establishes the **architectural foundation** for a production-ready rideshare app:

- **AppStateStore**: Redux-like global state management
- **DependencyContainer**: Centralized service injection
- **AppCoordinator**: State-driven navigation hierarchy
- **Service Protocols**: Clean boundaries for testing

This foundation enables independent feature modules, predictable state flow, and easy testing - essential for scaling a complex rideshare application.

**Next:** Phase 2 will extract feature modules with protocol boundaries! 🚀
