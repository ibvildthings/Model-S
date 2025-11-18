# Map Provider Guide - Modern Architecture

This guide explains the refactored maps architecture in Model S, designed for simplicity, maintainability, and extensibility.

---

## 🎯 Overview

The app supports both **Apple Maps** and **Google Maps** with seamless runtime switching. The architecture uses a unified service interface that makes it trivial to add new map providers.

### What Changed in the Refactoring

**Before:** Fragmented services, dual state management, complex factory patterns
**After:** Unified service interface, single source of truth, elegant composition

```
Old Architecture (3 protocols):          New Architecture (1 protocol):
├── LocationSearchService                ├── MapService (unified)
├── GeocodingService                     │   ├── search()
├── RouteCalculationService              │   ├── geocode()
└── MapServiceFactory                    │   ├── reverseGeocode()
                                         │   └── calculateRoute()
                                         ├── AppleMapService
                                         ├── GoogleMapService
                                         └── MapProviderService (manages state)
```

---

## 🚀 Quick Start

### Switching Map Providers

The new `MapProviderService` is the single source of truth for provider selection:

```swift
// Switch to Apple Maps
MapProviderService.shared.useAppleMaps()

// Switch to Google Maps (validates API key automatically)
let result = MapProviderService.shared.useGoogleMaps()
switch result {
case .success:
    print("✅ Switched to Google Maps")
case .failure(let error):
    print("❌ Failed: \(error.localizedDescription)")
}

// Toggle between providers
MapProviderService.shared.toggleProvider()

// Check current provider
let current = MapProviderService.shared.currentProvider
print("Using: \(current.displayName)")
```

### Using Map Services

All map operations are now unified in a single service:

```swift
// Get current map service
let mapService = MapProviderService.shared.currentService

// Search for locations
mapService.search(query: "Starbucks")

// Geocode an address
let (coordinate, name) = try await mapService.geocode(address: "123 Main St")

// Reverse geocode coordinates
let address = try await mapService.reverseGeocode(coordinate: coordinate)

// Calculate route
let route = try await mapService.calculateRoute(from: pickup, to: destination)
```

### Using in SwiftUI Views

The new architecture uses dependency injection for clean, testable code:

```swift
struct MyMapView: View {
    @StateObject private var providerService = MapProviderService.shared

    var body: some View {
        VStack {
            // Current provider info
            Text("Using: \(providerService.currentProvider.displayName)")

            // Map operations
            Button("Search") {
                providerService.currentService.search(query: "Coffee")
            }

            // Switch providers
            Button("Toggle Provider") {
                providerService.toggleProvider()
            }
        }
    }
}
```

---

## 🏗️ Architecture Deep Dive

### The Three Layers

```
┌─────────────────────────────────────────────┐
│   MapProviderService (State Management)     │
│   • Manages current provider                │
│   • Creates service instances               │
│   • Validates availability (API keys)       │
│   • Persists user preference                │
└────────────────┬────────────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────────────┐
│   MapService Protocol (Unified Interface)   │
│   • search(query:)                          │
│   • geocode(address:)                       │
│   • reverseGeocode(coordinate:)             │
│   • calculateRoute(from:to:)                │
│   • Provider-agnostic                       │
└────────────────┬────────────────────────────┘
                 │
        ┌────────┴────────┐
        ↓                 ↓
┌───────────────┐  ┌──────────────┐
│ AppleMap      │  │ GoogleMap    │
│ Service       │  │ Service      │
│ (Composes     │  │ (Composes    │
│ Apple impls)  │  │ Google impls)│
└───────────────┘  └──────────────┘
```

### Key Components

#### 1. MapService Protocol (Core/Services/Map/MapService.swift)

The unified interface for all map operations:

```swift
@MainActor
protocol MapService: ObservableObject {
    // Search
    var searchResults: [LocationSearchResult] { get }
    var isSearching: Bool { get }
    func search(query: String)
    func getCoordinate(for result: LocationSearchResult) async throws -> (CLLocationCoordinate2D, String)

    // Geocoding
    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String)
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String

    // Routing
    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult

    // Provider info
    var provider: MapProvider { get }
}
```

**Benefits:**
- Single interface to learn
- Easy to add new providers
- Type-safe operations
- Consistent error handling

#### 2. MapProviderService (Core/Services/Map/MapProviderService.swift)

Single source of truth for provider management:

