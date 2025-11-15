# New Ride Flow Architecture Guide

## Overview

We've re-architected the ride request flow to eliminate SwiftUI state management issues and make it easy to add new states. The new architecture uses a **State Machine** pattern with a **Single Source of Truth**.

## Key Components

### 1. RideState (Enum with Associated Values)

**Location:** `Features/RideRequest/Models/RideState.swift`

```swift
enum RideState: Equatable {
    case idle
    case selectingLocations(pickup: LocationPoint?, destination: LocationPoint?)
    case routeReady(pickup: LocationPoint, destination: LocationPoint, route: RouteInfo)
    case submittingRequest(pickup: LocationPoint, destination: LocationPoint)
    case searchingForDriver(rideId: String, pickup: LocationPoint, destination: LocationPoint)
    case driverAssigned(rideId: String, driver: DriverInfo, pickup: LocationPoint, destination: LocationPoint)
    case driverEnRoute(rideId: String, driver: DriverInfo, eta: TimeInterval, pickup: LocationPoint, destination: LocationPoint)
    case error(RideRequestError, previousState: RideState?)
}
```

**Why Associated Values?**
- State and data are always in sync
- Impossible to have inconsistent state (e.g., driver info without a driver state)
- Type-safe access to state-specific data
- Self-documenting

**Computed Properties:**
- `shouldShowConfirmSlider: Bool`
- `isActiveRide: Bool`
- `rideId: String?`
- `driver: DriverInfo?`
- `estimatedArrival: TimeInterval?`
- `pickupLocation: LocationPoint?`
- `destinationLocation: LocationPoint?`
- `routeInfo: RouteInfo?`

### 2. RideStateMachine

**Location:** `Features/RideRequest/Models/RideStateMachine.swift`

Validates all state transitions to prevent invalid states.

```swift
class RideStateMachine {
    func canTransition(from: RideState, to: RideState) -> Bool
    func transition(from: RideState, to: RideState) -> RideState
    func validNextStates(from: RideState) -> [RideState]
}
```

**Benefits:**
- All transitions are validated
- Easy to see state flow
- Prevents bugs from invalid state changes
- Centralized transition logic

### 3. RideFlowController (Single Source of Truth)

**Location:** `Features/RideRequest/Controllers/RideFlowController.swift`

The ONLY object that owns ride state.

```swift
@MainActor
class RideFlowController: ObservableObject {
    @Published private(set) var currentState: RideState = .idle

    func startFlow()
    func updatePickup(_ location: LocationPoint?)
    func updateDestination(_ location: LocationPoint?)
    func calculateRoute(from: LocationPoint, to: LocationPoint) async
    func requestRide() async
    func cancelRide() async
    func reset()
}
```

**Key Features:**
- Single `@Published` property (no nested ObservableObjects!)
- All async operations happen here
- State machine validates every transition
- Exposes computed properties for UI

## How to Use

### In Views

```swift
struct RideView: View {
    @StateObject private var flowController = RideFlowController()

    var body: some View {
        VStack {
            // Use computed properties
            if flowController.shouldShowConfirmSlider {
                ConfirmSlider()
            }

            // Access state-specific data safely
            if let driver = flowController.driver {
                DriverInfoView(driver: driver)
            }

            // Handle user actions
            Button("Request Ride") {
                Task {
                    await flowController.requestRide()
                }
            }
        }
    }
}
```

### Pattern Matching on State

```swift
// React to specific states
switch flowController.currentState {
case .idle:
    Text("Ready to start")

case .selectingLocations(let pickup, let destination):
    LocationInputView(pickup: pickup, destination: destination)

case .routeReady(let pickup, let destination, let route):
    RoutePreview(pickup: pickup, destination: destination, route: route)

case .searchingForDriver:
    Text("Finding your driver...")

case .driverAssigned(_, let driver, _, _):
    Text("Driver found: \(driver.name)")

case .driverEnRoute(_, let driver, let eta, _, _):
    Text("\(driver.name) arriving in \(Int(eta/60)) min")

case .error(let error, _):
    ErrorView(error: error)

default:
    EmptyView()
}
```

## Adding New States (Step by Step)

Let's say you want to add "Driver Arrived" state.

### Step 1: Add to RideState Enum

```swift
enum RideState: Equatable {
    // ... existing cases ...

    /// Driver has arrived at pickup location
    case driverArrived(rideId: String, driver: DriverInfo, pickup: LocationPoint, destination: LocationPoint)

    // Update computed properties if needed
    var isActiveRide: Bool {
        switch self {
        case .submittingRequest, .searchingForDriver, .driverAssigned, .driverEnRoute, .driverArrived:
            return true
        default:
            return false
        }
    }
}
```

### Step 2: Update State Machine Transitions

```swift
func validNextStates(from state: RideState) -> [RideState] {
    switch state {
    // ... existing cases ...

    case .driverEnRoute:
        return [
            .driverArrived(...), // Add new transition
            .error(...)
        ]

    case .driverArrived:
        return [
            .idle, // Ride completed
            .error(...)
        ]
    }
}
```

