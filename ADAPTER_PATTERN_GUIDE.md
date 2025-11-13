# Map Service Adapter Pattern Guide

## Overview

The app now uses an adapter pattern to abstract map provider APIs. This makes it easy to switch between Apple Maps and Google Maps (or add other providers in the future).

## Architecture

### Protocols (Provider-Agnostic Interfaces)

Located in `MapServiceProtocols.swift`:

1. **LocationSearchService** - Autocomplete/search
   - Apple: Uses `MKLocalSearchCompleter`
   - Google: Would use Places Autocomplete API

2. **GeocodingService** - Address ↔ Coordinates
   - Apple: Uses `CLGeocoder`
   - Google: Would use Geocoding API

3. **RouteCalculationService** - Route planning
   - Apple: Uses `MKDirections`
   - Google: Would use Directions API

### Factory Pattern

`MapServiceFactory` creates service instances based on configuration:

```swift
let factory = MapServiceFactory.shared

// Configure for Apple Maps (current default)
factory.configure(with: MapServiceConfiguration(provider: .apple, apiKey: nil))

// Future: Configure for Google Maps
factory.configure(with: MapServiceConfiguration(provider: .google, apiKey: "YOUR_KEY"))
```

## Current Implementation

### Apple Maps Services (`AppleMapServices.swift`)

- **AppleLocationSearchService**: Wraps MKLocalSearchCompleter
- **AppleGeocodingService**: Wraps CLGeocoder
- **AppleRouteCalculationService**: Wraps MKDirections

All implement their respective protocols, returning provider-agnostic data types.

### Components Using Adapters

1. **RideLocationCardWithSearch**: Uses `LocationSearchService` via factory
2. **RideRequestViewModel**: Uses `GeocodingService` and `RouteCalculationService`
3. **LocationSearchSuggestionsView**: Displays generic `LocationSearchResult` objects

## How to Add Google Maps

### Step 1: Add Google Maps SDK

```bash
# Add to Podfile or Package.swift
pod 'GoogleMaps'
pod 'GooglePlaces'
```

### Step 2: Create Google Service Implementations

Create `GoogleMapServices.swift`:

```swift
import GoogleMaps
import GooglePlaces

@MainActor
class GoogleLocationSearchService: NSObject, LocationSearchService {
    @Published var searchResults: [LocationSearchResult] = []
    @Published var isSearching = false

    private let placesClient: GMSPlacesClient
    private var sessionToken = GMSAutocompleteSessionToken()

    init(apiKey: String) {
        GMSPlacesClient.provideAPIKey(apiKey)
        self.placesClient = GMSPlacesClient.shared()
        super.init()
    }

    func search(query: String) {
        // Use GMSAutocompleteFilter
        let filter = GMSAutocompleteFilter()
        filter.types = ["address"]

        placesClient.findAutocompletePredictions(
            fromQuery: query,
            filter: filter,
            sessionToken: sessionToken
        ) { results, error in
            // Convert to LocationSearchResult
        }
    }

    func updateSearchRegion(center: CLLocationCoordinate2D, radiusMiles: Double) {
        // Set location bias for autocomplete
    }

    func getCoordinate(for result: LocationSearchResult) async throws -> (CLLocationCoordinate2D, String) {
        // Fetch place details using place ID
    }
}

class GoogleGeocodingService: GeocodingService {
    private let geocoder = GMSGeocoder()

    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String) {
        // Use GMSGeocoder
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String {
        // Use GMSGeocoder reverseGeocodeCoordinate
    }
}

class GoogleRouteCalculationService: RouteCalculationService {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult {
        // Call Google Directions API
        // Parse response
        // Return RouteResult with GMSPolyline in polyline field
    }
}
```

### Step 3: Update Factory

In `MapServiceProtocols.swift`, update factory methods:

```swift
func createLocationSearchService() -> any LocationSearchService {
    switch configuration.provider {
    case .apple:
        return AppleLocationSearchService()
    case .google:
        return GoogleLocationSearchService(apiKey: configuration.apiKey!)
    }
}
```

### Step 4: Update Map View

The map display (`RideMapView`) currently uses SwiftUI's `Map` which is Apple-only. For Google Maps, you'd need:

```swift
// Create GoogleMapView wrapper
struct GoogleMapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(...)
        let mapView = GMSMapView(frame: .zero, camera: camera)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Update markers, polyline, etc.
    }
}
```

Then conditionally show the right map:

```swift
if MapServiceFactory.shared.configuration.provider == .apple {
    RideMapView(viewModel: mapViewModel)
} else {
    GoogleMapView(viewModel: mapViewModel)
}
```

### Step 5: Handle Polyline Rendering

For route visualization:
- Apple: `MKPolyline` → `RouteLineView` (current implementation)
- Google: `GMSPolyline` → Directly rendered on `GMSMapView`

Update `MapViewModel` to store provider-agnostic route data:

```swift
@Published var routePolyline: Any? // MKPolyline or GMSPolyline
```

## Switching Providers at Runtime

```swift
// In your app configuration or settings
func switchToGoogleMaps() {
    MapServiceFactory.shared.configure(
        with: MapServiceConfiguration(
            provider: .google,
            apiKey: "YOUR_GOOGLE_API_KEY"
        )
    )

    // Recreate view models to use new services
    rideViewModel = RideRequestViewModel()
}
```

## Benefits of This Architecture

1. **Decoupling**: UI components don't know about map provider
2. **Testability**: Easy to mock services for testing
3. **Flexibility**: Switch providers via configuration
4. **Future-proof**: Add new providers (Mapbox, Here Maps) without changing UI
5. **Cost optimization**: Use different providers based on region or pricing

## Current Provider Comparison

| Feature | Apple Maps | Google Maps |
|---------|-----------|-------------|
| Autocomplete | MKLocalSearchCompleter | Places Autocomplete |
| Geocoding | CLGeocoder (free) | Geocoding API (paid) |
| Directions | MKDirections (free) | Directions API (paid) |
| Map Display | SwiftUI Map | GMSMapView |
| API Key | Not required | Required |
| Cost | Free | Usage-based pricing |

## Testing the Adapter

The app currently works with Apple Maps. All existing functionality is preserved:
- Address autocomplete (50-mile radius)
- Geocoding and reverse geocoding
- Route calculation with polyline
- Map display with markers

To verify: Run the app → "Order a ride" → Enter addresses → See route

No changes to user-facing features, just cleaner architecture under the hood!
