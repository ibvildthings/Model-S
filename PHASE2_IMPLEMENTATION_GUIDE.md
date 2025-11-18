# Phase 2 Implementation Guide: Feature Module Extraction

> Creating independent, protocol-based feature modules for scalable architecture

## Overview

Phase 2 builds on Phase 1's foundation by extracting features into **independent modules** with clean protocol boundaries. This enables:

✅ **Independent Development** - Teams can work on features without conflicts
✅ **Easy Testing** - Mock entire features with protocol implementations
✅ **Replaceable** - Swap implementations without changing consumers
✅ **Clear Boundaries** - Features don't know about each other

---

## What We've Built

### 1. Authentication Feature Module

**Location:** `Features/Authentication/AuthenticationFeature.swift`

#### Public Protocol

```swift
@MainActor
protocol AuthenticationFeature {
    // State
    var currentUser: User? { get }
    var isAuthenticated: Bool { get }
    var authStatePublisher: AnyPublisher<AuthState, Never> { get }

    // Actions
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String, name: String) async throws
    func signOut() async throws
    func resetPassword(email: String) async throws
    func validateSession() async -> Bool
}
```

#### Usage Example

```swift
// Get feature from factory
let authFeature = dependencies.featureFactory.createAuthenticationFeature()

// Use the feature
Task {
    do {
        try await authFeature.signIn(
            email: "user@example.com",
            password: "password123"
        )

        if authFeature.isAuthenticated {
            print("Logged in as: \(authFeature.currentUser?.name ?? "")")
        }
    } catch {
        print("Login failed: \(error)")
    }
}

// Observe auth state changes
authFeature.authStatePublisher
    .sink { state in
        switch state {
        case .authenticated(let user):
            print("User logged in: \(user.name)")
        case .unauthenticated:
            print("User logged out")
        case .authenticating:
            print("Authenticating...")
        case .error(let error):
            print("Auth error: \(error)")
        }
    }
    .store(in: &cancellables)
```

#### Authentication States

```swift
enum AuthState: Equatable {
    case unauthenticated
    case authenticating
    case authenticated(User)
    case error(AuthError)
}
```

#### Authentication Errors

```swift
enum AuthError: Error {
    case invalidCredentials
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case sessionExpired
    case unknown(Error)
}
```

### 2. Ride Request Feature Module

**Location:** `Features/RideRequest/RideRequestFeature.swift`

#### Public Protocol

```swift
@MainActor
protocol RideRequestFeature {
    // State
    var currentState: RideState { get }
    var rideStatePublisher: AnyPublisher<RideState, Never> { get }
    var hasActiveRide: Bool { get }
    var rideId: String? { get }
    var driver: DriverInfo? { get }

    // Actions
    func startRideRequest()
    func setPickupLocation(_ location: LocationPoint)
    func setDestination(_ location: LocationPoint)
    func confirmAndRequestRide() async throws
    func cancelRide() async throws
    func reset()
}
```

#### Usage Example

```swift
// Get feature from factory
let rideFeature = dependencies.featureFactory.createRideRequestFeature()

// Start ride request flow
rideFeature.startRideRequest()

// Set locations
rideFeature.setPickupLocation(pickupPoint)
rideFeature.setDestination(destinationPoint)

// Request ride
Task {
    do {
        try await rideFeature.confirmAndRequestRide()
        print("Ride requested successfully!")
    } catch {
        print("Failed to request ride: \(error)")
    }
}

// Observe ride state changes
rideFeature.rideStatePublisher
    .sink { state in
        switch state {
        case .idle:
            print("Ready to request ride")
        case .selectingLocations:
            print("Selecting locations")
        case .routeReady:
            print("Route calculated, ready to confirm")
        case .searchingForDriver:
            print("Finding a driver...")
        case .driverAssigned(_, let driver, _, _):
            print("Driver found: \(driver.name)")
        case .rideInProgress:
            print("Ride in progress")
        case .rideCompleted:
            print("Ride completed!")
        default:
            break
        }
    }
    .store(in: &cancellables)
```

### 3. Feature Factory

**Location:** `Features/RideRequest/RideRequestFeature.swift` (will be moved to `Core/Features/`)

