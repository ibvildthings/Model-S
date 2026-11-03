# Model S

**The ride-sharing app you can actually understand.**

---

## What is this?

Model S is a fully functional iOS ride-sharing app built with SwiftUI. It pairs a SwiftUI app with a small Node backend that simulates drivers, so you can follow a ride end to end on your machine.

**One app. Two modes.** Switch between being a rider or a driver with a tap.

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
- Live driver position and ETA (the app polls the backend every second)
- Automatic driver matching (real driver-app drivers first, simulated otherwise)
- Live ETA recalculation as the driver moves
- Graceful error handling
- Persistent user preferences

---

## Tech Stack

**iOS App**
- SwiftUI + Combine
- Views → coordinator/view model → flow controller (state machine) → services
- One source of truth per flow (`RideFlowController`, `DriverFlowController`)
- MapKit + Google Maps SDK (switchable at runtime)

**Backend**
- Node.js + Express
- Driver matching & simulation
- WebSocket endpoint for ride updates (not yet used by the app)

---

## Getting Started

### Prerequisites
- Xcode 16.4+
- Node.js 18+
- iOS 18.5+ device or simulator (the deployment target)

### Run the Backend

```bash
cd backend
npm install
npm start
```

Server runs on `http://localhost:3000`. Run `npm test` for the backend tests.

### Run the iOS App

1. Open `Model S.xcodeproj` in Xcode
2. Select your target device
3. Hit Run

On a physical device, or to run without the backend, set `BACKEND_BASE_URL` or `USE_MOCK_BACKEND=1` on the scheme (see [backend/README.md](backend/README.md#3-configure-ios-app)).

### Google Maps (Optional)

Want Google Maps instead of Apple Maps?

1. Get an API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Copy `Model S/Core/Configuration/Secrets.example.plist` to `Secrets.plist` and add the key (see [GOOGLE_MAPS_SETUP.md](GOOGLE_MAPS_SETUP.md))
3. Switch providers from the map or **Home → ⚙︎**

The app works fine with just Apple Maps — Google Maps is optional.

---

## Architecture

```
backend/               Node.js server (Express routes, in-memory stores, driver simulation)
Model S/
├── App/               App entry point
├── Core/              Configuration, logging, models, services (backend, maps, storage)
└── Features/
    ├── RideRequest/   Rider booking flow (screen → coordinator → RideFlowController)
    ├── DriverApp/     Driver experience (views → DriverViewModel → DriverFlowController)
    ├── Home/          Landing screen
    ├── RideHistory/   Past rides
    └── Settings/      Map provider settings
Model STests/          State machine and map service tests
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for how the pieces fit together.

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
