/**
 * Driver Pool Service
 * Manages a pool of simulated drivers
 */

const Driver = require('../models/Driver');
const { randomLocationInDonut } = require('../utils/geoUtils');

class DriverPool {
  constructor() {
    this.drivers = [];
    this.initializeDrivers();
  }

  /**
   * Initialize a pool of simulated drivers
   * Creates drivers at random locations around San Francisco
   * Drivers spawn in a donut shape (3-8km from center) to ensure
   * they're always a realistic distance away from typical pickup locations
   */
  initializeDrivers() {
    // San Francisco center coordinates
    const sfCenter = { lat: 37.7749, lng: -122.4194 };

    // Spawn drivers in a donut shape: 3-8 km from center
    // This ensures they're not too close (unrealistic instant arrival)
    // but not too far (too long to test)
    const minRadiusMeters = 3000;  // 3 km minimum
    const maxRadiusMeters = 8000;  // 8 km maximum

    const driverNames = [
      'Michael Chen',
      'Sarah Johnson',
      'David Martinez',
      'Emily Rodriguez',
      'James Wilson',
      'Maria Garcia',
      'Robert Taylor',
      'Jennifer Lee',
      'William Brown',
      'Lisa Anderson'
    ];

    const vehicleTypes = ['Standard', 'Standard', 'Standard', 'Premium', 'XL'];

    for (let i = 0; i < driverNames.length; i++) {
      // Spawn driver in donut-shaped area
      const location = randomLocationInDonut(
        sfCenter.lat,
        sfCenter.lng,
        minRadiusMeters,
        maxRadiusMeters
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

      console.log(`   ${driver.name}: ${location.lat.toFixed(4)}, ${location.lng.toFixed(4)}`);
    }

    console.log(`✅ Initialized ${this.drivers.length} simulated drivers (3-8km radius)`);
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
   */
  completeRide(driverId) {
    const driver = this.getDriverById(driverId);
    if (driver) {
      driver.completeRide();
    }
  }
}

// Singleton instance
const driverPool = new DriverPool();

module.exports = driverPool;
