/**
 * Ride Request Simulator
 * Generates simulated ride requests for driver app testing
 */

// Predefined locations around San Francisco for realistic ride requests
const PICKUP_LOCATIONS = [
  { lat: 37.7749, lng: -122.4194, address: 'Downtown San Francisco' },
  { lat: 37.8044, lng: -122.2712, address: 'Oakland City Center' },
  { lat: 37.7955, lng: -122.3937, address: 'Emeryville Marina' },
  { lat: 37.8715, lng: -122.2730, address: 'Berkeley Campus' },
  { lat: 37.7577, lng: -122.4376, address: 'Golden Gate Park' },
  { lat: 37.8080, lng: -122.4177, address: 'Fisherman\'s Wharf' },
  { lat: 37.7694, lng: -122.4862, address: 'Sunset District' },
  { lat: 37.7599, lng: -122.3934, address: 'Mission District' }
];

const DESTINATION_LOCATIONS = [
  { lat: 37.7897, lng: -122.3972, address: 'San Francisco Airport' },
  { lat: 37.8024, lng: -122.4058, address: 'Pier 39' },
  { lat: 37.7955, lng: -122.3937, address: 'Ferry Building' },
  { lat: 37.7694, lng: -122.4862, address: 'Ocean Beach' },
  { lat: 37.8199, lng: -122.4783, address: 'Golden Gate Bridge Vista' },
  { lat: 37.8715, lng: -122.2730, address: 'UC Berkeley' },
  { lat: 37.8044, lng: -122.2712, address: 'Jack London Square' },
  { lat: 37.7749, lng: -122.4194, address: 'Union Square' }
];

// Active simulators for each driver
const activeSimulators = new Map(); // driverId -> interval

/**
 * Start generating simulated ride requests for a driver
 */
function startSimulation(driverId, onRideRequest) {
  // Don't start if already running
  if (activeSimulators.has(driverId)) {
    console.log(`⚠️ Ride request simulator already running for driver ${driverId}`);
    return;
  }

  console.log(`🎬 Starting ride request simulator for driver ${driverId}`);

  // Generate first request immediately
  setTimeout(() => generateRideRequest(driverId, onRideRequest), 2000);

  // Then generate periodic requests
  const interval = setInterval(() => {
    generateRideRequest(driverId, onRideRequest);
  }, 15000); // New request every 15 seconds

  activeSimulators.set(driverId, interval);
}

/**
 * Stop generating simulated ride requests
 */
function stopSimulation(driverId) {
  const interval = activeSimulators.get(driverId);

  if (interval) {
    clearInterval(interval);
    activeSimulators.delete(driverId);
    console.log(`🛑 Stopped ride request simulator for driver ${driverId}`);
  }
}

/**
 * Generate a single ride request immediately (useful after rejection)
 */
function generateSingleRequest(driverId, onRideRequest) {
  generateRideRequest(driverId, onRideRequest);
}

/**
 * Generate a random ride request
 */
function generateRideRequest(driverId, onRideRequest) {
  // Random pickup and destination
  const pickup = PICKUP_LOCATIONS[Math.floor(Math.random() * PICKUP_LOCATIONS.length)];
  const destination = DESTINATION_LOCATIONS[Math.floor(Math.random() * DESTINATION_LOCATIONS.length)];

  // Avoid same pickup and destination
  if (pickup.address === destination.address) {
    return generateRideRequest(driverId, onRideRequest);
  }

  // Calculate distance
  const distance = calculateDistance(pickup.lat, pickup.lng, destination.lat, destination.lng);

  // Calculate estimated earnings
  const distanceKm = distance / 1000;
  const baseFare = 2.0;
  const perKm = 1.5;
  const estimatedEarnings = parseFloat((baseFare + distanceKm * perKm).toFixed(2));

  const rideRequest = {
    pickup,
    destination,
    distance: Math.round(distance),
    estimatedEarnings,
    expiresAt: new Date(Date.now() + 30000).toISOString() // 30 second expiry
  };

  console.log(`📱 Simulated ride request for driver ${driverId}:`);
  console.log(`   Pickup: ${pickup.address}`);
  console.log(`   Destination: ${destination.address}`);
  console.log(`   Distance: ${Math.round(distance)}m`);
  console.log(`   Earnings: $${estimatedEarnings}`);

  // Notify callback
  if (onRideRequest) {
    onRideRequest(rideRequest);
  }
}

/**
 * Simple distance calculation (Haversine formula)
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Earth's radius in meters
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

module.exports = {
  startSimulation,
  stopSimulation,
  generateSingleRequest
};