```swift
@MainActor
class MapProviderService: ObservableObject {
    static let shared = MapProviderService()

    // Current provider (auto-saves to UserDefaults)
    @Published private(set) var currentProvider: MapProvider

    // Current service instance (auto-updates when provider changes)
    @Published private(set) var currentService: AnyMapService

    // Check provider availability
    var isGoogleMapsAvailable: Bool { }
    var isAppleMapsAvailable: Bool { }
    var availableProviders: [MapProvider] { }

    // Switch providers (returns Result for error handling)
    func switchTo(provider: MapProvider) -> Result<Void, MapServiceError>
    func useAppleMaps() -> Result<Void, MapServiceError>
    func useGoogleMaps() -> Result<Void, MapServiceError>
    func toggleProvider()
}
```

**Key Features:**
- Singleton pattern for global access
- `@Published` properties for reactive updates
- Automatic persistence to UserDefaults
- Validates API key availability
- Graceful error handling (no crashes!)

#### 3. AppleMapService (Core/Services/Map/AppleMapService.swift)

Unified Apple Maps implementation:

```swift
@MainActor
class AppleMapService: MapService {
    let provider: MapProvider = .apple

    private let searchService: AppleLocationSearchService
    private let geocodingService: AppleGeocodingService
    private let routeService: AppleRouteCalculationService

    // Implements all MapService methods by delegating to composed services
}
```

**Implementation:**
- Composes existing Apple services
- No external dependencies
- Always available (no API key needed)

#### 4. GoogleMapService (Core/Services/Map/GoogleMapService.swift)

Unified Google Maps implementation:

```swift
@MainActor
class GoogleMapService: MapService {
    let provider: MapProvider = .google

    private let searchService: GoogleLocationSearchService
    private let geocodingService: GoogleGeocodingService
    private let routeService: GoogleRouteCalculationService

    init() {
        let apiKey = SecretsManager.googleMapsAPIKey ?? ""
        // Gracefully handles missing API key
    }
}
```

**Implementation:**
- Composes existing Google services
- Uses REST APIs (Places, Geocoding, Directions)
- Validates API key before operations
- Throws `MapServiceError` for better error handling

---

## 📱 UI Integration

### MapProviderSwitcher Component

A ready-to-use UI component for switching providers:

```swift
struct MapProviderSwitcher: View {
    @StateObject private var providerService = MapProviderService.shared

    var body: some View {
        Menu {
            // Shows only available providers
            ForEach(providerService.availableProviders, id: \.self) { provider in
                Button(action: {
                    providerService.switchTo(provider: provider)
                }) {
                    Label(provider.displayName, systemImage: provider.icon)
                    if providerService.currentProvider == provider {
                        Image(systemName: "checkmark")
                    }
                }
            }

            // Shows unavailable providers with warning
            ForEach(unavailableProviders, id: \.self) { provider in
                Button(action: {}) {
                    Label(provider.displayName, systemImage: provider.icon)
                    Image(systemName: "exclamationmark.triangle")
                }
                .disabled(true)
            }
        } label: {
            // Compact floating button
        }
    }
}
```

**Usage:**
```swift
// Add to any view
ZStack {
    MapView()

    VStack {
        HStack {
            Spacer()
            MapProviderSwitcher()
                .padding()
        }
        Spacer()
    }
}
```

### RideMapView Integration

The map view automatically switches between providers:

```swift
struct RideMapView: View {
    @ObservedObject var viewModel: MapViewModel
    @StateObject private var providerService = MapProviderService.shared

    var body: some View {
        Group {
            switch providerService.currentProvider {
            case .apple:
                MapViewWrapper(/* Apple Maps */)
            case .google:
                GoogleMapViewWrapper(/* Google Maps */)
            }
        }
    }
}
```

**No manual refresh needed!** When `currentProvider` changes, the view automatically re-renders.

---

## ⚙️ Setup Guide

### Apple Maps (Zero Configuration)

✅ **Works out of the box**
✅ No API key required
✅ Uses iOS built-in MapKit
✅ Always available

**That's it!** Apple Maps works immediately.

### Google Maps (Requires API Key)

#### Step 1: Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or select existing)
3. Enable these APIs:
   - **Places API** (for location search)
   - **Geocoding API** (for address ↔ coordinates)
   - **Directions API** (for route calculation)
4. Go to **Credentials** → **Create Credentials** → **API Key**
5. Copy the API key

#### Step 2: Configure API Key Securely

**Option A: Using Secrets.plist (Recommended)**

