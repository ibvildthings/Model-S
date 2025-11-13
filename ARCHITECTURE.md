# Model S Architecture Guide

Welcome to the Model S codebase! This guide will help you understand the architecture and get productive quickly.

## 🎯 Design Philosophy

The codebase follows these core principles:

1. **Simplicity First** - Code should be easy to understand at a glance
2. **Single Responsibility** - Each file/class does ONE thing well
3. **Clear Naming** - No ambiguity about what code does
4. **Minimal Coupling** - Components are loosely connected
5. **Unidirectional Data Flow** - Easy to trace how state changes

## 📁 Project Structure

```
Model S/
├── Core Files
│   ├── Model_SApp.swift          - App entry point
│   ├── ContentView.swift          - Root view
│   └── HomeView.swift             - Main navigation hub
│
├── Ride Request Feature
│   ├── RideRequestCoordinator.swift       - 🎯 Business logic orchestrator
│   ├── RideRequestViewModel.swift         - Domain state management
│   ├── MapViewModel.swift                 - Map display state
│   ├── ProductionExampleView.swift        - Production integration example
│   │
│   ├── Views/
│   │   ├── RideRequestView.swift          - Main ride request UI
│   │   ├── RideMapView.swift              - Map with pins and routes
│   │   ├── RideLocationCard.swift         - Location input (basic)
│   │   ├── RideLocationCardWithSearch.swift - Location input + autocomplete
│   │   ├── LocationSearchSuggestionsView.swift - Search dropdown
│   │   ├── RideConfirmSlider.swift        - Slide to confirm
│   │   ├── RouteInfoView.swift            - ETA and distance display
│   │   └── ErrorBannerView.swift          - Error messages
│   │
│   └── Models/
│       ├── RideRequestError.swift         - Error types
│       ├── RideRequestConfiguration.swift - UI configuration
│       └── Models.swift                   - LocationPoint, RideRequestState
│
├── Map Services (Adapter Pattern)
│   ├── MapServiceProtocols.swift          - Service abstractions
│   ├── AppleMapServices.swift             - Apple Maps implementation
│   └── MapServiceFactory.swift            - Service creation (in Protocols file)
│
└── Shared Utilities
    ├── Constants.swift                    - Centralized configuration values
    ├── Debounce.swift                     - Reusable debouncing utility
    └── CLLocationCoordinate2D+Equatable.swift - Extension for Equatable

```

## 🏗️ Architecture Pattern: MVVM + Coordinator

### The Coordinator Pattern (★ Key Simplification)

**Problem:** Views were doing too much - managing state, coordinating between multiple ViewModels, handling business logic.

**Solution:** `RideRequestCoordinator` centralizes ALL complex logic.

```
┌─────────────────────────────────────────┐
│      RideRequestCoordinator             │
│  (Orchestrates everything)              │
│                                         │
│  ✓ Manages RideRequestViewModel        │
│  ✓ Manages MapViewModel                │
│  ✓ Handles location selection           │
│  ✓ Coordinates route calculation        │
│  ✓ Manages debouncing                   │
│  ✓ Validates ride requests              │
└─────────────────────────────────────────┘
         ↓                    ↓
┌──────────────────┐   ┌──────────────────┐
│ RideRequestViewModel│   │  MapViewModel    │
│ (Domain State)      │   │ (Presentation)   │
│                     │   │                  │
│ • Pickup location   │   │ • Pin locations  │
│ • Destination       │   │ • Map region     │
│ • Route             │   │ • Polyline       │
│ • Errors            │   │ • User location  │
└──────────────────┘   └──────────────────┘
         ↓                    ↓
┌─────────────────────────────────────────┐
│          View Layer                      │
│  (Just presents state - NO logic)       │
└─────────────────────────────────────────┘
```

### Data Flow

**Simple, unidirectional flow:**

```
User Action → Coordinator → ViewModel(s) → View Updates
```

**Example: User selects a location**

```swift
1. User taps suggestion in LocationSearchSuggestionsView
   ↓
2. View calls: coordinator.selectLocation(coordinate, name, isPickup)
   ↓
3. Coordinator updates both ViewModels:
   - viewModel.pickupLocation = location
   - mapViewModel.updatePickupLocation(coordinate, name)
   ↓
4. Coordinator auto-calculates route if ready
   ↓
5. View observes changes and re-renders
```

**No complex view logic!** The view just calls coordinator methods.

## 📚 Key Components Explained

### 1. RideRequestCoordinator (The Brain)

**Purpose:** Orchestrates all ride request logic

**When to use:** Views call coordinator methods instead of managing state directly

