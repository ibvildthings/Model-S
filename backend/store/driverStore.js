/**
 * Driver Store
 * In-memory state for logged-in drivers and the simulated ride offers used to
 * exercise the driver app without a real rider.
 * Swap this module for a database/cache-backed implementation in production.
 */

class DriverStore {
  constructor() {
    this.sessions = new Map(); // driverId -> { driverId, loginTime, lastUpdate, ... }
    this.simulatedOffers = new Map(); // driverId -> current simulated offer
    this.activeSimulatedRides = new Map(); // rideId -> { driverId, pickup, destination, status, passenger }
  }

  /** Remove everything (used by tests) */
  clear() {
    this.sessions.clear();
    this.simulatedOffers.clear();
    this.activeSimulatedRides.clear();
  }
}

module.exports = new DriverStore();
