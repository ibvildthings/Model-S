/**
 * Driver Routes
 * API endpoints for driver operations
 */

const express = require('express');
const driverPool = require('../services/driverPool');

const router = express.Router();

// In-memory driver sessions (replace with database in production)
const driverSessions = new Map(); // driverId -> session data

/**
 * POST /api/drivers/login
 * Driver login/authentication
 */
router.post('/login', async (req, res) => {
  try {
    const { driverId, location } = req.body;

    // Validate request
    if (!driverId) {
      return res.status(400).json({
        error: 'Invalid request',
        message: 'Driver ID is required'
      });
    }

    // Get driver from pool
    const driver = driverPool.getDriverById(driverId);

    if (!driver) {
      return res.status(404).json({
        error: 'Driver not found',
        message: `No driver found with ID: ${driverId}`
      });
    }

    // Update driver location if provided
    if (location && location.lat && location.lng) {
      driver.updateLocation(location.lat, location.lng);
    }

    // Create session
    const session = {
      driverId: driver.id,
      loginTime: new Date(),
      lastUpdate: new Date(),
      totalEarnings: 0,
      completedRides: 0
    };
    driverSessions.set(driverId, session);

    console.log(`🚗 Driver ${driver.name} logged in`);

    res.json({
      success: true,
      driver: driver.toJSON(),
      session: {
        loginTime: session.loginTime,
        totalEarnings: session.totalEarnings,
        completedRides: session.completedRides
      }
    });

  } catch (error) {
    console.error('Error during driver login:', error);
    res.status(500).json({
      error: 'Login failed',
      message: error.message
    });
  }
});

/**
 * POST /api/drivers/:driverId/logout
 * Driver logout
 */
router.post('/:driverId/logout', (req, res) => {
  const { driverId } = req.params;
  const driver = driverPool.getDriverById(driverId);

  if (!driver) {
    return res.status(404).json({
      error: 'Driver not found'
    });
  }

  // Make driver unavailable
  driver.available = false;

  // Get session data
  const session = driverSessions.get(driverId);

  // Remove session
  driverSessions.delete(driverId);

  console.log(`👋 Driver ${driver.name} logged out`);

  res.json({
    success: true,
    message: 'Logged out successfully',
    sessionSummary: session ? {
      duration: Date.now() - session.loginTime.getTime(),
      earnings: session.totalEarnings,
      ridesCompleted: session.completedRides
    } : null
  });
});

/**
 * PUT /api/drivers/:driverId/availability
 * Toggle driver availability
 */
router.put('/:driverId/availability', (req, res) => {
  const { driverId } = req.params;
  const { available } = req.body;

  const driver = driverPool.getDriverById(driverId);

  if (!driver) {
    return res.status(404).json({
      error: 'Driver not found'
    });
  }

  // Check if driver has active ride
  if (!available && driver.currentRideId) {
    return res.status(400).json({
      error: 'Cannot go offline with active ride',
      message: 'Complete current ride before going offline'
    });
  }

  driver.available = available;

  console.log(`🚗 Driver ${driver.name} is now ${available ? 'ONLINE' : 'OFFLINE'}`);

  res.json({
    success: true,
    driver: driver.toJSON()
  });
});

/**
 * PUT /api/drivers/:driverId/location
 * Update driver location
 */
router.put('/:driverId/location', (req, res) => {
  const { driverId } = req.params;
  const { lat, lng } = req.body;

  if (!lat || !lng) {
    return res.status(400).json({
      error: 'Invalid location',
      message: 'Latitude and longitude are required'
    });
  }

  const driver = driverPool.getDriverById(driverId);

  if (!driver) {
    return res.status(404).json({
      error: 'Driver not found'
    });
  }

  driver.updateLocation(lat, lng);

  // Update session
  const session = driverSessions.get(driverId);
  if (session) {
    session.lastUpdate = new Date();
  }

  res.json({
    success: true,
    location: driver.location
  });
});

/**
 * POST /api/drivers/:driverId/rides/:rideId/accept
 * Accept a ride request
 */
