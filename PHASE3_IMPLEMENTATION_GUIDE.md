# Phase 3 Implementation Guide: Coordinator Hierarchy

> Creating a complete coordinator hierarchy for rider and driver modes

## Overview

Phase 3 builds on Phases 1 & 2 by creating a **complete coordinator hierarchy** that manages navigation for your existing features. Unlike the architecture guide which proposed hypothetical features, this implementation focuses on what you **actually have**: Rider and Driver modes.

---

## What We Built

### 1. Rider Coordinator

**Location:** `Core/Coordination/RiderCoordinator.swift`

Manages all rider-side navigation and features.

#### Responsibilities

- Navigate between rider screens (Home, RideRequest, History, Settings)
- Observe ride state for automatic navigation
- Handle rider-specific analytics and notifications
- Manage RideRequestCoordinator lifecycle

#### Screens

```swift
enum RiderScreen {
    case home          // HomeView
    case rideRequest   // ProductionExampleView with RideRequestCoordinator
    case history       // RideHistoryView
    case settings      // MapProviderSettingsView
}
```

#### Usage

```swift
let riderCoordinator = RiderCoordinator(
    stateStore: appState,
    dependencies: dependencies
)

riderCoordinator.start()

// Navigate
riderCoordinator.showRideRequest()
riderCoordinator.showHistory()
riderCoordinator.showSettings()
```

#### State-Driven Navigation

The rider coordinator observes ride state and automatically navigates:

```swift
// When ride state changes to searching/assigned/enroute
→ Automatically shows ride request screen

// When ride completes
→ Stays on current screen (user can navigate manually)
```

### 2. Driver Coordinator

**Location:** `Core/Coordination/DriverCoordinator.swift`

Manages all driver-side navigation and features.

#### Responsibilities

- Navigate between driver screens (Home, Active Ride, Ride Offers)
- Manage DriverFlowController lifecycle
- Handle driver-specific flows

#### Screens

```swift
enum DriverScreen {
    case home        // DriverAppView
    case activeRide  // ActiveRideView
    case rideOffer   // RideOfferView
}
```

#### Usage

```swift
let driverCoordinator = DriverCoordinator(
    stateStore: appState,
    dependencies: dependencies
)

driverCoordinator.start()

// Navigate
driverCoordinator.showHome()
driverCoordinator.showActiveRide()
driverCoordinator.showRideOffer()
```

### 3. Updated Main Coordinator

**Location:** `Core/Coordination/AppCoordinator.swift` (updated)

Delegates to feature coordinators instead of managing everything itself.

#### Key Changes

**Before:**
```swift
class MainCoordinator {
    // Tried to manage everything directly
    func setupObservers() {
        // TODO: Show driver interface
        // TODO: Show rider interface
    }
}
```

**After:**
```swift
class MainCoordinator {
    // Delegates to child coordinators
    private var riderCoordinator: RiderCoordinator?
    private var driverCoordinator: DriverCoordinator?

    func showRiderMode() {
        riderCoordinator = RiderCoordinator(...)
        riderCoordinator?.start()
    }

    func showDriverMode() {
        driverCoordinator = DriverCoordinator(...)
        driverCoordinator?.start()
    }
}
```

#### App Mode

```swift
enum AppMode {
    case rider
    case driver
}
```

The Main Coordinator switches between modes based on `AppStateStore.isDriverMode`.

---

## Complete Coordinator Hierarchy

```
AppCoordinator (Root)
│
├── AuthCoordinator
│   └── (Future: Login/Signup screens)
│
└── MainCoordinator
    │
    ├── RiderCoordinator (when isDriverMode = false)
    │   ├── Home
    │   ├── RideRequest (manages RideRequestCoordinator)
    │   ├── History
    │   └── Settings
    │
    └── DriverCoordinator (when isDriverMode = true)
        ├── Home (DriverAppView)
        ├── ActiveRide
        └── RideOffer
```

---

## View Integration

### Main App Flow

```swift
CoordinatedAppView (Root)
    ↓
AppCoordinator
    ↓
MainAppView
    ↓ (switches based on mode)
    ├── RiderCoordinatedView (rider mode)
    │       ↓
    │   RiderCoordinator → Shows appropriate rider screen
    │
    └── DriverCoordinatedView (driver mode)
            ↓
        DriverCoordinator → Shows appropriate driver screen
```

### SwiftUI Integration

Each coordinator has a corresponding view:

**RiderCoordinatedView:**
```swift
struct RiderCoordinatedView: View {
    @StateObject private var coordinator: RiderCoordinator

    var body: some View {
        Group {
            switch coordinator.currentScreen {
            case .home: HomeView()
            case .rideRequest: ProductionExampleView(...)
            case .history: RideHistoryView()
            case .settings: MapProviderSettingsView()
            }
        }
    }
}
```

**DriverCoordinatedView:**
```swift
struct DriverCoordinatedView: View {
    @StateObject private var coordinator: DriverCoordinator

    var body: some View {
        Group {
            switch coordinator.currentScreen {
            case .home: DriverAppView(...)
            case .activeRide: ActiveRideView(...)
            case .rideOffer: RideOfferView(...)
            }
        }
    }
}
```

