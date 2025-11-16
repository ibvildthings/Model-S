/**
 * Driver Matcher Service
 * Matches rides to the nearest available driver
 */

const { calculateDistance, calculateETA } = require('../utils/geoUtils');
const driverPool = require('./driverPool');

class DriverMatcher {
  /**
   * Find the nearest available driver to a pickup location
   * @param {object} pickupLocation - {lat, lng}
   * @returns {object|null} Driver object or null if none available
   */
  findNearestDriver(pickupLocation) {
    const availableDrivers = driverPool.getAvailableDrivers();

    if (availableDrivers.length === 0) {
      console.log('⚠️  No available drivers');
      return null;
    }

    // Calculate distance to each driver
    const driversWithDistance = availableDrivers.map(driver => ({
      driver,
      distance: calculateDistance(
        pickupLocation.lat,
        pickupLocation.lng,
        driver.location.lat,
        driver.location.lng
      )
    }));

    // Sort by distance (nearest first)
    driversWithDistance.sort((a, b) => a.distance - b.distance);

    const nearest = driversWithDistance[0];

    console.log(`🚗 Matched driver: ${nearest.driver.name} (${Math.round(nearest.distance)}m away)`);

    return {
      driver: nearest.driver,
      distance: nearest.distance,
      eta: calculateETA(nearest.distance)
    };
  }

  /**
   * Match a ride to a driver with simulated delay
   * @param {object} ride - Ride object
   * @param {function} onMatch - Callback when driver is matched
   */
  matchRideToDriver(ride, onMatch) {
    console.log(`🔍 Searching for driver for ride ${ride.id}...`);

    // Simulate search delay (2-4 seconds)
    const searchDelay = 2000 + Math.random() * 2000;

    setTimeout(() => {
      const match = this.findNearestDriver(ride.pickup);

      if (match) {
        onMatch(match);
      } else {
        console.log(`❌ No drivers available for ride ${ride.id}`);
        onMatch(null);
      }
    }, searchDelay);
  }
}

module.exports = new DriverMatcher();