router.post('/:driverId/rides/:rideId/accept', (req, res) => {
  const { driverId, rideId } = req.params;

  const driver = driverPool.getDriverById(driverId);

  if (!driver) {
    return res.status(404).json({
      error: 'Driver not found'
    });
  }

  if (!driver.available) {
    return res.status(400).json({
      error: 'Driver not available',
      message: 'Driver must be online to accept rides'
    });
  }

  if (driver.currentRideId) {
    return res.status(400).json({
      error: 'Driver already has active ride',
      message: 'Complete current ride before accepting another'
    });
  }

  // Assign ride to driver
  driver.assignRide(rideId);

  console.log(`✅ Driver ${driver.name} accepted ride ${rideId}`);

  res.json({
    success: true,
    message: 'Ride accepted',
    rideId,
    driver: driver.toJSON()
  });
});

/**
 * POST /api/drivers/:driverId/rides/:rideId/reject
 * Reject a ride request
 */
router.post('/:driverId/rides/:rideId/reject', (req, res) => {
  const { driverId, rideId } = req.params;

  const driver = driverPool.getDriverById(driverId);

  if (!driver) {
    return res.status(404).json({
      error: 'Driver not found'
    });
  }

  console.log(`❌ Driver ${driver.name} rejected ride ${rideId}`);

  res.json({
    success: true,
    message: 'Ride rejected',
    rideId
  });
});

/**
 * PUT /api/drivers/:driverId/rides/:rideId/status
 * Update ride status (arrived at pickup, passenger picked up, etc.)
 */
router.put('/:driverId/rides/:rideId/status', (req, res) => {
  const { driverId, rideId } = req.params;
  const { status } = req.body;

  const driver = driverPool.getDriverById(driverId);

  if (!driver) {
    return res.status(404).json({
      error: 'Driver not found'
    });
  }

  if (driver.currentRideId !== rideId) {
    return res.status(400).json({
      error: 'Invalid ride',
      message: 'This ride is not assigned to this driver'
    });
  }

  const validStatuses = ['arrived', 'pickedUp', 'approaching', 'completed'];
  if (!validStatuses.includes(status)) {
    return res.status(400).json({
      error: 'Invalid status',
      message: `Status must be one of: ${validStatuses.join(', ')}`
    });
  }

  console.log(`📍 Driver ${driver.name} updated ride ${rideId} status to: ${status}`);

  // If ride completed, update session
  if (status === 'completed') {
    driver.completeRide();

    const session = driverSessions.get(driverId);
    if (session) {
      session.completedRides += 1;
      session.totalEarnings += calculateFare(); // Simple fare calculation
    }

    console.log(`✅ Driver ${driver.name} completed ride ${rideId}`);
  }

  res.json({
    success: true,
    status,
    rideId,
    driver: driver.toJSON()
  });
});

/**
 * GET /api/drivers/:driverId/stats
 * Get driver statistics
 */
router.get('/:driverId/stats', (req, res) => {
  const { driverId } = req.params;

  const driver = driverPool.getDriverById(driverId);

  if (!driver) {
    return res.status(404).json({
      error: 'Driver not found'
    });
  }

  const session = driverSessions.get(driverId);

  if (!session) {
    return res.status(404).json({
      error: 'No active session',
      message: 'Driver must be logged in'
    });
  }

  const onlineTime = Date.now() - session.loginTime.getTime();

  res.json({
    driver: driver.toJSON(),
    stats: {
      onlineTime,
      completedRides: session.completedRides,
      totalEarnings: session.totalEarnings,
      acceptanceRate: 100, // Would track this in production
      rating: driver.rating
    }
  });
});

/**
 * GET /api/drivers/:driverId
 * Get driver details
 */
router.get('/:driverId', (req, res) => {
  const { driverId } = req.params;

  const driver = driverPool.getDriverById(driverId);

  if (!driver) {
    return res.status(404).json({
      error: 'Driver not found'
    });
  }

  res.json({
    driver: driver.toJSON(),
    session: driverSessions.has(driverId) ? {
      active: true,
      loginTime: driverSessions.get(driverId).loginTime
    } : {
      active: false
    }
  });
});

// Helper function to calculate fare
function calculateFare() {
  // Simple fare calculation: $8-25 per ride
  return parseFloat((Math.random() * 17 + 8).toFixed(2));
}

module.exports = {
  router,
  driverSessions
};
