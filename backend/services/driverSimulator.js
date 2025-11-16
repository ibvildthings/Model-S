/**
 * Driver Simulator Service
 * Simulates driver movement along routes
 */

const { calculateDistance, interpolate, generateRoutePolyline, calculateBearing } = require('../utils/geoUtils');
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
    // Store driver's ORIGINAL location before any movement
    const driverStartLocation = { ...driver.location };

    console.log(`🎬 Starting simulation for ride ${ride.id} with driver ${driver.name}`);
    console.log(`   Driver starting at: ${driverStartLocation.lat.toFixed(4)}, ${driverStartLocation.lng.toFixed(4)}`);
    console.log(`   Pickup location: ${ride.pickup.lat.toFixed(4)}, ${ride.pickup.lng.toFixed(4)}`);
    console.log(`   Destination: ${ride.destination.lat.toFixed(4)}, ${ride.destination.lng.toFixed(4)}`);

    // Calculate distance from driver to pickup
    const distanceToPickup = calculateDistance(
      driverStartLocation.lat,
      driverStartLocation.lng,
      ride.pickup.lat,
      ride.pickup.lng
    );

    console.log(`   Distance to pickup: ${Math.round(distanceToPickup)}m`);

    // Generate route polyline from driver to pickup
    const routeToPickup = generateRoutePolyline(driverStartLocation, ride.pickup, 30);

    // Calculate duration based on distance to pickup
    // REALISTIC TIMING: 2-3 minutes for driver to arrive (like real Uber/Lyft)
    const durationToPickupSeconds = 120 + Math.random() * 60; // 2-3 minutes
    const updateIntervalMs = 500; // Update every 500ms
    const totalUpdatesToPickup = (durationToPickupSeconds * 1000) / updateIntervalMs;
    const initialProgressIncrement = 1 / totalUpdatesToPickup;

    console.log(`   Duration to pickup: ${(durationToPickupSeconds / 60).toFixed(1)} minutes`);

    const simulation = {
      rideId: ride.id,
      driver: driver,
      currentPhase: 'toPickup', // toPickup, toDestination
      progress: 0,
      progressIncrement: initialProgressIncrement, // Store in simulation so it can be updated
      start: driverStartLocation, // Driver's actual starting location
      end: { ...ride.pickup },
      route: routeToPickup, // Route points for visualization
      interval: null,
      updateIntervalMs: updateIntervalMs
    };

    // Assign driver
    driverPool.assignDriver(driver.id, ride.id);

    // Send IMMEDIATE initial position update showing driver at their ACTUAL location
    const initialBearing = calculateBearing(
      driverStartLocation.lat,
      driverStartLocation.lng,
      ride.pickup.lat,
      ride.pickup.lng
    );

    onUpdate({
      rideId: ride.id,
      driver: {
        id: driver.id,
        name: driver.name,
        location: driverStartLocation, // Driver's actual starting position
        bearing: initialBearing
      },
      status: ride.status,
      currentPhase: 'toPickup',
      distanceRemaining: Math.round(distanceToPickup),
      progress: 0,
      route: routeToPickup, // Send route polyline for visualization
      destination: ride.pickup // Driver is heading to pickup
    });

    console.log(`📡 Sent initial driver position: ${driverStartLocation.lat.toFixed(4)}, ${driverStartLocation.lng.toFixed(4)}`);

    // Start movement simulation
    simulation.interval = setInterval(() => {
      // Use progressIncrement from simulation object (can be updated between phases)
      simulation.progress += simulation.progressIncrement;

      if (simulation.progress >= 1.0) {
        // Reached current waypoint
        if (simulation.currentPhase === 'toPickup') {
          // Driver reached pickup
          console.log(`📍 Driver ${driver.name} arrived at pickup`);
          console.log(`   Final position: ${ride.pickup.lat.toFixed(4)}, ${ride.pickup.lng.toFixed(4)}`);

          // Update driver's position to exactly at pickup
          driverPool.updateDriverLocation(driver.id, ride.pickup.lat, ride.pickup.lng);

          // Transition to arriving state
          onStateChange('arriving');

          // After 2 seconds, start ride
          setTimeout(() => {
            console.log(`🚗 Starting ride to destination`);
            onStateChange('inProgress');

            // Calculate distance from pickup to destination
            const distanceToDestination = calculateDistance(
              ride.pickup.lat,
              ride.pickup.lng,
              ride.destination.lat,
              ride.destination.lng
            );

            console.log(`   Distance to destination: ${Math.round(distanceToDestination)}m`);

            // IMPORTANT: Recalculate duration for pickup-to-destination phase
            // REALISTIC TIMING: 5 minutes for the actual ride (like real Uber/Lyft)
            const durationToDestinationSeconds = 300; // Exactly 5 minutes
            const totalUpdatesToDestination = (durationToDestinationSeconds * 1000) / simulation.updateIntervalMs;
            simulation.progressIncrement = 1 / totalUpdatesToDestination;

            console.log(`   Duration to destination: ${(durationToDestinationSeconds / 60).toFixed(1)} minutes (realistic ride duration)`);

            // Generate route from pickup to destination
            const routeToDestination = generateRoutePolyline(ride.pickup, ride.destination, 30);

            // Start second phase: to destination
            simulation.currentPhase = 'toDestination';
            simulation.progress = 0;
            simulation.start = { ...ride.pickup };
            simulation.end = { ...ride.destination };
            simulation.route = routeToDestination;

            // Send route update
            onUpdate({
              rideId: ride.id,
              driver: {
                id: driver.id,
                location: ride.pickup
              },
              status: 'inProgress',
              currentPhase: 'toDestination',
              route: routeToDestination,
              destination: ride.destination
            });
          }, 2000);

        } else if (simulation.currentPhase === 'toDestination') {
          // Driver reached destination
          console.log(`🏁 Driver ${driver.name} completed ride`);
          console.log(`   Final position: ${ride.destination.lat.toFixed(4)}, ${ride.destination.lng.toFixed(4)}`);

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

        // Calculate bearing (direction of movement)
        const bearing = calculateBearing(
          currentPosition.lat,
          currentPosition.lng,
          simulation.end.lat,
          simulation.end.lng
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

        // Log progress every 10% for long rides (helps debug 5-minute rides)
        const progressPercent = Math.floor(simulation.progress * 100);
        if (progressPercent % 10 === 0 && progressPercent > 0) {
          const phase = simulation.currentPhase === 'toPickup' ? 'to pickup' : 'to destination';
          console.log(`🚗 ${driver.name} ${progressPercent}% ${phase} (${Math.round(distanceRemaining)}m remaining)`);
        }

        // Notify state changes based on distance
        if (simulation.currentPhase === 'toPickup') {
          if (distanceRemaining < 100 && ride.status !== 'arriving') {
            console.log(`⏰ Driver ${driver.name} is approaching pickup (${Math.round(distanceRemaining)}m away)`);
            onStateChange('arriving');
          } else if (distanceRemaining >= 100 && ride.status !== 'enRoute') {
            onStateChange('enRoute');
          }
        } else if (simulation.currentPhase === 'toDestination') {
          if (distanceRemaining < 100 && ride.status !== 'approachingDestination') {
            console.log(`🎯 Driver ${driver.name} is approaching destination (${Math.round(distanceRemaining)}m away)`);
            onStateChange('approachingDestination');
          }
        }

        // Send position update
        onUpdate({
          rideId: ride.id,
          driver: {
            id: driver.id,
            location: currentPosition,
            bearing: bearing
          },
          status: ride.status,
          currentPhase: simulation.currentPhase,
          distanceRemaining: Math.round(distanceRemaining),
          progress: simulation.progress,
          route: simulation.route // Continue sending route for visualization
        });
      }
    }, simulation.updateIntervalMs);

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
