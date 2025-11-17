/**
 * Rides Routes
 * API endpoints for ride requests
 */

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const Ride = require('../models/Ride');
const driverMatcher = require('../services/driverMatcher');
const driverSimulator = require('../services/driverSimulator');
const driverPool = require('../services/driverPool');
const { driverSessions } = require('./drivers');

const router = express.Router();

// In-memory storage (replace with database in production)
const rides = new Map();
const pendingRideOffers = new Map(); // rideId -> driverId (offers sent to real drivers)

/**
 * Get online drivers (those with active sessions)
 */
function getOnlineDrivers() {
  const onlineDriverIds = Array.from(driverSessions.keys());
  return onlineDriverIds
    .map(id => driverPool.getDriverById(id))
    .filter(driver => driver && driver.available);
}

/**
 * Find nearest online driver to a location
 */
function findNearestOnlineDriver(pickup) {
  const onlineDrivers = getOnlineDrivers();

  if (onlineDrivers.length === 0) {
    return null;
  }

  // Calculate distances and find nearest
  const driversWithDistance = onlineDrivers.map(driver => {
    const distance = calculateDistance(
      pickup.lat,
      pickup.lng,
      driver.location.lat,
      driver.location.lng
    );
    return { driver, distance };
  });

  driversWithDistance.sort((a, b) => a.distance - b.distance);
  return driversWithDistance[0];
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

/**
 * POST /api/rides/request
 * Request a new ride
 */
router.post('/request', async (req, res) => {
  try {
    const { pickup, destination } = req.body;

    // Validate request
    if (!pickup || !pickup.lat || !pickup.lng) {
      return res.status(400).json({
        error: 'Invalid pickup location',
        message: 'Pickup must include lat and lng'
      });
    }

    if (!destination || !destination.lat || !destination.lng) {
      return res.status(400).json({
        error: 'Invalid destination location',
        message: 'Destination must include lat and lng'
      });
    }

    // Create ride
    const rideId = uuidv4();
    const ride = new Ride(rideId, pickup, destination);
    rides.set(rideId, ride);

    console.log(`📱 New ride request: ${rideId}`);
    console.log(`   Pickup: ${pickup.address || `${pickup.lat}, ${pickup.lng}`}`);
    console.log(`   Destination: ${destination.address || `${destination.lat}, ${destination.lng}`}`);

    // Immediately return ride ID with searching status
    res.status(201).json({
      rideId: ride.id,
      status: ride.status,
      pickup: ride.pickup,
      destination: ride.destination,
      createdAt: ride.createdAt
    });

    // Check for online real drivers first
    const nearestDriver = findNearestOnlineDriver(pickup);

    // Check if the driver is actually logged in (has active session)
    const { driverSessions } = require('./drivers');
    const hasLoggedInDriver = nearestDriver && driverSessions.has(nearestDriver.driver.id);

    if (hasLoggedInDriver) {
      // Found a logged-in driver! Send them the ride offer
      const { driver, distance } = nearestDriver;
      const estimatedEarnings = calculateFare(distance);

      console.log(`🎯 Found logged-in driver: ${driver.name}`);
      console.log(`   Distance: ${Math.round(distance)}m`);
      console.log(`   Estimated earnings: $${estimatedEarnings}`);

      // Store pending offer
      pendingRideOffers.set(ride.id, {
        driverId: driver.id,
        distance,
        estimatedEarnings,
        offeredAt: Date.now()
      });

      // Set ride status to searching (waiting for driver acceptance)
      ride.updateStatus('searching');

      // Reduced timeout: 5 seconds instead of 30 for development
      setTimeout(() => {
        const offer = pendingRideOffers.get(ride.id);
        if (offer && ride.status === 'searching') {
          console.log(`⏰ Ride ${ride.id} offer expired (no response), using simulated driver`);
          pendingRideOffers.delete(ride.id);

          // Fall back to simulated driver
          useSimulatedDriver(ride);
        }
      }, 5000);

      return; // Wait for driver to accept
    }

    // No logged-in drivers, use simulated driver immediately
    if (nearestDriver) {
      console.log(`⚠️ Driver ${nearestDriver.driver.name} found but not logged in, using simulation`);
    } else {
      console.log('📵 No online drivers available, using simulation');
    }
    useSimulatedDriver(ride);

  } catch (error) {
    console.error('Error creating ride:', error);
    res.status(500).json({
      error: 'Failed to create ride',
      message: error.message
    });
  }
});

/**
 * Helper: Use simulated driver for a ride
 */
function useSimulatedDriver(ride) {
  driverMatcher.matchRideToDriver(ride, (match) => {
      if (match) {
        const { driver, distance, eta } = match;

        console.log(`✅ Driver ${driver.name} matched!`);
        console.log(`   Driver location: ${driver.location.lat.toFixed(4)}, ${driver.location.lng.toFixed(4)}`);
        console.log(`   Distance to pickup: ${Math.round(distance)}m`);
        console.log(`   ETA: ${Math.round(eta)}s`);

        // IMPORTANT: Store driver's location BEFORE assignment
        const driverOriginalLocation = { ...driver.location };

        // Assign driver to ride
        ride.assignDriver(driver, eta);

        // Broadcast initial assignment with driver's ACTUAL location
        broadcastRideUpdate(ride);

        // Start driver movement simulation
        // The simulator will send the initial position immediately
        driverSimulator.startSimulation(
          ride,
          driver,
          (positionUpdate) => {
            // Broadcast driver position update
            broadcastDriverPosition(positionUpdate);
          },
          (newStatus) => {
            // Update ride status
            ride.updateStatus(newStatus);
            broadcastRideUpdate(ride);
          }
        );
      } else {
        // No drivers available
        console.log(`❌ No drivers available for ride ${ride.id}`);
        ride.updateStatus('noDriversAvailable');
        broadcastRideUpdate(ride);
      }
    });
}

/**
 * Calculate fare based on distance
 */
function calculateFare(distanceMeters) {
  const distanceKm = distanceMeters / 1000;
  const baseFare = 2.0;
  const perKm = 1.5;
  return parseFloat((baseFare + distanceKm * perKm).toFixed(2));
}

/**
 * GET /api/rides/:rideId
 * Get ride status
 */
router.get('/:rideId', (req, res) => {
  const { rideId } = req.params;
  const ride = rides.get(rideId);

  if (!ride) {
    return res.status(404).json({
      error: 'Ride not found',
      message: `No ride found with ID: ${rideId}`
    });
  }

  const rideData = ride.toJSON();

  // Debug: Log what we're sending to iOS
  if (rideData.driver) {
    console.log(`📤 Sending ride status with driver: ${rideData.driver.name}`);
    console.log(`   Driver location: ${rideData.driver.location.lat}, ${rideData.driver.location.lng}`);
  } else {
    console.log(`📤 Sending ride status: ${rideData.status} (no driver yet)`);
  }

  res.json(rideData);
});

/**
 * POST /api/rides/:rideId/cancel
 * Cancel a ride
 */
router.post('/:rideId/cancel', (req, res) => {
  const { rideId } = req.params;
  const ride = rides.get(rideId);

  if (!ride) {
    return res.status(404).json({
      error: 'Ride not found',
      message: `No ride found with ID: ${rideId}`
    });
  }

  // Stop simulation if active
  driverSimulator.stopSimulation(rideId);

  // Update ride status
  ride.updateStatus('cancelled');

  console.log(`❌ Ride ${rideId} cancelled`);

  // Broadcast cancellation
  broadcastRideUpdate(ride);

  res.json({
    success: true,
    message: 'Ride cancelled',
    ride: ride.toJSON()
  });
});

/**
 * GET /api/rides
 * Get all rides (for debugging)
 */
router.get('/', (req, res) => {
  const allRides = Array.from(rides.values()).map(r => r.toJSON());
  res.json({
    count: allRides.length,
    rides: allRides
  });
});

// Helper function to broadcast ride updates (will be set by server)
let broadcastRideUpdate = () => {};
let broadcastDriverPosition = () => {};

function setBroadcastFunctions(rideUpdateFn, driverPositionFn) {
  broadcastRideUpdate = rideUpdateFn;
  broadcastDriverPosition = driverPositionFn;
}

/**
 * Get pending ride offer for a specific driver
 */
function getPendingOfferForDriver(driverId) {
  // Find any ride with a pending offer for this driver
  for (const [rideId, offer] of pendingRideOffers.entries()) {
    if (offer.driverId === driverId) {
      const ride = rides.get(rideId);
      if (ride) {
        return {
          rideId: ride.id,
          pickup: ride.pickup,
          destination: ride.destination,
          distance: offer.distance,
          estimatedEarnings: offer.estimatedEarnings,
          expiresAt: new Date(offer.offeredAt + 30000).toISOString()
        };
      }
    }
  }
  return null;
}

/**
 * Assign a driver to a ride
 */
function assignDriverToRide(rideId, driver) {
  const ride = rides.get(rideId);
  const offer = pendingRideOffers.get(rideId);

  if (!ride || !offer) {
    return false;
  }

  // Remove pending offer
  pendingRideOffers.delete(rideId);

  // Assign driver to ride
  const distance = offer.distance;
  const eta = Math.round(distance / 10); // Rough estimate: 10m/s = 36 km/h
  ride.assignDriver(driver, eta);

  // Assign ride to driver
  driver.assignRide(rideId);

  console.log(`🎯 Driver ${driver.name} assigned to ride ${rideId}`);

  // Broadcast update
  broadcastRideUpdate(ride);

  return true;
}

/**
 * Update ride status based on driver actions
 */
function updateRideStatus(rideId, status) {
  const ride = rides.get(rideId);

  if (!ride) {
    return false;
  }

  // Map driver status to ride status
  const statusMap = {
    'arrived': 'arriving',
    'pickedUp': 'inProgress',
    'approaching': 'approachingDestination',
    'completed': 'completed'
  };

  const rideStatus = statusMap[status] || status;
  ride.updateStatus(rideStatus);

  console.log(`📍 Ride ${rideId} status updated to: ${rideStatus}`);

  // Broadcast update
  broadcastRideUpdate(ride);

  return true;
}

module.exports = {
  router,
  setBroadcastFunctions,
  getPendingOfferForDriver,
  assignDriverToRide,
  updateRideStatus
};
