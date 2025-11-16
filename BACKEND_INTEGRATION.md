# Backend Integration Guide

The iOS app now connects to the real Node.js backend server for ride requests!

## 🎉 What's New

The app now uses `RideAPIClient` instead of `MockRideRequestService`:
- **Real HTTP requests** to backend server
- **Automatic polling** for driver assignment
- **Live driver data** from server simulation
- **Realistic driver behavior** - spawns 3-8km away

## 🚀 Quick Start

### 1. Start the Backend Server

```bash
cd backend
npm install  # First time only
npm start
```

You should see:
```
🚀 Server running on http://localhost:3000
📡 WebSocket available at ws://localhost:3000
✅ Initialized 10 simulated drivers (3-8km radius)
```

### 2. Run the iOS App

The app is **already configured** to use the backend:

```swift
// In RideFlowController.swift
self.rideService = RideRequestServiceFactory.shared
    .createRideRequestService(useMock: false)  // ← Using real backend!
```

### 3. Test It

1. Launch the iOS app (Simulator or Device)
2. Tap "Order a ride"
3. Select pickup and destination
4. Slide to confirm

**Watch the Xcode console:**
```
🌐 RideAPIClient initialized with baseURL: http://localhost:3000
📤 Requesting ride from backend...
   Pickup: 37.33233141, -122.0312186
   Destination: 37.3225885, -122.0235143
📥 Response status: 201
✅ Ride created: C2FD4735-DE5F-46EF-B750-48BD6AFC0118
   Status: searching
🔄 Starting to poll for driver assignment...
⏳ Waiting for driver... (attempt 1)
⏳ Waiting for driver... (attempt 2)
🚗 Driver info received:
   Name: Michael Chen
   Location: 37.7940, -122.4388  ← Driver's actual location (far away!)
   ETA: 382s
✅ Driver assigned after 3 attempts!
```

**Watch the Backend console:**
```
📱 New ride request: C2FD4735-DE5F-46EF-B750-48BD6AFC0118
   Pickup: 37.33233141, -122.0312186
   Destination: 37.3225885, -122.0235143
🔍 Searching for driver for ride C2FD4735...
🚗 Matched driver: Michael Chen (4234m away)
   Driver location: 37.7940, -122.4388
   Distance to pickup: 4234m
   ETA: 382s
✅ Driver Michael Chen assigned to ride C2FD4735
🎬 Starting simulation for ride C2FD4735 with driver Michael Chen
   Driver starting at: 37.7940, -122.4388  ← Far from pickup!
   Pickup location: 37.3323, -122.0312
   Destination: 37.3226, -122.0235
   Distance to pickup: 4234m
📡 Sent initial driver position
[Position updates every 500ms...]
```

## 🔧 Configuration

### Switch Between Mock and Real Backend

**To use REAL backend:**
```swift
// In RideFlowController.swift line 43
self.rideService = RideRequestServiceFactory.shared
    .createRideRequestService(useMock: false)
```

**To use MOCK (for testing without backend):**
```swift
self.rideService = RideRequestServiceFactory.shared
    .createRideRequestService(useMock: true)
```

### Change Backend URL

**For iOS Simulator:**
```swift
// Default - works for simulator
let service = RideRequestServiceFactory.shared
    .createRideRequestService(useMock: false)  // Uses http://localhost:3000
```

**For Physical Device:**
```swift
// Find your computer's IP address:
// Mac: System Preferences → Network
// Use that IP instead of localhost

let service = RideRequestServiceFactory.shared
    .createRideRequestService(
        useMock: false,
        baseURL: "http://192.168.1.100:3000"  // Your computer's IP
    )
```

## 📋 How It Works

### 1. Ride Request Flow

```
iOS App                          Backend Server
────────                         ──────────────
  │
  │  POST /api/rides/request
  ├──────────────────────────────►  Create ride with ID
  │                                 Status: "searching"
  │◄──────────────────────────────  Return ride ID
  │  { rideId: "abc-123", status: "searching" }
  │
  │  Poll every 1 second
  │  GET /api/rides/abc-123
  ├──────────────────────────────►  Check if driver assigned
  │◄──────────────────────────────  Still searching...
  │
  │  GET /api/rides/abc-123
  ├──────────────────────────────►  Driver matched!
  │◄──────────────────────────────  Return driver info
  │  { driver: { id, name, location, ... }, status: "assigned" }
  │
  │  Continue polling every 2s
  │  for status updates
  │
```

### 2. Driver Spawn Behavior

**Backend spawns drivers 3-8km away:**

```
        🚗 Driver spawns here
        (37.7940, -122.4388)
        4.2km northwest
            │
            │ ← Driver's route to pickup
            │
            ↓
        📍 Your pickup
        (37.3323, -122.0312)
            │
            │ ← Your ride route
            │
            ↓
        📍 Destination
        (37.3226, -122.0235)
```