1. Create `Secrets.plist` in your project root (it's gitignored):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GoogleMapsAPIKey</key>
    <string>YOUR_API_KEY_HERE</string>
</dict>
</plist>
```

2. The app will automatically load it via `SecretsManager`

**Option B: Direct Configuration (For Testing)**

Edit `Core/Configuration/SecretsManager.swift`:

```swift
enum SecretsManager {
    static var googleMapsAPIKey: String? {
        return "YOUR_TEMPORARY_TEST_KEY"
    }
}
```

⚠️ **Never commit API keys to git!**

#### Step 3: Verify Setup

```swift
// Check if Google Maps is available
let isAvailable = MapProviderService.shared.isGoogleMapsAvailable

if isAvailable {
    print("✅ Google Maps ready to use")
} else {
    print("⚠️ Google Maps API key not configured")
}
```

---

## 🧪 Testing

### Testing Provider Switching

```swift
func testProviderSwitch() async {
    let service = MapProviderService.shared

    // Start with Apple Maps
    service.useAppleMaps()
    XCTAssertEqual(service.currentProvider, .apple)
    XCTAssertEqual(service.currentService.provider, .apple)

    // Switch to Google Maps
    let result = service.useGoogleMaps()
    if case .success = result {
        XCTAssertEqual(service.currentProvider, .google)
        XCTAssertEqual(service.currentService.provider, .google)
    }
}
```

### Testing Map Operations

```swift
func testGeocode() async throws {
    let service = MapProviderService.shared.currentService

    let (coordinate, name) = try await service.geocode(address: "1 Apple Park Way")

    XCTAssertNotNil(coordinate)
    XCTAssertFalse(name.isEmpty)
    XCTAssertEqual(coordinate.latitude, 37.334, accuracy: 0.1)
}
```

### Mock Service for Testing

```swift
class MockMapService: MapService {
    let provider: MapProvider = .apple
    var searchResults: [LocationSearchResult] = []
    var isSearching: Bool = false
    var shouldFail = false

    func search(query: String) {
        // Mock implementation
    }

    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String) {
        if shouldFail {
            throw MapServiceError.geocodingFailed
        }
        return (CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0), address)
    }

    // ... other methods
}

// Use in tests
let coordinator = RideRequestCoordinator(mapService: AnyMapService(MockMapService()))
```

---

## 🎨 Adding a New Map Provider (e.g., Mapbox)

The refactored architecture makes adding providers trivial:

### Step 1: Add to MapProvider Enum

```swift
// In MapServiceProtocols.swift
enum MapProvider: CaseIterable {
    case apple
    case google
    case mapbox  // ← New provider
}

extension MapProvider {
    var displayName: String {
        switch self {
        case .apple: return "Apple Maps"
        case .google: return "Google Maps"
        case .mapbox: return "Mapbox"  // ← Add name
        }
    }

    var icon: String {
        switch self {
        case .apple: return "map.fill"
        case .google: return "globe.americas.fill"
        case .mapbox: return "map.circle.fill"  // ← Add icon
        }
    }
}
```

### Step 2: Implement MapService Protocol

```swift
// Create MapboxMapService.swift
import MapboxMaps

@MainActor
class MapboxMapService: MapService {
    let provider: MapProvider = .mapbox

    @Published var searchResults: [LocationSearchResult] = []
    @Published var isSearching: Bool = false

    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func search(query: String) {
        // Use Mapbox Search API
    }

    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String) {
        // Use Mapbox Geocoding API
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String {
        // Use Mapbox Reverse Geocoding
    }

    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult {
        // Use Mapbox Directions API
    }
}
```

### Step 3: Update MapProviderService

```swift
// In MapProviderService.swift
private static func createService(for provider: MapProvider) -> AnyMapService {
    switch provider {
    case .apple:
        return AnyMapService(AppleMapService())
    case .google:
        return AnyMapService(GoogleMapService())
    case .mapbox:  // ← Add case
        return AnyMapService(MapboxMapService(apiKey: SecretsManager.mapboxAPIKey ?? ""))
    }
}

var isMapboxAvailable: Bool {
    // Check API key
}
```

### Step 4: Add Map View Wrapper (Optional)

```swift
struct MapboxMapViewWrapper: UIViewRepresentable {
    @Binding var region: MapRegion
    var pickupLocation: CLLocationCoordinate2D?
    var destinationLocation: CLLocationCoordinate2D?
    // ... same interface as Apple/Google wrappers
}

// Update RideMapView
var body: some View {
    switch providerService.currentProvider {
    case .apple: appleMapView
    case .google: googleMapView
    case .mapbox: mapboxMapView  // ← Add case
    }
}
```

**That's it!** The entire app now supports Mapbox with zero changes to existing code.

---

## 💡 Best Practices

### 1. Always Use MapProviderService

```swift
// ✅ GOOD: Use centralized service
let service = MapProviderService.shared.currentService
service.search(query: "Coffee")