### Step 3: Add Handler in RideFlowController

```swift
func handleDriverArrival() async {
    guard case .driverEnRoute(let rideId, let driver, _, let pickup, let destination) = currentState else {
        return
    }

    transition(to: .driverArrived(
        rideId: rideId,
        driver: driver,
        pickup: pickup,
        destination: destination
    ))
}
```

### Step 4: Update UI

```swift
switch flowController.currentState {
// ... existing cases ...

case .driverArrived(_, let driver, _, _):
    VStack {
        Text("\(driver.name) has arrived!")
        Button("Start Ride") {
            Task {
                await flowController.startJourney()
            }
        }
    }
}
```

**That's it!** The state is:
- ✅ Type-safe
- ✅ Validated by state machine
- ✅ Automatically observed by SwiftUI
- ✅ Easy to test

## Migration from Old Architecture

### Before (Old Architecture)

```swift
// ❌ Multiple sources of truth
class RideRequestViewModel: ObservableObject {
    @Published var rideState: RideRequestState
    @Published var currentDriver: DriverInfo?
    @Published var currentRideId: String?
    @Published var estimatedDriverArrival: TimeInterval?
}

class RideRequestCoordinator: ObservableObject {
    @Published var viewModel: RideRequestViewModel // Nested!

    init() {
        // ❌ Manual change forwarding
        viewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }
}

// ❌ State mutations during view updates
.onChange(of: text) { value in
    coordinator.viewModel.property = value  // Causes warnings!
}
```

### After (New Architecture)

```swift
// ✅ Single source of truth
@MainActor
class RideFlowController: ObservableObject {
    @Published private(set) var currentState: RideState = .idle
}

// ✅ No nested ObservableObjects
// ✅ No manual change forwarding
// ✅ All state in one place

// ✅ Proper async boundaries
.onChange(of: text) { value in
    flowController.updateLocation(value) // Sync method, safe!
}
```

## Benefits Summary

### 🎯 Single Source of Truth
- One object owns all state
- No synchronization issues
- Easy to debug
- Clear data flow

### 🔒 Type-Safe State Transitions
- Compiler enforces valid states
- Impossible states are impossible
- Associated values keep data together
- Self-documenting code

### 🚀 Easy to Extend
- Add new states without touching existing code
- Just update enum + state machine + add handler
- No scattered changes across files
- Works immediately

### 🧪 Highly Testable
- State machine is pure logic
- Controller is easily mockable
- Clear input/output boundaries
- No SwiftUI dependencies

### ✅ No Publisher Issues
- Single ObservableObject
- No nested forwarding needed
- SwiftUI naturally observes changes
- No "Publishing changes" warnings

## Testing

### Test State Transitions

```swift
func testStateTransitions() {
    let machine = RideStateMachine()

    // Valid transition
    let result = machine.transition(
        from: .idle,
        to: .selectingLocations(pickup: nil, destination: nil)
    )
    XCTAssertEqual(result, .selectingLocations(pickup: nil, destination: nil))

    // Invalid transition
    let invalid = machine.transition(
        from: .idle,
        to: .driverEnRoute(...)
    )
    // Should return error state
    if case .error = invalid {
        // Expected
    } else {
        XCTFail("Should have returned error state")
    }
}
```

### Test Flow Controller

```swift
@MainActor
func testRideRequest() async {
    let mockService = MockRideRequestService()
    let controller = RideFlowController(rideService: mockService)

    controller.startFlow()
    XCTAssertEqual(controller.currentState, .selectingLocations(pickup: nil, destination: nil))

    controller.updatePickup(testPickup)
    controller.updateDestination(testDestination)

    await controller.requestRide()

    // Verify final state
    if case .driverEnRoute = controller.currentState {
        // Success
    } else {
        XCTFail("Should be in driverEnRoute state")
    }
}
```

## Troubleshooting

### Q: How do I access data in a specific state?

Use pattern matching:
```swift
if case .driverEnRoute(_, let driver, let eta, _, _) = currentState {
    // Use driver and eta
}

// Or use computed properties:
if let driver = flowController.driver {
    // Use driver
}
```

### Q: Can I transition to any state?

No! The state machine validates transitions. This prevents bugs.

### Q: What if I need to go back to a previous state?

Define valid backward transitions in the state machine:
```swift
case .error(_, let previousState):
    if let previous = previousState {
        return [previous, .idle]
    }
    return [.idle]
```

### Q: How do I handle errors?

The error state carries the previous state:
```swift
.error(let error, let previousState)

// You can recover:
if let previous = previousState {
    transition(to: previous)
}
```

## Key Learnings Applied

1. ✅ **Avoid Nested ObservableObjects** - Single source of truth
2. ✅ **Use State Machines** - Make illegal states unrepresentable
3. ✅ **Associated Values > Properties** - Keep data with state
4. ✅ **Tasks in Views** - Clear async boundaries
5. ✅ **Validate Transitions** - Prevent bugs at compile time

---

**Ready to use the new architecture!** All the hard work of state management is now encapsulated in `RideFlowController`.
