# Map Provider Guide

This guide explains how to use and switch between Apple Maps and Google Maps in the Model S app.

## Overview

The app supports both **Apple Maps** and **Google Maps** with seamless switching between providers. When you switch providers, both the map services (search, geocoding, routes) AND the visual map display change.

## Quick Start

### Option 1: Using MapProviderManager (Recommended)

```swift
import SwiftUI

// Switch to Apple Maps
MapProviderManager.shared.useAppleMaps()

// Switch to Google Maps
MapProviderManager.shared.useGoogleMaps()

// Toggle between providers
MapProviderManager.shared.toggleProvider()
```

### Option 2: Using Settings UI

Add the `MapProviderSettingsView` to your app:

```swift
NavigationLink("Map Settings") {
    MapProviderSettingsView()
}
```

### Option 3: Direct Configuration

```swift
// Configure at app launch
MapServiceFactory.shared.configure(with: .google)

// Or use Apple Maps
MapServiceFactory.shared.configure(with: .apple)
```

## Setup

### Apple Maps (No Setup Required)
✅ Works out of the box
✅ No API key needed
✅ Uses iOS built-in MapKit

### Google Maps (Requires API Key)

**Step 1: Get API Key**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable these APIs:
   - Places API
   - Geocoding API
   - Directions API
4. Create credentials → API Key
5. (Optional) Restrict key to your bundle ID

**Step 2: Add API Key to Code**

Edit `Model S/Core/Services/Map/MapServiceProtocols.swift`:

```swift
static let google = MapServiceConfiguration(
    provider: .google,
    apiKey: "YOUR_ACTUAL_API_KEY_HERE"  // Replace this
)
```

**Step 3 (Optional): Add Google Maps SDK**

For Google Maps visual display (not just services):

**Via CocoaPods:**
```ruby
pod 'GoogleMaps'
pod 'GooglePlaces'
```

**Via Swift Package Manager:**
```swift
dependencies: [
    .package(url: "https://github.com/googlemaps/ios-maps-sdk", from: "8.0.0")
]
```

**Initialize in App:**
```swift
import GoogleMaps

@main
struct Model_SApp: App {
    init() {
        GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## What Changes When You Switch

| Component | Apple Maps | Google Maps |
|-----------|------------|-------------|
| **Map Display** | Apple's map tiles | Google's map tiles (if SDK installed) |
| **Location Search** | MKLocalSearchCompleter | Google Places Autocomplete API |
| **Geocoding** | CLGeocoder | Google Geocoding API |
| **Route Calculation** | MKDirections | Google Directions API |
| **Polylines** | MKPolyline | CLLocationCoordinate2D array |

## Architecture

The app uses the **Adapter Pattern** for easy provider switching:

```
┌─────────────────────────────────────┐
│     RideMapView (UI Layer)          │
│  Switches between map views         │
└──────────────┬──────────────────────┘
               │
       ┌───────┴────────┐
       │                │
┌──────▼─────┐   ┌─────▼────────┐
│ Apple Maps │   │ Google Maps  │
│   Wrapper  │   │   Wrapper    │
└────────────┘   └──────────────┘
               │
┌──────────────▼──────────────────────┐
│    MapServiceFactory                 │
│  Creates appropriate service         │
└──────────────┬──────────────────────┘
               │
       ┌───────┴────────┐
       │                │
┌──────▼─────┐   ┌─────▼────────┐
│Apple       │   │Google        │
│Services    │   │Services      │
└────────────┘   └──────────────┘
```

## Examples

### Example 1: Switch at App Launch

```swift
@main
struct Model_SApp: App {
    init() {
        // Use Google Maps by default
        MapProviderManager.shared.useGoogleMaps()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Example 2: User Preference

```swift
struct SettingsView: View {
    @StateObject private var manager = MapProviderManager.shared

    var body: some View {
        Picker("Map Provider", selection: $manager.currentProvider) {
            Text("Apple Maps").tag(MapProvider.apple)
            Text("Google Maps").tag(MapProvider.google)
        }
    }
}
```

### Example 3: A/B Testing

```swift
// Randomly assign users to different providers
let useGoogle = Bool.random()
if useGoogle {
    MapProviderManager.shared.useGoogleMaps()
} else {
    MapProviderManager.shared.useAppleMaps()
}
```

## Testing

Run tests to verify both providers work:

```bash
xcodebuild test -scheme "Model S" -destination 'platform=iOS Simulator,name=iPhone 15'
```

Key test cases:
- ✅ Switch between providers
- ✅ Create services for each provider
- ✅ Type-erased wrapper works with both
- ✅ Map view displays correct provider
- ✅ Persistence of user preference

## Troubleshooting

### Google Maps not showing

**Problem:** Map display shows placeholder
**Solution:** Install Google Maps SDK (see Step 3 above)

### Google Maps services failing

**Problem:** Search/geocoding not working
**Solution:** Check API key in `MapServiceConfiguration.google`

### "API key required" error

**Problem:** Trying to use Google without API key
**Solution:** Add valid API key or switch to Apple Maps

### Map not updating after switch

**Problem:** UI doesn't reflect provider change
**Solution:** Ensure `MapProviderManager.shared` is used and view observes it

## Best Practices

1. **Default Provider:** Set in `MapServiceConfiguration.default`
2. **API Key Security:** Don't commit API keys to git (use environment variables in production)
3. **Error Handling:** Always check `MapProviderManager.shared.isGoogleMapsReady`
4. **User Preference:** Save choice with `MapProviderManager` (auto-saves to UserDefaults)
5. **Testing:** Test with both providers before release

## Cost Considerations

### Apple Maps
- ✅ Free
- ✅ No usage limits
- ✅ No billing required

### Google Maps
- 💰 Charges per API call after free tier
- Free tier: $200 credit/month (~28K free requests)
- Monitor usage in Google Cloud Console
- Consider rate limiting in production

## Support

For issues or questions:
- Check the code in `Model S/Core/Services/Map/`
- Review tests in `Model STests/MapServiceTests.swift`
- See adapter pattern guide: `ADAPTER_PATTERN_GUIDE.md`