---

## Key Benefits

### ✅ Clear Separation

Rider and Driver features are completely separate:

```swift
// Rider features
RiderCoordinator → HomeView, RideRequest, History, Settings

// Driver features
DriverCoordinator → DriverApp, ActiveRide, RideOffer

// No overlap, no confusion
```

### ✅ Independent Navigation

Each coordinator manages its own navigation:

```swift
// Rider navigation
riderCoordinator.showRideRequest()
riderCoordinator.showHistory()

// Driver navigation
driverCoordinator.showActiveRide()
driverCoordinator.showRideOffer()

// No cross-contamination
```

### ✅ Easy Mode Switching

MainCoordinator cleanly switches between modes:

```swift
// User switches to driver mode
stateStore.dispatch(.setDriverMode(true))

// MainCoordinator observes and switches
mainCoordinator.showDriverMode()
    → Stops RiderCoordinator
    → Starts DriverCoordinator
```

### ✅ State-Driven UI

Coordinators observe state and navigate automatically:

```swift
// Ride state changes to .driverEnRoute
riderCoordinator observes
    → Automatically shows ride request screen

// No manual navigation needed
```

---

## How Navigation Works

### 1. User Action

User taps "Order a Ride" in HomeView

### 2. Coordinator Receives Action

```swift
riderCoordinator.showRideRequest()
```

### 3. Coordinator Updates State

```swift
currentScreen = .rideRequest
```

### 4. View Observes Change

```swift
RiderCoordinatedView observes coordinator.currentScreen
    → Shows ProductionExampleView
```

### 5. Done!

Navigation complete, new screen visible.

---

## Testing Coordinators

### Mock Coordinator

```swift
class MockRiderCoordinator: RiderCoordinator {
    var showRideRequestCalled = false
    var showHistoryCalled = false

    override func showRideRequest() {
        showRideRequestCalled = true
    }

    override func showHistory() {
        showHistoryCalled = true
    }
}
```

### Test Usage

```swift
func testNavigationToRideRequest() {
    let mockCoordinator = MockRiderCoordinator(...)

    // Trigger navigation
    mockCoordinator.showRideRequest()

    // Verify
    XCTAssertTrue(mockCoordinator.showRideRequestCalled)
}
```

---

## Migrating Existing Code

### Before: Direct Navigation

```swift
struct HomeView: View {
    @State private var showRideRequest = false

    var body: some View {
        Button("Order Ride") {
            showRideRequest = true
        }
        .sheet(isPresented: $showRideRequest) {
            ProductionExampleView()
        }
    }
}
```

### After: Coordinator-Driven

```swift
struct RiderCoordinatedView: View {
    @ObservedObject var coordinator: RiderCoordinator

    var body: some View {
        // Coordinator handles navigation automatically
        // Just show the current screen
        switch coordinator.currentScreen {
        case .home: HomeView()
        case .rideRequest: ProductionExampleView(...)
        // ...
        }
    }
}
```

---

## Files Created/Modified

```
Model S/
├── Core/Coordination/
│   ├── AppCoordinator.swift              ✏️ UPDATED
│   │   - Updated MainCoordinator with child coordinators
│   │   - Added AppMode enum
│   │   - Added MainAppView for mode switching
│   │
│   ├── RiderCoordinator.swift            ✨ NEW (185 lines)
│   │   - RiderCoordinator class
│   │   - RiderScreen enum
│   │   - RiderCoordinatedView
│   │
│   └── DriverCoordinator.swift           ✨ NEW (135 lines)
│       - DriverCoordinator class
│       - DriverScreen enum
│       - DriverCoordinatedView
```

---

## What's Different from the Architecture Guide?

The original guide proposed coordinators for hypothetical features. This implementation is **pragmatic**:

❌ **Not Implemented:** AuthCoordinator (no auth in app yet)
❌ **Not Implemented:** Coordinators for features that don't exist

✅ **Implemented:** RiderCoordinator (you have rider features)
✅ **Implemented:** DriverCoordinator (you have driver features)
✅ **Implemented:** Proper hierarchy with MainCoordinator

**Focus:** What you need now, not what you might need later.

---

## Next Steps

### Optional Phase 4: Testing & Refinement

If beneficial, Phase 4 could add:

1. **Unit Tests** for coordinators
2. **Integration Tests** for navigation flows
3. **Performance Optimization** if needed
4. **Documentation Updates** based on usage

---

## Summary

Phase 3 creates a **complete coordinator hierarchy** for your actual app:

- **RiderCoordinator**: Manages rider-side navigation (Home, RideRequest, History, Settings)
- **DriverCoordinator**: Manages driver-side navigation (DriverApp, ActiveRide, RideOffer)
- **MainCoordinator**: Switches between rider/driver modes cleanly
- **State-Driven**: Navigation responds to state changes automatically

**The app now has a complete, working coordinator hierarchy for both rider and driver modes!** 🚀

Each mode is independent, navigation is clean, and switching modes is seamless.
