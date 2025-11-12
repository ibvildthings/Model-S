# RideRequestView Component

A beautiful, reusable SwiftUI component that replicates an Uber-style ride request experience with an interactive map, location inputs, and slide-to-confirm interaction.

![iOS](https://img.shields.io/badge/iOS-18.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green.svg)

## Features

- 🗺️ **Interactive Map** - MapKit integration with user location tracking
- 📍 **Custom Pins** - Animated pickup and destination pins with custom colors
- 💳 **Glassmorphic Card** - Beautiful floating input panel with blur effect
- 👆 **Slide to Confirm** - Interactive slider with haptic feedback
- 🎨 **Fully Customizable** - Configure colors, text, and map styles
- ♿ **Accessible** - Complete VoiceOver support with labels and hints
- 🌗 **Theme Support** - Automatic light/dark mode adaptation

## Requirements

- iOS 18.0+
- Xcode 16.0+
- Swift 5.9+

## Installation

### Direct Integration

1. Copy the following files into your project:
   - `Models.swift`
   - `MapViewModel.swift`
   - `RideMapView.swift`
   - `RideLocationCard.swift`
   - `RideConfirmSlider.swift`
   - `RideRequestView.swift`
   - `RideRequestConfiguration.swift`

2. Add location permissions to your project settings:
   - Open your Xcode project settings
   - Go to Build Settings
   - Add `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` with a description

## Usage

### Basic Usage

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        RideRequestView(
            onPickupSelected: { location in
                print("Pickup: \(location)")
            },
            onDestinationSelected: { location in
                print("Destination: \(location)")
            },
            onConfirmRide: {
                print("Ride confirmed!")
                // Handle ride request
            }
        )
    }
}
```

### Custom Configuration

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        // Create custom configuration
        var config = RideRequestConfiguration()
        config.accentColor = .purple
        config.pickupPinColor = .orange
        config.destinationPinColor = .red
        config.sliderText = "Swipe to Confirm"
        config.cardTitle = "Book your ride"

        return RideRequestView(
            configuration: config,
            onPickupSelected: { location in
                print("Pickup: \(location)")
            },
            onDestinationSelected: { location in
                print("Destination: \(location)")
            },
            onConfirmRide: {
                print("Ride confirmed!")
            }
        )
    }
}
```

## Configuration Options

`RideRequestConfiguration` provides the following customization options:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `accentColor` | `Color` | `.blue` | Accent color for slider and interactive elements |
| `pickupPinColor` | `Color` | `.green` | Color for pickup location pin |
| `destinationPinColor` | `Color` | `.blue` | Color for destination location pin |
| `sliderText` | `String` | `"Slide to Request"` | Text displayed on the slider |
| `requestingText` | `String` | `"Requesting Ride..."` | Text shown when requesting |
| `findingDriverText` | `String` | `"Finding your driver..."` | Status banner text |
| `mapStyle` | `MapStyle` | `.standard(elevation: .flat, emphasis: .muted)` | Map appearance style |
| `defaultPickupText` | `String` | `"Current Location"` | Default pickup field text |
| `destinationPlaceholder` | `String` | `"Where to?"` | Destination field placeholder |
| `cardTitle` | `String` | `"Plan your ride"` | Location card header text |

## Component Architecture

```
RideRequestView (Main Component)
├── RideMapView (Map with pins)
│   ├── MapViewModel (Location management)
│   └── PinView (Custom pin annotations)
├── RideLocationCard (Input panel)
│   ├── Pickup text field
│   └── Destination text field
└── RideConfirmSlider (Confirmation control)
    └── Haptic feedback
```

## State Management

The component manages four states internally:

- `selectingPickup` - User is entering pickup location
- `selectingDestination` - User is entering destination
- `routeReady` - Both locations set, slider visible
- `rideRequested` - Ride confirmed, showing status

## Callbacks

### onPickupSelected

Called when the pickup location text changes.

```swift
onPickupSelected: { location in
    // Update your backend or local state
}
```

### onDestinationSelected

Called when the destination location text changes.

```swift
onDestinationSelected: { location in
    // Update your backend or local state
}
```

### onConfirmRide

Called when the user completes the slide-to-confirm gesture.

```swift
onConfirmRide: {
    // Submit ride request to your backend
}
```

## Accessibility

All components include comprehensive accessibility support:

- **Map**: Labeled as "Ride request map"
- **Pins**: Announced with type (pickup/destination)
- **Text Fields**: Clear labels and hints for input
- **Slider**: Contextual labels that update with state

## Haptic Feedback

The component provides tactile feedback at key moments:

- Light impact when pins are placed
- Light impact at 50% slider progress
- Success notification when ride is confirmed

## Examples

### Change Map Style

```swift
var config = RideRequestConfiguration()
config.mapStyle = .standard(elevation: .realistic)
```

### Custom Branding

```swift
var config = RideRequestConfiguration()
config.accentColor = Color(hex: "#FF0000")
config.pickupPinColor = Color(hex: "#00FF00")
config.destinationPinColor = Color(hex: "#0000FF")
config.sliderText = "Book Now"
config.cardTitle = "Your Journey"
```

## Known Limitations

- Map pin dragging is not yet implemented
- Route visualization is placeholder (no actual routing)
- Location permissions must be configured in project settings

## Future Enhancements

Planned features for future versions:

- ETA and fare estimates
- Driver search animation
- Driver card with details
- Real route calculation with MapKit Directions
- Search suggestions for locations
- Recent locations history

## License

This component is part of the Model S project.

## Support

For issues or questions, please refer to the project repository.

---

Built with ❤️ using SwiftUI and MapKit
