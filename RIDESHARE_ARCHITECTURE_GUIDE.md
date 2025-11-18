# Production Rideshare iOS App Architecture Guide

> A comprehensive blueprint for building a scalable, maintainable iOS rideshare application (driver or rider side) that can grow without breaking.

## Table of Contents

1. [The Core Idea](#the-core-idea)
2. [Recommended Architecture](#recommended-architecture)
3. [State Machine for Ride Stages](#state-machine-for-ride-stages)
4. [Global State Store](#global-state-store)
5. [Coordinator Pattern](#coordinator-pattern)
6. [Feature Module Boundaries](#feature-module-boundaries)
7. [Service Layer](#service-layer)
8. [Full Architecture Diagram](#full-architecture-diagram)
9. [Isolation Techniques](#isolation-techniques)
10. [Problems This Solves](#problems-this-solves)

---

## The Core Idea

You want your app divided into **independent feature modules** that:

1. ✅ **Own their UI + logic + networking internally**
2. ✅ **Communicate with the rest of the app only through very small interfaces**
3. ✅ **Don't know about each other**
4. ✅ **Share global state only in a controlled, observable way**

**This is how you keep features from breaking each other.**

---

## Recommended Architecture

### 1. Global App Layer

The glue that connects feature modules together:

- **AppCoordinator** (or RootCoordinator) - Root navigation controller
- **DependencyContainer** / ServiceLocator - Centralized dependency injection
- **Global AppState** (or StateStore) - Single source of truth for app-wide state

### 2. Feature Modules (Independent Units)

Each major feature becomes its own "mini-app".

#### Examples of Feature Modules

For a driver/rider rideshare app:

| Module | Responsibility |
|--------|---------------|
| **Authentication** | Login, signup, session management |
| **Profile Management** | User profile, settings, preferences |
| **Map / Location** | Map display, location tracking, permissions |
| **Ride Request Flow** | Pickup/destination selection, fare estimation |
| **Ride Matching Flow** | Driver search, matching logic |
| **Trip Flow** | Active ride, navigation, trip progress |
| **Chat** | In-app messaging with driver/rider |
| **Payments** | Payment methods, billing, receipts |
| **Settings** | App configuration, preferences |
| **History** | Past rides, receipts, ratings |

#### Each Module Includes:

```
FeatureModule/
├── Views/              # SwiftUI views (presentation only)
├── ViewModels/         # Feature-specific state and logic
├── Coordinator/        # Navigation within feature (optional)
├── Services/           # Feature-specific networking, storage
├── Models/             # Data models for the feature
└── FeatureInterface.swift  # Public protocol boundary
```

---

## State Machine for Ride Stages

### ❌ Problem: Manual Stage Management

You are currently doing "stages" manually. That becomes buggy as the app grows:

```swift
// ❌ Brittle, error-prone
var currentStage = "requesting"
var isDriverAssigned = false
var isRideActive = false
// What if isDriverAssigned is true but currentStage is "requesting"?
```

### ✅ Solution: State Machine

Implement a **state machine** that controls transitions.

#### Example RideState

```swift
enum RideState: Equatable {
    case idle
    case requesting(pickup: LocationPoint, destination: LocationPoint)
    case matching(requestId: String)
    case driverArriving(rideId: String, driver: DriverInfo, eta: TimeInterval)
    case inRide(rideId: String, driver: DriverInfo, route: RouteInfo)
    case completed(rideId: String, receipt: Receipt)
    case cancelled(reason: CancellationReason)
}
```

#### State Machine Protocol

```swift
protocol TripStateMachine {
    var currentState: RideState { get }
    func transition(to newState: RideState) -> Bool
    func send(_ event: RideEvent)
}

enum RideEvent {
    case requestRide(pickup: LocationPoint, destination: LocationPoint)
    case driverMatched(driver: DriverInfo)
    case driverArrived
    case tripStarted
    case tripCompleted
    case cancelled
}
```

#### Benefits

- ✅ **Deterministic** - All transitions are validated
- ✅ **Type-safe** - Compiler enforces valid states
- ✅ **Testable** - Easy to unit test state transitions
- ✅ **Clear** - Each state carries only relevant data

**Now each UI module only observes the state; it does NOT drive the state.**

---

## Global State Store

### Use a Global Store (Redux-like, or ObservableObject)

Think:
- **Combine** framework with `@Published` properties
- **Swift Concurrency** with `actor` for thread safety
- **SwiftData/CoreData** for persistence
- Or a Redux library (ReSwift, Composable Architecture)

### Example Global State Store

```swift
@MainActor
class AppStateStore: ObservableObject {
    // Ride state
    @Published private(set) var rideState: RideState = .idle

    // User state
    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated: Bool = false

    // Location state
    @Published private(set) var currentLocation: LocationPoint?

    // Actions
    func dispatch(_ action: AppAction) {
        switch action {
        case .updateRideState(let newState):
            rideState = newState
        case .updateUser(let user):
            currentUser = user
            isAuthenticated = true
        case .updateLocation(let location):
            currentLocation = location
        // ... more actions
        }
    }
}

enum AppAction {
    case updateRideState(RideState)
    case updateUser(User)
    case updateLocation(LocationPoint)
    // ... more actions
}
```

### Benefits

- ✅ **Single source of truth** - No conflicting state
- ✅ **Observable** - Features subscribe to changes
- ✅ **Predictable** - Actions are the only way to mutate state
- ✅ **Debuggable** - Can log all state changes

**This prevents random UI hiding bugs or unexpected stage transitions.**

---

## Coordinator Pattern

### Coordinators Only Handle Navigation

Let your Coordinators do exactly **ONE** thing:

✅ **Start screen**
✅ **Navigate to next screen**

❌ **DO NOT manage state**
❌ **DO NOT own business logic**
❌ **DO NOT fetch network data**

This keeps them small.

### Example: RideCoordinator

```swift
@MainActor
class RideCoordinator: Coordinator {
    private let stateStore: AppStateStore
    private let navigationController: UINavigationController
    private var cancellables = Set<AnyCancellable>()

    init(stateStore: AppStateStore, navigationController: UINavigationController) {
        self.stateStore = stateStore
        self.navigationController = navigationController
    }

    func start() {
        showRideRequestScreen()
        observeStateChanges()
    }

    private func observeStateChanges() {
        stateStore.$rideState
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
    }

    private func handleStateChange(_ state: RideState) {
        switch state {
        case .idle:
            showRideRequestScreen()
        case .requesting:
            showLoadingScreen()
        case .matching:
            showMatchingScreen()
        case .driverArriving:
            showDriverArrivingScreen()
        case .inRide:
            showTripScreen()
        case .completed:
            showReceiptScreen()
        case .cancelled:
            showCancellationScreen()
        }
    }

    private func showRideRequestScreen() {
        let viewModel = RideRequestViewModel(stateStore: stateStore)
        let view = RideRequestView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        navigationController.pushViewController(hostingController, animated: true)
    }

    // ... more navigation methods
}
```

**State drives UI, not the other way.**

---

## Feature Module Boundaries

### Feature Modules Should Talk via Protocol Boundaries

Example for the Ride Request feature:

#### RideRequestFeatureInterface.swift

```swift
/// Public interface for the Ride Request feature
protocol RideRequestFeature {
    /// Start the ride request flow
    func startRequestFlow()

    /// Observable events from the feature
    var events: AnyPublisher<RideRequestEvent, Never> { get }
}

enum RideRequestEvent {
    case rideRequested(pickup: LocationPoint, destination: LocationPoint)
    case requestCancelled
    case requestFailed(Error)
}
```

#### Benefits

The rest of the app does not know:
- ❌ How UI is implemented
- ❌ How network calls work
- ❌ How validation works

**Each module is replaceable.**

This is how you make things independent.

---

## Service Layer

### Build a Service Layer (Shared Dependencies)

These are **shared services** that multiple features depend on:

| Service | Responsibility |
|---------|---------------|
| **LocationService** | GPS tracking, location permissions |
| **DriverService** | Driver data, availability |
| **RiderService** | Rider profile, preferences |
| **TripService** | Ride lifecycle management |
| **PaymentService** | Payment processing, billing |
| **SocketService** | Real-time updates (driver location, ETA) |
| **NotificationService** | Push notifications |
| **LoggingService** | Analytics, error tracking |

### Example Service Protocol

```swift
protocol LocationService {
    var currentLocation: AnyPublisher<LocationPoint, Never> { get }
    func requestLocationPermission() async -> Bool
    func startTracking()
    func stopTracking()
}

protocol TripService {
    func requestRide(pickup: LocationPoint, destination: LocationPoint) async throws -> RideRequest
    func cancelRide(rideId: String) async throws
    func getRideStatus(rideId: String) async throws -> RideStatus
    func observeRideUpdates(rideId: String) -> AnyPublisher<RideUpdate, Error>
}
```

### Dependency Injection

Services are injected into each feature module, typically at the **Coordinator** level or via a **Dependency Container**.

```swift
class DependencyContainer {
    let locationService: LocationService
    let tripService: TripService
    let paymentService: PaymentService
    let socketService: SocketService

    init() {
        self.locationService = ProductionLocationService()
        self.tripService = ProductionTripService()
        self.paymentService = ProductionPaymentService()
        self.socketService = ProductionSocketService()
    }

    // Factory methods for testing
    static func mock() -> DependencyContainer {
        let container = DependencyContainer()
        // Inject mock services
        return container
    }
}
```

---

## Full Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         App Layer                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ AppCoordinator (Root Navigation)                     │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Global StateStore (TripState, UserState)             │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ DependencyContainer (Service Locator)                │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ↓                     ↓                     ↓
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│  Feature      │     │  Feature      │     │  Feature      │
│  Modules      │     │  Modules      │     │  Modules      │
├───────────────┤     ├───────────────┤     ├───────────────┤
│ • AuthModule  │     │ • MapModule   │     │ • ChatModule  │
│ • ProfileModule│     │ • RideRequest │     │ • Payments   │
│               │     │ • Matching    │     │ • Settings   │
│               │     │ • TripModule  │     │ • History    │
└───────────────┘     └───────────────┘     └───────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ↓
        ┌─────────────────────────────────────────────┐
        │         Shared Services Layer               │
        ├─────────────────────────────────────────────┤
        │ • NetworkingService                         │
        │ • LocationService                           │
        │ • MapService (Google/Apple/Mapbox)          │
        │ • TripService                               │
        │ • PaymentService                            │
        │ • SocketService (Real-time updates)         │
        │ • NotificationService                       │
        │ • LoggingService                            │
        └─────────────────────────────────────────────┘
```

### Data Flow

```
User Action → Feature Module → StateStore.dispatch(action)
                                      ↓
                                State Updated
                                      ↓
                         All Observers Notified
                                      ↓
                         UI Updates Automatically
```

---

## Isolation Techniques

### How do you isolate features in practice?

Here are the **exact techniques**:

#### 1. ✅ Split Features into Swift Packages

**Benefits:**
- Isolates compilation + testing
- Forces clear API boundaries
- Speeds up build times
- Makes dependencies explicit

```
Model-S/
├── App/                    # Main app target
├── Packages/
│   ├── AuthModule/
│   ├── MapModule/
│   ├── RideRequestModule/
│   ├── TripModule/
│   └── SharedServices/
```

#### 2. ✅ Use Protocols for Module Boundaries

```swift
// Public interface
protocol RideRequestModule {
    func start(coordinator: RideCoordinator)
}

// Internal implementation
class RideRequestModuleImpl: RideRequestModule {
    func start(coordinator: RideCoordinator) {
        // Implementation details hidden
    }
}
```

#### 3. ✅ Use a Global State Store for Shared State

- Single source of truth
- Observable changes
- Predictable mutations

#### 4. ✅ Use Coordinators ONLY for Navigation

- Keep them thin
- No business logic
- No state management

#### 5. ✅ Use ViewModels ONLY for Feature Logic

- Feature-specific state
- Presentation logic
- No navigation logic

#### 6. ✅ Use Services ONLY for Shared Operations

- Reusable across features
- Protocol-based
- Dependency injected

#### 7. ✅ Use State Machine for Ride Stages

- Deterministic transitions
- Type-safe states
- Easy to test

---

## Problems This Solves

With this architecture:

✅ **Add new screens without breaking others**
→ Features are independent, changes are isolated

✅ **Navigation logic never tangles with business logic**
→ Coordinators only navigate, ViewModels only manage state

✅ **Ride stages become deterministic**
→ No "stuck stage" bugs, all transitions validated

✅ **Test each feature without launching the whole app**
→ Features are self-contained units

✅ **Replace your mapping provider easily**
→ Protocol-based service layer (Google → Mapbox)

✅ **Simulate server events easily in development**
→ Mock services via dependency injection

✅ **Onboard new developers faster**
→ Clear boundaries, single responsibility

✅ **Scale the team**
→ Different teams can work on different modules

✅ **Ship features faster**
→ Less integration friction, fewer merge conflicts

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)

1. Set up global state store
2. Define core state machine (`RideState`, `RideStateMachine`)
3. Create dependency container
4. Extract existing services into protocols

### Phase 2: Feature Extraction (Week 3-4)

1. Extract Authentication module
2. Extract Map module
3. Extract Ride Request module
4. Define module interfaces (protocols)

### Phase 3: Coordinators (Week 5-6)

1. Implement `AppCoordinator`
2. Implement `AuthCoordinator`
3. Implement `RideCoordinator`
4. Migrate navigation logic out of views

### Phase 4: Testing & Refinement (Week 7-8)

1. Write unit tests for state machine
2. Write integration tests for features
3. Mock services for testing
4. Performance optimization

---

## Related Architecture Guides

This guide complements the existing architecture documentation:

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Current MVVM + Coordinator implementation
- **[NEW_ARCHITECTURE_GUIDE.md](./NEW_ARCHITECTURE_GUIDE.md)** - State machine pattern details
- **[JUNIOR_ENGINEER_GUIDE.md](./JUNIOR_ENGINEER_GUIDE.md)** - Getting started guide
- **[MAP_PROVIDER_GUIDE.md](./MAP_PROVIDER_GUIDE.md)** - Map service abstraction

---

## Summary

### Key Principles

1. **Independent feature modules** that don't know about each other
2. **Protocol boundaries** for communication between modules
3. **Global state store** for shared state (single source of truth)
4. **State machine** for ride stages (deterministic, type-safe)
5. **Coordinators** for navigation only (no business logic)
6. **Service layer** for shared operations (dependency injected)

### The Result

A **scalable, maintainable, testable** iOS rideshare app that can grow without breaking.

**State drives UI, features are isolated, and adding new functionality is straightforward.**

---

*This architecture is battle-tested by production rideshare apps (Uber/Lyft-style). Apply these patterns to build a world-class iOS application.* 🚀
