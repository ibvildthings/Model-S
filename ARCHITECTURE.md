# Architecture

This describes the code as it runs. Keep it in sync when the structure changes.

## Overview

```
iOS app (SwiftUI)                                   Node backend (backend/)
─────────────────                                   ───────────────────────
HomeView
 ├─ RideRequestScreen ── RideRequestCoordinator
 │                          ├─ RideFlowController ── RideAPIClient ──HTTP──▶ routes/rides.js
 │                          │    └─ RideStateMachine                 (poll 1s)   └─ store/rideStore
 │                          └─ MapViewModel (pins, routes, region)              └─ services/driverSimulator
 ├─ DriverAppView ─ DriverViewModel
 │                    └─ DriverFlowController ── DriverAPIClient ──HTTP──▶ routes/drivers.js
 │                         └─ DriverStateMachine                          └─ store/driverStore
 ├─ RideHistoryView ── RideHistoryStore (UserDefaults)
 └─ MapProviderSettingsView ─┐
                             MapProviderService ── AnyMapService (Apple | Google)
```

## iOS app (`Model S/`)

### Layers

| Layer | Responsibility | Examples |
|---|---|---|
| **Views** | Render state, forward user intents. No business logic. | `RideRequestScreen`, `RideStatusBanner`, `DriverHomeView` |
| **Coordinator / ViewModel** | Adapt a flow controller to views; derive presentation state. | `RideRequestCoordinator`, `MapViewModel`, `DriverViewModel` |
| **Flow controllers** | Own a flow's state; the only place state changes. Validated by a state machine. | `RideFlowController` + `RideStateMachine`, `DriverFlowController` + `DriverStateMachine` |
| **Services** | I/O behind protocols: backend, maps, persistence. | `RideRequestService` (`RideAPIClient`, `MockRideRequestService`), `MapService`, `RideHistoryStore` |

### Rider flow: one source of truth

`RideFlowController.currentState` (a `RideState` enum) is the **only** owner of
pickup, destination, route, driver and ride status. Data flows one way:

```
user intent ─▶ RideRequestCoordinator.selectLocation(...)
             ─▶ RideFlowController.updatePickup / updateDestination / requestRide
             ─▶ RideStateMachine validates transition ─▶ currentState
             ─▶ RideRequestCoordinator.handleStateChange(state) projects onto MapViewModel
```

`MapViewModel` is presentation-only (pins, polylines, region, user GPS). Views
never write pickup/destination to it directly.

Once a ride is requested, `RideFlowController` polls `GET /api/rides/:id`
every second. The backend's status drives state transitions; the driver's
position and ETA are published separately (`realTimeDriverLocation`,
`realTimeETA`) so they don't create a new state every second.

> `@Published` emits in `willSet`. Subscribers must use the value they are given,
> not re-read the property (see `RideRequestCoordinator.handleStateChange`).

### Map providers

- `MapProviderService.shared` is the single owner of the selected provider and
  the only reader/writer of the `selectedMapProvider` preference.
- It vends `currentService: AnyMapService`, a type-erased `MapService`
  (search, geocode, reverse-geocode, route) backed by `AppleMapService` or
  `GoogleMapService`. Those compose the per-capability services in
  `AppleMapServices.swift` / `GoogleMapServices.swift`.
- Switching providers creates a new service, so consumers read
  `MapProviderService.shared.currentService` at call time and do not cache it.
- Google Maps is enabled only when `Secrets.plist` has a `GoogleMapsAPIKey`
  (see `GOOGLE_MAPS_SETUP.md`); otherwise Apple Maps is used.

### Configuration

| What | Where |
|---|---|
| Backend URL, mock vs real backend | `Core/Configuration/BackendConfiguration.swift` (scheme env vars `BACKEND_BASE_URL`, `USE_MOCK_BACKEND`) |
| Google Maps key | `Core/Configuration/Secrets.plist` (gitignored; template `Secrets.example.plist`) |
| Rider UI options | `Core/Models/RideRequestConfiguration.swift` |
| Map/timing constants | `Core/Utilities/Constants.swift` |

### Logging

Use `AppLog.debug/info/warning/error(...)` (an `os.Logger` wrapper, category =
calling file), not `print`. Filter by subsystem in Console.app.

### Tests (`Model STests/`)

- `RideStateMachineTests`, `DriverStateMachineTests`: transition rules
- `MapServiceTests`: provider selection, unified and component map services

## Backend (`backend/`)

See `backend/README.md` for endpoints and setup.

- `app.js` is the Express app (routes only), so tests use it without a port.
  `server.js` adds the HTTP listener and the WebSocket server.
- `store/` holds all in-memory state behind small modules. Replace them with a
  database without touching routes.
- When a rider requests a ride, the nearest driver **logged in through the
  driver app** gets an offer (30s timeout). Otherwise `driverMatcher` assigns a
  simulated driver and `driverSimulator` moves it along a route.
- A WebSocket endpoint (`subscribe` by `rideId`) broadcasts ride updates and
  simulated driver positions. The iOS app does not use it yet; it polls.

Tests: `npm test` (geo utils, matcher, HTTP routes via supertest).
