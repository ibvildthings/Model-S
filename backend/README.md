# Model S Backend Server

Automatic driver simulation server for testing the Model S iOS app.

## Features

✅ **Automatic Driver Matching** - Finds nearest available driver from a pool of 10 simulated drivers
✅ **Real-time Position Updates** - WebSocket connection for live driver location
✅ **Driver Movement Simulation** - Smoothly animates driver from their location → pickup → destination
✅ **State Management** - Automatically transitions through ride states (searching → assigned → enRoute → arriving → inProgress → completed)
✅ **No Database Required** - In-memory storage for easy testing
✅ **CORS Enabled** - Works with iOS simulator and device

## Quick Start

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Start Server

```bash
npm start
```

You should see:

```
🚀 Server running on http://localhost:3000
📡 WebSocket available at ws://localhost:3000

💡 Ready to receive ride requests from iOS app!

👥 Active drivers: 10
   - Michael Chen (Toyota Camry) - 4.8⭐
   - Sarah Johnson (Tesla Model 3) - 4.9⭐
   - David Martinez (Honda Accord) - 4.7⭐
   ... and 7 more
```

### 3. Configure iOS App

The app uses `http://localhost:3000` by default (fine for the simulator).
To point it elsewhere, set environment variables on the Xcode scheme
(Edit Scheme → Run → Arguments → Environment Variables), read by
`BackendConfiguration.swift`:

| Variable | Example | Effect |
|---|---|---|
| `BACKEND_BASE_URL` | `http://192.168.1.20:3000` | Backend for rider and driver flows |
| `USE_MOCK_BACKEND` | `1` | Rider flow uses an in-app mock, no server needed |

**For physical devices:** Find your computer's IP address:
- Mac: System Preferences → Network
- Use that IP instead of `localhost`

### 4. Test It!

1. Run the iOS app
2. Request a ride
3. Watch the server logs to see:
   - Driver matching
   - Position updates
   - State transitions

## API Endpoints

### POST /api/rides/request

Request a new ride with automatic driver assignment.

**Request:**
```json
{
  "pickup": {
    "lat": 37.7749,
    "lng": -122.4194,
    "address": "123 Main St, San Francisco, CA"
  },
  "destination": {
    "lat": 37.8049,
    "lng": -122.4294,
    "address": "456 Market St, San Francisco, CA"
  }
}
```

**Response:**
```json
{
  "rideId": "550e8400-e29b-41d4-a716-446655440000",
  "status": "searching",
  "pickup": { ... },
  "destination": { ... },
  "createdAt": "2024-01-15T10:30:00.000Z"
}
```

The server will automatically:
1. Search for nearest driver (2-4 seconds)
2. Assign driver and send update via WebSocket
3. Start simulating driver movement
4. Transition through states automatically

### GET /api/rides/:rideId

Get current ride status.

**Response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "enRoute",
  "pickup": { ... },
  "destination": { ... },
  "driver": {
    "id": "driver_1",
    "name": "Michael Chen",
    "vehicleType": "Standard",
    "vehicleModel": "Toyota Camry",
    "licensePlate": "ABC-1234",
    "rating": 4.8,
    "location": {
      "lat": 37.7755,
      "lng": -122.4180
    }
  },
  "estimatedArrival": 300,
  "createdAt": "2024-01-15T10:30:00.000Z",
  "updatedAt": "2024-01-15T10:30:15.000Z"
}
```

### POST /api/rides/:rideId/cancel

Cancel an active ride.

**Response:**
```json
{
  "success": true,
  "message": "Ride cancelled",
  "ride": { ... }
}
```

### GET /api/drivers

View all simulated drivers (debugging).

**Response:**
```json
{
  "count": 10,
  "drivers": [
    {
      "id": "driver_1",
      "name": "Michael Chen",
      "vehicleType": "Standard",
      "vehicleModel": "Toyota Camry",
      "licensePlate": "ABC-1234",
      "rating": 4.8,
      "location": { "lat": 37.7749, "lng": -122.4194 },
      "available": true
    },
    ...
  ]
}
```

## WebSocket Connection

For real-time updates, connect to `ws://localhost:3000`.

### Subscribe to Ride Updates

**Send:**
```json
{
  "type": "subscribe",
  "rideId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Receive (ride update):**
```json
{
  "type": "rideUpdate",
  "data": {
    "id": "550e8400-...",
    "status": "enRoute",
    "driver": { ... },
    ...
  }
}
```

**Receive (driver position):**
```json
{
  "type": "driverPosition",
  "data": {
    "rideId": "550e8400-...",
    "driver": {
      "id": "driver_1",
      "location": {
        "lat": 37.7755,
        "lng": -122.4180
      }
    },
    "status": "enRoute",
    "distanceRemaining": 450,
    "progress": 0.65
  }
}
```

Position updates are sent every **500ms** during active rides.

## Ride State Flow

The server automatically transitions rides through these states:

```
searching
    ↓ (2-4 seconds)
