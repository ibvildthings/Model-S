/**
 * Ride Model
 * Represents a ride request in the system
 */

class Ride {
  constructor(id, pickup, destination) {
    this.id = id;
    this.pickup = pickup; // { lat, lng, address }
    this.destination = destination; // { lat, lng, address }
    this.status = 'searching'; // searching, assigned, enRoute, arriving, inProgress, completed, cancelled
    this.driver = null;
    this.estimatedArrival = null;
    this.createdAt = new Date();
    this.updatedAt = new Date();
  }

  assignDriver(driver, estimatedArrival) {
    this.driver = driver;
    this.status = 'assigned';
    this.estimatedArrival = estimatedArrival;
    this.updatedAt = new Date();
  }

  updateStatus(status) {
    this.status = status;
    this.updatedAt = new Date();
  }

  toJSON() {
    return {
      rideId: this.id,  // Changed from "id" to "rideId" for iOS compatibility
      pickup: this.pickup,
      destination: this.destination,
      status: this.status,
      driver: this.driver ? {
        id: this.driver.id,
        name: this.driver.name,
        vehicleType: this.driver.vehicleType,
        vehicleModel: this.driver.vehicleModel,
        licensePlate: this.driver.licensePlate,
        rating: this.driver.rating,
        location: this.driver.location
      } : null,
      estimatedArrival: this.estimatedArrival,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt
    };
  }
}

module.exports = Ride;