**NOT like before (broken):**
```
        📍 Pickup
            ↓
        🚗 Driver spawns AT destination (wrong!)
        📍 Destination
```

### 3. Polling Strategy

The `RideAPIClient` uses smart polling:

- **Initial:** Poll every **1 second** until driver assigned (max 30 seconds)
- **After driver assigned:** Poll every **2 seconds** for status updates
- **Auto-cleanup:** Stops polling when ride is cancelled

## 🐛 Troubleshooting

### "Failed to connect to localhost"

**Cause:** Backend server not running

**Fix:**
```bash
cd backend
npm start
```

### "Cannot connect to server" (Physical Device)

**Cause:** Device can't reach `localhost` (localhost means the device itself)

**Fix:**
1. Find your computer's IP:
   ```bash
   # Mac
   ifconfig | grep "inet "
   # Look for something like 192.168.1.100
   ```

2. Update RideFlowController.swift:
   ```swift
   self.rideService = RideRequestServiceFactory.shared
       .createRideRequestService(
           useMock: false,
           baseURL: "http://192.168.1.100:3000"  // Your IP
       )
   ```

3. Make sure iPhone and Mac are on same WiFi network

### "Driver still spawns at destination"

**Cause:** App is still using mock service

**Check:** RideFlowController.swift line 43
```swift
// Should be:
createRideRequestService(useMock: false)  // ← FALSE = real backend

// NOT:
createRideRequestService(useMock: true)   // ← TRUE = mock
```

### Backend logs show driver far away, but iOS doesn't

**Cause:** WebSocket not implemented yet (coming soon!)

**Current behavior:**
- Backend sends driver's actual position in HTTP response
- iOS receives it via polling (every 1-2 seconds)
- Driver position updates work, just not real-time yet

**Coming soon:** WebSocket integration for real-time updates every 500ms

## 📊 API Endpoints Used

### POST /api/rides/request

**Request:**
```json
{
  "pickup": {
    "lat": 37.33233141,
    "lng": -122.0312186,
    "address": "Current Location"
  },
  "destination": {
    "lat": 37.3225885,
    "lng": -122.0235143,
    "address": "Sweet Maple"
  }
}
```

**Response:**
```json
{
  "rideId": "C2FD4735-DE5F-46EF-B750-48BD6AFC0118",
  "status": "searching",
  "pickup": { ... },
  "destination": { ... },
  "createdAt": "2024-01-15T10:30:00.000Z"
}
```

### GET /api/rides/:rideId

**Response (driver assigned):**
```json
{
  "id": "C2FD4735-DE5F-46EF-B750-48BD6AFC0118",
  "status": "assigned",
  "driver": {
    "id": "driver_1",
    "name": "Michael Chen",
    "vehicleType": "Standard",
    "vehicleModel": "Toyota Camry",
    "licensePlate": "ABC-1234",
    "rating": 4.8,
    "location": {
      "lat": 37.7940,
      "lng": -122.4388
    }
  },
  "estimatedArrival": 382,
  "pickup": { ... },
  "destination": { ... }
}
```

### POST /api/rides/:rideId/cancel

**Response:**
```json
{
  "success": true,
  "message": "Ride cancelled"
}
```

## 🎯 Next Steps

### Immediate

- [x] HTTP client for ride requests ✅
- [x] Polling for driver assignment ✅
- [x] Driver spawn 3-8km away ✅
- [ ] WebSocket for real-time updates (in progress)
- [ ] Driver route visualization on map (in progress)

### Future

- [ ] Authentication (JWT)
- [ ] Payment integration (Stripe)
- [ ] Push notifications
- [ ] Driver tracking with route polyline
- [ ] Ride history sync with backend
- [ ] User profile management

## 📝 Files Changed

```
Model S/
├── Core/Services/Backend/
│   ├── RideAPIClient.swift        # NEW - HTTP client
│   └── BackendModels.swift        # NEW - API models
└── Core/Services/RideRequest/
    └── RideRequestService.swift   # UPDATED - factory supports real API

Features/RideRequest/Controllers/
└── RideFlowController.swift       # UPDATED - uses real backend
```

## 🎉 Testing Checklist

- [ ] Backend server starts without errors
- [ ] iOS app connects to backend (check Xcode console for "RideAPIClient initialized")
- [ ] Ride request creates ride on backend (check backend logs)
- [ ] iOS polls for driver assignment (check Xcode console for "Waiting for driver...")
- [ ] Driver assigned after 2-4 seconds (check both consoles)
- [ ] Driver info appears in iOS app
- [ ] Driver location is FAR from pickup (not at destination!)
- [ ] Backend logs show driver at 3-8km distance

---

**You're all set!** The app now uses the real backend with realistic driver spawning. 🚗💨

Run `npm start` in the backend directory and test your ride requests!
