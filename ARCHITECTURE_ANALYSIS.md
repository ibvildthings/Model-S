# SwiftUI State Management & Publisher Architecture Analysis

## Problems We Encountered

### 1. "Publishing changes from within view updates" Warning

**Root Cause:**
```swift
// ❌ WRONG: State mutation during view rendering
.onChange(of: text) { newValue in
    viewModel.property = newValue  // Happens during view update cycle
}
```

**Why It Happens:**
- SwiftUI's view update cycle is synchronous
- When `.onChange` fires, we're still in the view's body evaluation
- Mutating `@Published` properties triggers `objectWillChange`
- This creates a feedback loop: View Update → State Change → View Update

**Solution:**
```swift
// ✅ CORRECT: Defer to next run loop
.onChange(of: text) { newValue in
    DispatchQueue.main.async {
        viewModel.property = newValue
    }
}
```

### 2. Nested ObservableObjects Not Updating Views

**Root Cause:**
```swift
class Coordinator: ObservableObject {
    @Published var viewModel: SomeViewModel  // ❌ Changes inside viewModel don't propagate
}
```

**Why It Happens:**
- `@Published` only observes the **reference** change, not property changes within the object
- When `viewModel.someProperty` changes, the reference stays the same
- SwiftUI doesn't know to re-render

**Solution:**
```swift
class Coordinator: ObservableObject {
    @Published var viewModel: SomeViewModel
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.viewModel = SomeViewModel()

        // ✅ Forward nested object changes
        viewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }
}
```

### 3. Task Creation in Button Actions During Rendering

**Root Cause:**
```swift
Button("Confirm") {
    coordinator.confirmRide()  // This is called during view evaluation
}

func confirmRide() {
    Task {  // ❌ Created during view rendering
        await doAsyncWork()
    }
}
```

**Why It Happens:**
- Button actions are closures evaluated when building the view
- Creating Tasks here can coincide with view updates
- State changes from the Task conflict with ongoing view updates

**Solution:**
```swift
// ✅ Create Task in the view layer, outside coordinator
Button("Confirm") {
    Task {
        await coordinator.startRideRequest()
    }
}
```

## Current Architecture Issues

### Issue 1: Split State Across Multiple Objects
```
RideRequestCoordinator
├── viewModel (RideRequestViewModel)
│   ├── rideState
│   ├── currentDriver
│   └── estimatedDriverArrival
└── mapViewModel (MapViewModel)
    ├── pickupLocation
    └── destinationLocation
```

**Problems:**
- State is fragmented
- Hard to ensure consistency
- Complex change propagation chain
- Difficult to add new states

### Issue 2: State Transitions Mixed with Business Logic

```swift
func requestRide() async {
    rideState = .rideRequested        // State change
    let result = try await service()  // Business logic
    rideState = .searchingForDriver   // State change
    // ...
}
```

**Problems:**
- State transitions are implicit
- No single place to see all possible transitions
- Hard to validate state changes
- Difficult to debug

### Issue 3: No Clear State Machine

Current states are just an enum:
```swift
enum RideRequestState {
    case selectingPickup
    case selectingDestination
    case routeReady
    case rideRequested
    case searchingForDriver
    case driverFound
    case driverEnRoute
}
```

**Missing:**
- Valid state transitions
- Entry/exit actions
- Guards for state changes
- Clear state lifecycle

## Proposed Architecture

### 1. Single Source of Truth: RideFlowController

```swift
@MainActor
class RideFlowController: ObservableObject {
    // Single published state - the only source of truth
    @Published private(set) var currentState: RideState

    // State transition manager
    private let stateMachine: RideStateMachine

    // Services
    private let rideService: RideRequestService

    // State data (separate from state machine)
    @Published private(set) var driver: DriverInfo?
    @Published private(set) var estimatedArrival: TimeInterval?
}
```

**Benefits:**
- One object owns all state
- No nested ObservableObjects
- Clear ownership
- Easy to observe

### 2. Explicit State Machine

