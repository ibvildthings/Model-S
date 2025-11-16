/**
 * Driver Simulator Service
 * Simulates driver movement along routes
 */

const { calculateDistance, interpolate } = require('../utils/geoUtils');
const driverPool = require('./driverPool');

class DriverSimulator {
  constructor() {
    this.activeSimulations = new Map(); // rideId -> simulation data
  }

  /**
   * Start simulating driver movement for a ride
   * @param {object} ride - Ride object
   * @param {object} driver - Driver object
   * @param {function} onUpdate - Callback for position updates
   * @param {function} onStateChange - Callback for state changes
   */
  startSimulation(ride, driver, onUpdate, onStateChange) {
    console.log(`🎬 Starting simulation for ride ${ride.id} with driver ${driver.name}`);

    const simulation = {
      rideId: ride.id,
      driver: driver,
      currentPhase: 'toPickup', // toPickup, toDestination
      progress: 0,
      start: { ...driver.location },
      end: { ...ride.pickup },
      interval: null
    };

    // Calculate total distance
    const distanceToPickup = calculateDistance(
      driver.location.lat,
      driver.location.lng,
      ride.pickup.lat,
      ride.pickup.lng
    );

    // Speed: complete journey in 15-30 seconds for testing
    // (In production, this would match the actual ETA)
    const durationSeconds = 20 + Math.random() * 10;
    const updateIntervalMs = 500; // Update every 500ms
    const totalUpdates = (durationSeconds * 1000) / updateIntervalMs;
    const progressIncrement = 1 / totalUpdates;

    // Assign driver
    driverPool.assignDriver(driver.id, ride.id);

    // Start movement simulation
    simulation.interval = setInterval(() => {
      simulation.progress += progressIncrement;

      if (simulation.progress >= 1.0) {
        // Reached current waypoint
        if (simulation.currentPhase === 'toPickup') {
          // Driver reached pickup
          console.log(`📍 Driver ${driver.name} arrived at pickup`);

          // Transition to arriving state
          onStateChange('arriving');

          // After 2 seconds, start ride
          setTimeout(() => {
            console.log(`🚗 Starting ride to destination`);
            onStateChange('inProgress');

            // Start second phase: to destination
            simulation.currentPhase = 'toDestination';
            simulation.progress = 0;
            simulation.start = { ...ride.pickup };
            simulation.end = { ...ride.destination };
          }, 2000);

        } else if (simulation.currentPhase === 'toDestination') {
          // Driver reached destination
          console.log(`🏁 Driver ${driver.name} completed ride`);
          onStateChange('completed');

          // Clean up
          this.stopSimulation(ride.id);
          driverPool.completeRide(driver.id);
        }
      } else {
        // Update driver position
        const currentPosition = interpolate(
          simulation.start,
          simulation.end,
          simulation.progress
        );

        // Update driver in pool
        driverPool.updateDriverLocation(driver.id, currentPosition.lat, currentPosition.lng);

        // Check if approaching (within 100m)
        const distanceRemaining = calculateDistance(
          currentPosition.lat,
          currentPosition.lng,
          simulation.end.lat,
          simulation.end.lng
        );

        // Notify state changes based on distance
        if (simulation.currentPhase === 'toPickup') {
          if (distanceRemaining < 100 && ride.status !== 'arriving') {
            console.log(`⏰ Driver ${driver.name} is approaching pickup`);
            onStateChange('arriving');
          } else if (distanceRemaining >= 100 && ride.status !== 'enRoute') {
            onStateChange('enRoute');
          }
        } else if (simulation.currentPhase === 'toDestination') {
          if (distanceRemaining < 100 && ride.status !== 'approachingDestination') {
            console.log(`🎯 Driver ${driver.name} is approaching destination`);
            onStateChange('approachingDestination');
          }
        }

        // Send position update
        onUpdate({
          rideId: ride.id,
          driver: {
            id: driver.id,
            location: currentPosition
          },
          status: ride.status,
          distanceRemaining: Math.round(distanceRemaining),
          progress: simulation.progress
        });
      }
    }, updateIntervalMs);

    this.activeSimulations.set(ride.id, simulation);
  }

  /**
   * Stop simulation for a ride
   */
  stopSimulation(rideId) {
    const simulation = this.activeSimulations.get(rideId);
    if (simulation && simulation.interval) {
      clearInterval(simulation.interval);
      this.activeSimulations.delete(rideId);
      console.log(`🛑 Stopped simulation for ride ${rideId}`);
    }
  }

  /**
   * Get active simulation
   */
  getSimulation(rideId) {
    return this.activeSimulations.get(rideId);
  }

  /**
   * Stop all simulations
   */
  stopAll() {
    for (const [rideId, simulation] of this.activeSimulations) {
      if (simulation.interval) {
        clearInterval(simulation.interval);
      }
    }
    this.activeSimulations.clear();
    console.log('🛑 Stopped all simulations');
  }
}

module.exports = new DriverSimulator();