// ❌ BAD: Create services directly
let service = AppleLocationSearchService()  // Don't do this!
```

### 2. Handle Errors Gracefully

```swift
// ✅ GOOD: Handle Result type
let result = MapProviderService.shared.useGoogleMaps()
switch result {
case .success:
    showSuccess("Switched to Google Maps")
case .failure(let error):
    showError(error.localizedDescription)
}

// ✅ GOOD: Catch async errors
do {
    let route = try await mapService.calculateRoute(from: pickup, to: destination)
} catch let error as MapServiceError {
    handleMapError(error)
} catch {
    handleUnexpectedError(error)
}
```

### 3. Check Provider Availability

```swift
// ✅ GOOD: Check before switching
if MapProviderService.shared.isGoogleMapsAvailable {
    MapProviderService.shared.useGoogleMaps()
} else {
    showAlert("Google Maps requires an API key")
}

// ✅ GOOD: Show only available providers
let providers = MapProviderService.shared.availableProviders
// UI automatically updates
```

### 4. Use SwiftUI Environment for Dependency Injection

```swift
// In parent view
@StateObject private var providerService = MapProviderService.shared

var body: some View {
    ChildView()
        .environment(\.mapService, providerService.currentService)
}

// In child view
@Environment(\.mapService) var mapService

func search() {
    mapService.search(query: "Coffee")
}
```

### 5. Persist User Preference Automatically

The `MapProviderService` automatically saves to UserDefaults:

```swift
// User switches to Google Maps
MapProviderService.shared.useGoogleMaps()
// ✅ Automatically saved to UserDefaults

// Next app launch
// ✅ Automatically loads last used provider
```

---

## 🐛 Troubleshooting

### Issue: Google Maps Services Not Working

**Symptom:** Search/geocoding fails with errors

**Solution:**
```swift
// Check API key
print("API Key: \(SecretsManager.googleMapsAPIKey ?? "MISSING")")

// Verify APIs enabled in Google Cloud Console:
// - Places API
// - Geocoding API
// - Directions API

// Check availability
let available = MapProviderService.shared.isGoogleMapsAvailable
print("Google Maps Available: \(available)")
```

### Issue: Provider Not Switching

**Symptom:** UI doesn't update after switching

**Solution:**
```swift
// ✅ GOOD: Use @StateObject
@StateObject private var providerService = MapProviderService.shared

// ❌ BAD: Don't create new instance
let providerService = MapProviderService()  // Wrong!
```

### Issue: "API Key Missing" Error

**Symptom:** MapServiceError.apiKeyMissing thrown

**Solution:**
1. Check `Secrets.plist` exists and is in project
2. Verify key name is `GoogleMapsAPIKey`
3. Ensure plist is included in build (Build Phases → Copy Bundle Resources)
4. Clean build folder (⇧⌘K) and rebuild

### Issue: Map View Not Updating

**Symptom:** Visual map doesn't change after switch

**Solution:**
```swift
// Ensure RideMapView observes the service
@StateObject private var providerService = MapProviderService.shared

var body: some View {
    // This will re-render when currentProvider changes
    switch providerService.currentProvider {
    case .apple: appleMapView
    case .google: googleMapView
    }
}
```

---

## 💰 Cost Considerations

### Apple Maps
- ✅ **Free** - No usage limits
- ✅ **No billing** required
- ✅ **Privacy-focused** - Runs locally

### Google Maps
- 💰 **Charges per API call** after free tier
- **Free tier:** $200 credit/month (~28,000 requests)
- **Pricing (as of 2024):**
  - Places Autocomplete: $2.83 per 1,000 requests
  - Geocoding: $5.00 per 1,000 requests
  - Directions: $5.00 per 1,000 requests

**Monitoring:**
- Check usage in [Google Cloud Console](https://console.cloud.google.com/)
- Set up billing alerts
- Consider caching frequently used results

---

## 📚 Code Examples

### Example 1: Search with Autocomplete

```swift
struct LocationSearchView: View {
    @StateObject private var providerService = MapProviderService.shared
    @State private var query = ""

    var mapService: AnyMapService {
        providerService.currentService
    }