**Key Methods:**
```swift
// Location management
func selectLocation(coordinate:, name:, isPickup:) async
func addressTextChanged(_:, isPickup:) // Auto-debounced

// State management
func confirmRide() -> (pickup, destination)?
func reset()

// Focus events
func didFocusPickup()
func didFocusDestination()
```

**Benefits:**
- Views are thin (just presentation)
- Easy to test (mock the coordinator)
- Single source of truth for business logic

### 2. ViewModels

#### RideRequestViewModel (Domain State)
- Manages ride-specific data
- Calls geocoding and routing services
- Publishes errors and loading state
- **Does NOT** coordinate with map

#### MapViewModel (Presentation State)
- Shows pins on map
- Manages user location
- Handles location permissions
- Updates map region
- **Does NOT** know about ride business logic

### 3. Service Layer (Adapter Pattern)

**Protocols:**
```swift
LocationSearchService  - Autocomplete search
GeocodingService      - Address ↔ Coordinates
RouteCalculationService - Calculate routes
```

**Current Implementation:**
- `AppleLocationSearchService`
- `AppleGeocodingService`
- `AppleRouteCalculationService`

**Future:** Can add Google Maps, Mapbox, etc. without changing app code!

**Factory Pattern:**
```swift
MapServiceFactory.shared.createLocationSearchService()
```

### 4. Utilities

#### Debounce.swift
Prevents excessive API calls while user types:

```swift
let debouncer = Debouncer(delay: 1.0)
debouncer.debounce {
    await performExpensiveOperation()
}
```

#### Constants.swift
Centralized configuration - NO magic numbers:

```swift
MapConstants.defaultCenter          // Default map location
MapConstants.searchRadiusMiles      // Search radius
TimingConstants.geocodingDebounceDelay  // Debounce delay
```

## 🔄 Common Tasks

### Adding a New Feature

1. **Determine scope:** Is it ride-request specific or general?
2. **Update Coordinator** if it involves business logic
3. **Update ViewModel** if it's new state
4. **Update View** for presentation only

### Debugging

1. **State issues?** Check the Coordinator
2. **Map not updating?** Check MapViewModel
3. **Routes not calculating?** Check RideRequestViewModel
4. **UI not rendering?** Check the View observing the right properties

### Testing

Mock the Coordinator for view tests:
```swift
class MockCoordinator: RideRequestCoordinator {
    var selectLocationCalled = false

    override func selectLocation(...) {
        selectLocationCalled = true
    }
}
```

## 🎨 Code Style

### Naming Conventions

- **ViewModels:** `<Feature>ViewModel` (e.g., `RideRequestViewModel`)
- **Views:** `<Feature>View` (e.g., `RideMapView`)
- **Services:** `Apple<Service>Service` (e.g., `AppleGeocodingService`)
- **Coordinators:** `<Feature>Coordinator`

### Comments

- Use `///` for documentation (shows in Xcode Quick Help)
- Use `//` for inline explanations
- Use `// MARK: -` to organize code sections

### File Length

- **Target:** < 200 lines per file
- **Max:** 300 lines
- **If longer:** Extract to separate files

## 🚀 Getting Started

### For New Developers

1. **Read this guide** (you're here!)
2. **Run the app** and explore `ProductionExampleView`
3. **Set a breakpoint** in `RideRequestCoordinator.selectLocation()`
4. **Trigger it** by selecting a location in the app
5. **Step through** to see the data flow

### Common Gotchas

1. **@MainActor required** - Many components use `@MainActor` for thread safety
2. **Async/await everywhere** - Location and routing are async
3. **Published properties** - Changes trigger view updates
4. **StateObject vs ObservedObject** - StateObject owns, ObservedObject observes

## 📖 Further Reading

- **SwiftUI MVVM:** [Apple's SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- **Coordinator Pattern:** [Coordinator Pattern in SwiftUI](https://www.hackingwithswift.com/articles/216/complete-guide-to-navigationstack-in-swiftui)
- **MapKit:** [Apple MapKit Documentation](https://developer.apple.com/documentation/mapkit)

## 🤝 Contributing

When adding code:

1. ✅ Keep it simple
2. ✅ Add documentation comments
3. ✅ Use Constants instead of magic numbers
4. ✅ Put business logic in Coordinator
5. ✅ Keep views thin (presentation only)
6. ✅ Write clear commit messages

## 💡 Questions?

- Check this guide first
- Look at `ProductionExampleView.swift` for usage examples
- Examine `RideRequestCoordinator.swift` to understand flow
- Read inline comments - they explain "why" not just "what"

---

**Remember:** Simple code is maintainable code. When in doubt, favor clarity over cleverness! 🎯
