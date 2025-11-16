/**
 * Driver Pool Service
 * Manages a pool of simulated drivers
 */

const Driver = require('../models/Driver');
const { randomLocationInRadius } = require('../utils/geoUtils');

class DriverPool {
  constructor() {
    this.drivers = [];
    this.initializeDrivers();
  }

  /**
   * Initialize a pool of simulated drivers
   * Creates drivers at random locations around San Francisco
   */
  initializeDrivers() {
    // San Francisco center coordinates
    const sfCenter = { lat: 37.7749, lng: -122.4194 };
    const radiusMeters = 10000; // 10 km radius

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
      const location = randomLocationInRadius(sfCenter.lat, sfCenter.lng, radiusMeters);
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
    }

    console.log(`✅ Initialized ${this.drivers.length} simulated drivers`);
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