```swift
class RideStateMachine {
    func canTransition(from: RideState, to: RideState) -> Bool
    func transition(from: RideState, to: RideState, context: Context) -> RideState
    func validNextStates(from: RideState) -> [RideState]
}
```

**Benefits:**
- All transitions are validated
- Easy to see state flow
- Prevents invalid states
- Self-documenting

### 3. State with Associated Data

```swift
enum RideState: Equatable {
    case idle
    case selectingLocations(pickup: LocationPoint?, destination: LocationPoint?)
    case routeCalculated(route: RouteInfo)
    case requestingRide
    case searchingForDriver(rideId: String)
    case driverFound(driver: DriverInfo, eta: TimeInterval)
    case driverEnRoute(driver: DriverInfo, eta: TimeInterval)
    case error(RideRequestError)
}
```

**Benefits:**
- State carries its own data
- No separate properties to keep in sync
- Impossible to have inconsistent state
- Type-safe

### 4. Clear Async Boundaries

```swift
// ✅ Coordinator only has sync validation methods
class RideRequestCoordinator {
    func validateLocations() -> Result<(LocationPoint, LocationPoint), Error>
}

// ✅ Controller handles all async operations
class RideFlowController {
    func startRideRequest() async
    func requestRide(pickup: LocationPoint, destination: LocationPoint) async
}

// ✅ View creates Tasks
struct RideView: View {
    func handleConfirm() {
        Task {
            await controller.startRideRequest()
        }
    }
}
```

**Benefits:**
- Clear responsibility separation
- No Task creation in coordinators
- No state mutation conflicts
- Easy to test

## Migration Strategy

### Phase 1: Create New Components
1. Create `RideState` enum with associated values
2. Create `RideStateMachine` with transition rules
3. Create `RideFlowController` as single source of truth

### Phase 2: Migrate Logic
1. Move state management to `RideFlowController`
2. Update coordinator to be a lightweight orchestrator
3. Update views to use controller directly

### Phase 3: Cleanup
1. Remove old state properties
2. Remove change forwarding hacks
3. Simplify view models
4. Update documentation

## Benefits of New Architecture

✅ **Single Source of Truth**
- One object owns all ride state
- No synchronization issues
- Easy to debug

✅ **Type-Safe State Transitions**
- Compiler-enforced state validity
- Impossible states are impossible
- Clear state lifecycle

✅ **Easy to Extend**
- Adding new states is straightforward
- Just add to enum and state machine
- No scattered changes

✅ **Testable**
- State machine is pure logic
- Controller is easily mockable
- Clear input/output boundaries

✅ **No Publisher Issues**
- Single ObservableObject
- No nested forwarding needed
- SwiftUI naturally observes changes

## Example: Adding a New State

### Current Architecture (❌ Hard)
1. Add case to enum
2. Add properties to ViewModel for data
3. Add logic to multiple methods
4. Forward changes through layers
5. Hope nothing breaks

### New Architecture (✅ Easy)
1. Add case to enum with associated data:
   ```swift
   case arrivedAtPickup(driver: DriverInfo)
   ```

2. Add transitions to state machine:
   ```swift
   func validTransitions(from state: RideState) -> [RideState] {
       case .driverEnRoute:
           return [.arrivedAtPickup, .error]
   }
   ```

3. Add handler in controller:
   ```swift
   func handleDriverArrival() async {
       await stateMachine.transition(to: .arrivedAtPickup(driver: currentDriver))
   }
   ```

4. View automatically updates (no changes needed)

Done! Type-safe, validated, testable.

---

## Key Learnings

1. **Avoid Nested ObservableObjects** - Use composition, not nesting
2. **Defer State Mutations** - Use DispatchQueue.main.async in onChange
3. **Tasks in Views, Not Coordinators** - Keep async boundaries clear
4. **Use State Machines** - Make illegal states unrepresentable
5. **Associated Values > Separate Properties** - Keep state cohesive

## References

- [SwiftUI Data Flow](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [Combine Framework](https://developer.apple.com/documentation/combine)
- [State Machines in Swift](https://www.swiftbysundell.com/articles/state-machines-in-swift/)
