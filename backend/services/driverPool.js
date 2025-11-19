/**
 * Driver Pool Service
 * Manages a pool of simulated drivers
 * Uses centralized geoConfig for consistent locations across the system
 */

const Driver = require('../models/Driver');
const { randomLocationInDonut, randomLocationInRadius } = require('../utils/geoUtils');
const geoConfig = require('../config/geoConfig');

class DriverPool {
  constructor() {
    this.drivers = [];
    this.initializeDrivers();
  }

  /**
   * Initialize a pool of simulated drivers
   * Creates drivers at random locations around San Francisco
   * Uses zone-based distribution for realistic coverage
   */
  initializeDrivers() {
    // Get configuration from centralized geoConfig
    const region = geoConfig.getActiveRegion();
    this.center = region.center;
    this.minRadiusMeters = region.driverSpawn.minRadius;
    this.maxRadiusMeters = region.driverSpawn.maxRadius;

    const driverNames = [
      // Diverse set of drivers reflecting SF's multicultural community
      'Michael Chen',
      'Sarah Johnson',
      'David Martinez',
      'Emily Rodriguez',
      'James Wilson',
      'Maria Garcia',
      'Robert Taylor',
      'Jennifer Lee',
      'William Brown',
      'Lisa Anderson',
      'Kevin Nguyen',
      'Priya Patel',
      'Carlos Santos',
      'Yuki Tanaka',
      'Omar Hassan',
      'Sofia Kowalski',
      'Andre Jackson',
      'Mei Lin Wong',
      'Diego Fernandez',
      'Aisha Mohammed'
    ];

    const vehicleTypes = ['Standard', 'Standard', 'Standard', 'Standard', 'Premium', 'Premium', 'XL'];

    for (let i = 0; i < driverNames.length; i++) {
      // Use zone-based distribution for realistic coverage
      const zone = geoConfig.selectDriverZone();
      const location = randomLocationInRadius(
        zone.center.lat,
        zone.center.lng,
        zone.radius
      );

      const rating = 4.5 + Math.random() * 0.5; // Rating between 4.5 and 5.0
      const vehicleType = vehicleTypes[i % vehicleTypes.length];

      const driver = new Driver(
        `driver_${i + 1}`,
        driverNames[i],
        location.lat,
        location.lng,
        vehicleType,
        Math.round(rating * 10) / 10
      );

      this.drivers.push(driver);

      console.log(`   ${driver.name} (${zone.name}): ${location.lat.toFixed(4)}, ${location.lng.toFixed(4)}`);
    }

    console.log(`✅ Initialized ${this.drivers.length} simulated drivers across SF zones`);
  }

  /**
   * Get all drivers
   */
  getAllDrivers() {
    return this.drivers;
  }

  /**
   * Get available drivers
   */
  getAvailableDrivers() {
    return this.drivers.filter(d => d.available);
  }

  /**
   * Get driver by ID
   */
  getDriverById(id) {
    return this.drivers.find(d => d.id === id);
  }

  /**
   * Update driver location
   */
  updateDriverLocation(driverId, lat, lng) {
    const driver = this.getDriverById(driverId);
    if (driver) {
      driver.updateLocation(lat, lng);
    }
  }

  /**
   * Assign driver to ride
   */
  assignDriver(driverId, rideId) {
    const driver = this.getDriverById(driverId);
    if (driver) {
      driver.assignRide(rideId);
    }
  }

  /**
   * Complete ride and free up driver
   * Also randomizes the driver's location for the next ride
   */
  completeRide(driverId) {
    const driver = this.getDriverById(driverId);
    if (driver) {
      driver.completeRide();

      // Randomize driver location for next ride
      // This ensures variety in testing scenarios
      this.randomizeDriverLocation(driverId);
    }
  }

  /**
   * Randomize a driver's location (for testing variety)
   * Spawns driver at a new random location in a weighted zone
   */
  randomizeDriverLocation(driverId) {
    const driver = this.getDriverById(driverId);
    if (driver) {
      // Use zone-based distribution for realistic relocation
      const zone = geoConfig.selectDriverZone();
      const newLocation = randomLocationInRadius(
        zone.center.lat,
        zone.center.lng,
        zone.radius
      );

      driver.updateLocation(newLocation.lat, newLocation.lng);
      console.log(`🎲 ${driver.name} relocated to ${zone.name}: ${newLocation.lat.toFixed(4)}, ${newLocation.lng.toFixed(4)}`);
    }
  }
}

// Singleton instance
const driverPool = new DriverPool();

module.exports = driverPool;