    var body: some View {
        VStack {
            TextField("Search", text: $query)
                .onChange(of: query) { newValue in
                    mapService.search(query: newValue)
                }

            List(mapService.searchResults) { result in
                Button(action: {
                    selectResult(result)
                }) {
                    VStack(alignment: .leading) {
                        Text(result.title)
                        Text(result.subtitle)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }

    func selectResult(_ result: LocationSearchResult) {
        Task {
            do {
                let (coordinate, name) = try await mapService.getCoordinate(for: result)
                print("Selected: \(name) at \(coordinate)")
            } catch {
                print("Error: \(error)")
            }
        }
    }
}
```

### Example 2: Calculate and Display Route

```swift
struct RouteView: View {
    @StateObject private var providerService = MapProviderService.shared
    @State private var route: RouteResult?

    var mapService: AnyMapService {
        providerService.currentService
    }

    func calculateRoute(from pickup: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        Task {
            do {
                let result = try await mapService.calculateRoute(from: pickup, to: destination)
                route = result

                let miles = result.distance / 1609.34
                let minutes = result.expectedTravelTime / 60
                print("Route: \(miles) miles, \(minutes) minutes")
            } catch let error as MapServiceError {
                print("Map error: \(error.localizedDescription)")
            } catch {
                print("Unexpected error: \(error)")
            }
        }
    }
}
```

### Example 3: Settings Screen

```swift
struct MapSettingsView: View {
    @StateObject private var providerService = MapProviderService.shared

    var body: some View {
        List {
            Section("Map Provider") {
                ForEach(MapProvider.allCases, id: \.self) { provider in
                    Button(action: {
                        let result = providerService.switchTo(provider: provider)
                        handleResult(result, provider: provider)
                    }) {
                        HStack {
                            Image(systemName: provider.icon)
                            Text(provider.displayName)
                            Spacer()
                            if providerService.currentProvider == provider {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                            if !providerService.isProviderAvailable(provider) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }

            Section("Current Provider") {
                HStack {
                    Text("Provider")
                    Spacer()
                    Text(providerService.currentProvider.displayName)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Map Settings")
    }

    func handleResult(_ result: Result<Void, MapServiceError>, provider: MapProvider) {
        switch result {
        case .success:
            showToast("Switched to \(provider.displayName)")
        case .failure(let error):
            showAlert(error.localizedDescription)
        }
    }
}
```

---

## 🎓 Advanced Topics

### Custom Map Service Wrappers

Create domain-specific wrappers:

```swift
class RestaurantMapService {
    private let mapService: AnyMapService

    init(mapService: AnyMapService = MapProviderService.shared.currentService) {
        self.mapService = mapService
    }

    func searchRestaurants(near coordinate: CLLocationCoordinate2D) async throws -> [Restaurant] {
        mapService.updateSearchRegion(center: coordinate, radiusMiles: 5.0)
        mapService.search(query: "restaurant")

        // Process results...
        return restaurants
    }
}
```

### Fallback Provider Pattern

Automatically fall back to Apple Maps if Google fails:

```swift
class FallbackMapService: MapService {
    private var primaryService: AnyMapService
    private let fallbackService: AnyMapService

    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String) {
        do {
            return try await primaryService.geocode(address: address)
        } catch let error as MapServiceError where error.shouldFallback {
            print("⚠️ Primary service failed, using fallback")
            return try await fallbackService.geocode(address: address)
        }
    }
}
```

### Caching Layer

Add caching to reduce API calls:

```swift
class CachedMapService: MapService {
    private let underlyingService: AnyMapService
    private var geocodeCache: [String: (CLLocationCoordinate2D, String)] = [:]

    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String) {
        if let cached = geocodeCache[address] {
            return cached
        }

        let result = try await underlyingService.geocode(address: address)
        geocodeCache[address] = result
        return result
    }
}
```

---

## 📖 Related Documentation

- **JUNIOR_ENGINEER_GUIDE.md** - Comprehensive app architecture guide
- **ARCHITECTURE.md** - Overall app architecture
- **ADAPTER_PATTERN_GUIDE.md** - Design pattern details

---

## 🎉 Summary

The refactored maps architecture provides:

✅ **Simplicity** - One protocol instead of three
✅ **Maintainability** - Single source of truth
✅ **Extensibility** - Add providers by implementing one interface
✅ **Safety** - Graceful error handling, no crashes
✅ **Testability** - Easy to mock and test
✅ **User-Friendly** - Automatic persistence, intelligent availability checks

**The Bottom Line:** Adding a new map provider now takes minutes, not days!

---

**Questions or issues?** Check the code in `Model S/Core/Services/Map/` or create an issue on GitHub.