assigned
    ↓ (driver starts moving)
enRoute
    ↓ (when < 100m from pickup)
arriving
    ↓ (driver reaches pickup)
inProgress
    ↓ (driver moving to destination)
approachingDestination
    ↓ (driver reaches destination)
completed
```

## Driver Simulation

### Movement

- Drivers move smoothly from their current location → pickup → destination
- Speed is accelerated for testing (20-30 seconds per leg)
- Updates sent every 500ms
- Position calculated using linear interpolation

### Matching Algorithm

1. Filters for available drivers (not currently on a ride)
2. Calculates distance to each using Haversine formula
3. Selects nearest driver
4. Assigns and marks as unavailable

### After Ride Completion

- Driver is marked as available again
- Returns to the driver pool
- Ready for next ride

## Configuration

Edit `services/driverPool.js` to customize:

```javascript
// Number of drivers
const driverNames = [...]; // Add/remove names

// Starting area (default: San Francisco)
const sfCenter = { lat: 37.7749, lng: -122.4194 };
const radiusMeters = 10000; // 10 km

// Speed (in driverSimulator.js)
const durationSeconds = 20 + Math.random() * 10; // 20-30 seconds
```

## Development Mode

For auto-restart on file changes:

```bash
npm run dev  # Uses nodemon
```

## Testing the API

### Using curl:

```bash
# Request a ride
curl -X POST http://localhost:3000/api/rides/request \
  -H "Content-Type: application/json" \
  -d '{
    "pickup": {"lat": 37.7749, "lng": -122.4194, "address": "San Francisco"},
    "destination": {"lat": 37.8049, "lng": -122.4094, "address": "Oakland"}
  }'

# Get ride status
curl http://localhost:3000/api/rides/{RIDE_ID}

# View all drivers
curl http://localhost:3000/api/drivers

# Cancel ride
curl -X POST http://localhost:3000/api/rides/{RIDE_ID}/cancel
```

### Using Postman:

Import the collection (create one with above endpoints) or test manually.

## Project Layout

```
app.js            Express app: middleware + HTTP routes (no port, no sockets)
server.js         Starts HTTP + WebSocket servers, wires broadcasts
routes/           rides.js (rider API), drivers.js (driver app API)
store/            In-memory state (rideStore, driverStore) – swap for a DB
services/         driverPool, driverMatcher, driverSimulator, rideRequestSimulator
models/           Ride, Driver
utils/geoUtils.js Distance, ETA, interpolation helpers
```

## Tests

```bash
npm test                # all suites
npx jest routes         # HTTP route tests only (supertest, simulations mocked)
```

> The iOS app currently **polls** `GET /api/rides/:rideId` every second.
> The WebSocket endpoint below is available but not yet used by the app.

## Troubleshooting

### "Cannot connect to localhost:3000" from iOS device

- **Cause:** Device can't reach your computer's localhost
- **Fix:** Use your computer's IP address instead
  - Mac: `ifconfig | grep "inet "`
  - Windows: `ipconfig`
  - Set `BACKEND_BASE_URL=http://192.168.x.x:3000` on the Xcode scheme

### "No drivers available"

- **Cause:** All 10 drivers are currently assigned
- **Fix:** Wait for rides to complete or restart server

### WebSocket not connecting

- **Cause:** Might be using wrong protocol or port
- **Fix:** Ensure using `ws://` not `wss://` for local development

### Driver not moving

- **Cause:** Simulation might have stopped
- **Fix:** Check server logs for errors, restart if needed

## Architecture

```
backend/
├── server.js                 # Express + WebSocket server
├── routes/
│   └── rides.js             # Ride endpoints
├── services/
│   ├── driverPool.js        # Pool of simulated drivers
│   ├── driverMatcher.js     # Matching algorithm
│   └── driverSimulator.js   # Movement simulation
├── models/
│   ├── Driver.js            # Driver model
│   └── Ride.js              # Ride model
└── utils/
    └── geoUtils.js          # Distance/interpolation functions
```

## Next Steps

### To Deploy in Production:

1. **Add Database**
   - Replace in-memory storage with PostgreSQL/MongoDB
   - Store rides, drivers, users

2. **Add Authentication**
   - JWT tokens
   - User registration/login

3. **Add Real Driver Integration**
   - Driver app to update real positions
   - Driver acceptance flow
   - Driver notifications

4. **Add Payment Processing**
   - Stripe/Square integration
   - Fare calculation
   - Payment methods

5. **Scale WebSocket**
   - Use Redis pub/sub for multiple server instances
   - Load balancing

## License

MIT

## Support

For issues or questions:
1. Check server logs for errors
2. Verify iOS app is using correct URL
3. Test endpoints with curl
4. Review this README

---

**Ready to test your iOS app!** 🚗💨

Just run `npm start` and start requesting rides from your iOS app.
