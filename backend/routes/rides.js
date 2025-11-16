/**
 * Rides Routes
 * API endpoints for ride requests
 */

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const Ride = require('../models/Ride');
const driverMatcher = require('../services/driverMatcher');
const driverSimulator = require('../services/driverSimulator');

const router = express.Router();

// In-memory storage (replace with database in production)
const rides = new Map();

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

    // Start driver matching asynchronously
    driverMatcher.matchRideToDriver(ride, (match) => {
      if (match) {
        const { driver, distance, eta } = match;

        // Assign driver to ride
        ride.assignDriver(driver, eta);

        console.log(`✅ Driver ${driver.name} assigned to ride ${ride.id}`);

        // Broadcast update via WebSocket
        broadcastRideUpdate(ride);

        // Start driver movement simulation
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
        ride.updateStatus('noDriversAvailable');
        broadcastRideUpdate(ride);
      }
    });

  } catch (error) {
    console.error('Error creating ride:', error);
    res.status(500).json({
      error: 'Failed to create ride',
      message: error.message
    });
  }
});

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

  res.json(ride.toJSON());
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

module.exports = {
  router,
  setBroadcastFunctions
};
