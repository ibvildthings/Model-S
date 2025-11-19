/**
 * Ride Request Simulator
 * Generates simulated ride requests for driver app testing
 * Uses centralized geoConfig for consistent locations across the system
 */

const geoConfig = require('../config/geoConfig');

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
 * Generate a random ride request using realistic patterns
 */
function generateRideRequest(driverId, onRideRequest) {
  // Use pattern-based ride generation for realistic scenarios
  const ride = geoConfig.generatePatternBasedRide();
  const pickup = ride.pickup;
  const destination = ride.destination;

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
  console.log(`   Pattern: ${ride.pattern} - ${ride.description}`);
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