The FeatureFactory centralizes feature module creation with proper dependency injection.

```swift
@MainActor
class FeatureFactory {
    private let dependencies: DependencyContainer

    init(dependencies: DependencyContainer = .shared) {
        self.dependencies = dependencies
    }

    func createAuthenticationFeature() -> AuthenticationFeature {
        let authService = MockAuthService() // Or production service
        return AuthenticationModule(
            authService: authService,
            stateStore: dependencies.stateStore
        )
    }

    func createRideRequestFeature() -> RideRequestFeature {
        let flowController = RideFlowController(
            rideService: dependencies.rideRequestService,
            mapService: dependencies.mapService,
            stateStore: dependencies.stateStore
        )

        return RideRequestModule(
            flowController: flowController,
            stateStore: dependencies.stateStore
        )
    }
}
```

#### Usage

```swift
// Access via DependencyContainer
let factory = DependencyContainer.shared.featureFactory

// Create features
let authFeature = factory.createAuthenticationFeature()
let rideFeature = factory.createRideRequestFeature()
```

---

## Key Architecture Patterns

### 1. Protocol-Based Boundaries

Each feature exposes a **protocol** as its public API:

```swift
protocol AuthenticationFeature { ... }  // Public interface
class AuthenticationModule: AuthenticationFeature { ... }  // Implementation
```

**Benefits:**
- ✅ Consumers depend on protocol, not concrete implementation
- ✅ Easy to create mocks for testing
- ✅ Can swap implementations without breaking consumers

### 2. Feature Modules Don't Know Each Other

Features communicate through:
- **Shared state** (AppStateStore)
- **Events** (Combine publishers)
- **Coordinators** (navigation only)

They **NEVER** import or reference each other directly.

```swift
// ❌ BAD: Direct dependency
import RideRequestModule
let rideRequest = RideRequestModule()

// ✅ GOOD: Protocol dependency
let rideRequest: RideRequestFeature = factory.createRideRequestFeature()
```

### 3. Single Responsibility

Each feature module handles **ONE** domain:

- **AuthenticationFeature**: User authentication only
- **RideRequestFeature**: Ride request flow only
- **MapFeature**: Map display and interaction only
- **ProfileFeature**: User profile management only

### 4. Dependency Injection

Features receive dependencies through initializers:

```swift
init(
    authService: AuthService,
    stateStore: AppStateStore
) {
    self.authService = authService
    self.stateStore = stateStore
}
```

**Never** create dependencies inside features:

```swift
// ❌ BAD: Creating dependencies internally
class AuthenticationModule {
    let service = AuthAPIClient()  // Hard dependency!
}

// ✅ GOOD: Injecting dependencies
class AuthenticationModule {
    init(service: AuthService) {
        self.service = service
    }
}
```

---

## How to Add a New Feature Module

### Step 1: Define the Protocol

Create `Features/YourFeature/YourFeatureInterface.swift`:

```swift
@MainActor
protocol YourFeature {
    // State
    var currentState: YourFeatureState { get }
    var statePublisher: AnyPublisher<YourFeatureState, Never> { get }

    // Actions
    func performAction() async throws
}
```

### Step 2: Implement the Module

Create `Features/YourFeature/YourFeatureModule.swift`:

```swift
@MainActor
class YourFeatureModule: YourFeature, ObservableObject {
    @Published private(set) var currentState: YourFeatureState = .idle

    private let stateStore: AppStateStore
    private let yourService: YourService

    init(yourService: YourService, stateStore: AppStateStore) {
        self.yourService = yourService
        self.stateStore = stateStore
    }

    func performAction() async throws {
        // Implementation
    }
}
```

### Step 3: Add to Feature Factory

Update `FeatureFactory`:

```swift
extension FeatureFactory {
    func createYourFeature() -> YourFeature {
        let service = YourServiceImpl()
        return YourFeatureModule(
            yourService: service,
            stateStore: dependencies.stateStore
        )
    }
}
```

### Step 4: Use the Feature

```swift
let feature = dependencies.featureFactory.createYourFeature()

Task {
    try await feature.performAction()
}
```

---

## Testing Feature Modules

### Mock Implementation

Create a mock feature for testing:

