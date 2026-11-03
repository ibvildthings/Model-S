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
const rideStore = require('../store/rideStore');
const driverStore = require('../store/driverStore');
const { calculateDistance } = require('../utils/geoUtils');

const router = express.Router();

const OFFER_TIMEOUT_MS = 30000; // Matches the driver app's offer countdown

function isValidLocation(location) {
  return Boolean(location) &&
    Number.isFinite(location.lat) && Math.abs(location.lat) <= 90 &&
    Number.isFinite(location.lng) && Math.abs(location.lng) <= 180;
}

/**
 * Nearest available driver that is logged in through the driver app
 * @returns {{ driver: Driver, distance: number } | null}
 */
function findNearestOnlineDriver(pickup) {
  let nearest = null;

  for (const driverId of driverStore.sessions.keys()) {
    const driver = driverPool.getDriverById(driverId);
    if (!driver || !driver.available) continue;

    const distance = calculateDistance(pickup.lat, pickup.lng, driver.location.lat, driver.location.lng);
    if (!nearest || distance < nearest.distance) {
      nearest = { driver, distance };
    }
  }

  return nearest;
}

/**
 * POST /api/rides/request
 * Request a new ride
 */
router.post('/request', async (req, res) => {
  try {
    const { pickup, destination } = req.body;

    // Validate request
    if (!isValidLocation(pickup)) {
      return res.status(400).json({
        error: 'Invalid pickup location',
        message: 'Pickup must include lat and lng'
      });
    }

    if (!isValidLocation(destination)) {
      return res.status(400).json({
        error: 'Invalid destination location',
        message: 'Destination must include lat and lng'
      });
    }

    // Create ride
    const rideId = uuidv4();
    const ride = new Ride(rideId, pickup, destination);
    rideStore.save(ride);

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

    // Prefer a real driver logged in through the driver app
    const nearestDriver = findNearestOnlineDriver(pickup);

    if (nearestDriver) {
      // Found a logged-in driver! Send them the ride offer
      const { driver, distance } = nearestDriver;
      const estimatedEarnings = calculateFare(distance);

      console.log(`🎯 Found logged-in driver: ${driver.name}`);
      console.log(`   Distance: ${Math.round(distance)}m`);
      console.log(`   Estimated earnings: $${estimatedEarnings}`);

      // Store pending offer
      rideStore.setPendingOffer(ride.id, {
        driverId: driver.id,
        distance,
        estimatedEarnings,
        offeredAt: Date.now()
      });

      // Set ride status to searching (waiting for driver acceptance)
      ride.updateStatus('searching');

      // If the driver doesn't respond in time, fall back to a simulated driver
      setTimeout(() => {
        const offer = rideStore.getPendingOffer(ride.id);
        if (offer && ride.status === 'searching') {
          console.log(`⏰ Ride ${ride.id} offer expired (no response), using simulated driver`);
          rideStore.deletePendingOffer(ride.id);
          useSimulatedDriver(ride);
        }
      }, OFFER_TIMEOUT_MS).unref();

      return; // Wait for driver to accept
    }

    // No logged-in drivers, use a simulated driver immediately
    console.log('📵 No online drivers available, using simulation');
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
  const ride = rideStore.get(rideId);

  if (!ride) {
    return res.status(404).json({
      error: 'Ride not found',
      message: `No ride found with ID: ${rideId}`
    });
  }

  res.json(ride.toJSON());
});

/**
 * POST /api/rides/:rideId/cancel
 * Cancel a ride
 */
router.post('/:rideId/cancel', (req, res) => {
  const { rideId } = req.params;
  const ride = rideStore.get(rideId);

  if (!ride) {
    return res.status(404).json({
      error: 'Ride not found',
      message: `No ride found with ID: ${rideId}`
    });
  }

  // Stop simulation / withdraw any pending offer
  driverSimulator.stopSimulation(rideId);
  rideStore.deletePendingOffer(rideId);

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
  const allRides = rideStore.all().map(r => r.toJSON());
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
  const pending = rideStore.findPendingOfferForDriver(driverId);
  if (!pending) return null;

  const ride = rideStore.get(pending.rideId);
  if (!ride) return null;

  const { offer } = pending;
  return {
    rideId: ride.id,
    pickup: ride.pickup,
    destination: ride.destination,
    distance: offer.distance,
    estimatedEarnings: offer.estimatedEarnings,
    expiresAt: new Date(offer.offeredAt + OFFER_TIMEOUT_MS).toISOString()
  };
}

/**
 * Assign a driver to a ride
 */
function assignDriverToRide(rideId, driver) {
  const ride = rideStore.get(rideId);
  const offer = rideStore.getPendingOffer(rideId);

  if (!ride || !offer) {
    return false;
  }

  rideStore.deletePendingOffer(rideId);

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
  const ride = rideStore.get(rideId);

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
