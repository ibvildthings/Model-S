# Model S

**The ride-sharing app you can actually understand.**

![App Demo](screenshots/demo.gif)
<!-- TODO: Add demo gif showing rider booking a ride -->

---

## What is this?

Model S is a fully functional iOS ride-sharing app built with SwiftUI. It's not a tutorial project with TODO comments everywhere — it's the real deal with real architecture patterns used by the big guys.

**One app. Two modes.** Switch between being a rider or a driver with a tap.

![Rider and Driver Mode](screenshots/dual-mode.png)
<!-- TODO: Add side-by-side screenshot of rider and driver home screens -->

---

## Features

### As a Rider
- Book rides with an interactive map
- Watch your driver approach in real-time
- Slide-to-confirm (yes, like that app)
- View ride history
- Choose between Apple Maps or Google Maps

### As a Driver
- Go online/offline
- Receive ride offers with pickup details
- Navigate to pickup and dropoff
- Complete rides and see summaries

### Under the Hood
- Real-time WebSocket updates
- Automatic driver matching
- Live ETA recalculation as the driver moves
- Graceful error handling
- Persistent user preferences

---

## Screenshots

| Booking a Ride | Driver View | Live Tracking |
|----------------|-------------|---------------|
| ![Booking](screenshots/booking.png) | ![Driver](screenshots/driver.png) | ![Tracking](screenshots/tracking.png) |
<!-- TODO: Add actual screenshots -->

---

## Tech Stack

**iOS App**
- SwiftUI + Combine
- MVVM + Coordinator pattern
- Redux-like state management
- MapKit + Google Maps SDK (switchable at runtime)

**Backend**
- Node.js + Express
- WebSocket for real-time stuff
- Driver matching & simulation

---

## Getting Started

### Prerequisites
- Xcode 15+
- Node.js 18+
- iOS 18+ device or simulator

### Run the Backend

```bash
cd backend
npm install
npm start
```

Server runs on `http://localhost:3000`

### Run the iOS App

1. Open `Model S.xcodeproj` in Xcode
2. Select your target device
3. Hit Run

### Google Maps (Optional)

Want Google Maps instead of Apple Maps?

1. Get an API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Add it to `SecretsManager.swift`
3. Switch providers in Settings

The app works fine with just Apple Maps — Google Maps is optional.

---

## Architecture

```
Model S/
├── backend/           # Node.js server
├── Model S/
│   ├── Core/          # Shared stuff (state, services, DI)
│   └── Features/      # Independent feature modules
│       ├── RideRequest/   # Rider booking flow
│       ├── DriverApp/     # Driver experience
│       ├── Home/          # Landing screen
│       ├── RideHistory/   # Past rides
│       └── Settings/      # User prefs
```

Check out the `/Documentation` folder for deep dives on:
- Architecture patterns
- Map provider setup
- Backend integration
- Onboarding guide for new devs

---

## Why "Model S"?

Because every good project needs a codename. And this one ships.

---

## Contributing

Found a bug? Want to add a feature? PRs are welcome.

1. Fork it
2. Create your branch (`git checkout -b feature/cool-thing`)
3. Commit your changes
4. Push and open a PR

---

## License

MIT — do whatever you want with it.

---

**Built with SwiftUI, caffeine, and questionable life choices.**