```swift
class MockAuthenticationFeature: AuthenticationFeature {
    var currentUser: User?
    var isAuthenticated: Bool = false
    var authStatePublisher: AnyPublisher<AuthState, Never> {
        Just(.unauthenticated).eraseToAnyPublisher()
    }

    var signInCalled = false
    var signInResult: Result<Void, Error> = .success(())

    func signIn(email: String, password: String) async throws {
        signInCalled = true
        try signInResult.get()
        isAuthenticated = true
    }

    // ... other methods
}
```

### Test Usage

```swift
class MyViewModelTests: XCTestCase {
    func testLoginFlow() async throws {
        // Arrange
        let mockAuth = MockAuthenticationFeature()
        mockAuth.signInResult = .success(())

        let viewModel = MyViewModel(authFeature: mockAuth)

        // Act
        await viewModel.login(email: "test@test.com", password: "password")

        // Assert
        XCTAssertTrue(mockAuth.signInCalled)
        XCTAssertTrue(mockAuth.isAuthenticated)
    }
}
```

---

## Migration from Existing Code

### Before: Direct Dependencies

```swift
class MyView: View {
    @StateObject private var flowController = RideFlowController()

    var body: some View {
        Button("Request Ride") {
            Task {
                await flowController.requestRide()
            }
        }
    }
}
```

### After: Protocol-Based

```swift
class MyView: View {
    private let rideFeature: RideRequestFeature

    init(rideFeature: RideRequestFeature) {
        self.rideFeature = rideFeature
    }

    var body: some View {
        Button("Request Ride") {
            Task {
                try await rideFeature.confirmAndRequestRide()
            }
        }
    }
}

// In parent view or coordinator
let factory = DependencyContainer.shared.featureFactory
MyView(rideFeature: factory.createRideRequestFeature())
```

---

## Files Created

```
Model S/
├── Features/
│   ├── Authentication/
│   │   └── AuthenticationFeature.swift        ✨ NEW (280 lines)
│   │       - AuthenticationFeature protocol
│   │       - AuthenticationModule implementation
│   │       - AuthService protocol
│   │       - MockAuthService
│   │       - AuthState, AuthError enums
│   │
│   └── RideRequest/
│       └── RideRequestFeature.swift           ✨ NEW (140 lines)
│           - RideRequestFeature protocol
│           - RideRequestModule implementation
│           - FeatureFactory class
│
└── Core/
    └── DI/
        └── DependencyContainer.swift          ✏️ UPDATED
            - Added featureFactory property
```

---

## Benefits of Phase 2

### ✅ Independent Development

Teams can work on different features simultaneously without merge conflicts.

```swift
// Team A works on authentication
class AuthenticationModule: AuthenticationFeature { ... }

// Team B works on ride requests
class RideRequestModule: RideRequestFeature { ... }

// No shared code = no conflicts!
```

### ✅ Easy Testing

Mock entire features with simple protocol implementations:

```swift
let mockAuth = MockAuthenticationFeature()
mockAuth.isAuthenticated = true
```

### ✅ Clear Contracts

Protocol defines exactly what the feature does:

```swift
protocol RideRequestFeature {
    func confirmAndRequestRide() async throws  // Clear action
    var hasActiveRide: Bool { get }            // Clear state
}
```

### ✅ Flexible Implementation

Swap implementations without changing consumers:

```swift
// Use production auth
let authFeature: AuthenticationFeature = ProductionAuthModule()

// Use mock auth for testing
let authFeature: AuthenticationFeature = MockAuthModule()

// Consumer code stays the same!
```

---

## Next Steps: Phase 3

Phase 3 will focus on **Coordinators** for each feature:

1. **RiderCoordinator** - Navigate through rider features
2. **DriverCoordinator** - Navigate through driver features
3. **Complete Coordinator Hierarchy** - Full app navigation tree

---

## Summary

Phase 2 establishes **feature module boundaries** with protocols:

- **AuthenticationFeature**: Protocol-based auth with mock service
- **RideRequestFeature**: Protocol-based ride requests
- **FeatureFactory**: Centralized feature creation
- **Clean Boundaries**: Features don't know about each other

**The app is now ready for independent feature development!** 🚀

Teams can work on different features in parallel, test in isolation, and swap implementations easily.
