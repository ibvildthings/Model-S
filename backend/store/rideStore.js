/**
 * Ride Store
 * In-memory persistence for rides and pending ride offers to real drivers.
 * Swap this module for a database-backed implementation in production;
 * routes and services only talk to this interface.
 */

class RideStore {
  constructor() {
    this.rides = new Map(); // rideId -> Ride
    this.pendingOffers = new Map(); // rideId -> { driverId, distance, estimatedEarnings, offeredAt }
  }

  // Rides

  save(ride) {
    this.rides.set(ride.id, ride);
    return ride;
  }

  get(rideId) {
    return this.rides.get(rideId);
  }

  all() {
    return Array.from(this.rides.values());
  }

  // Pending offers to logged-in drivers

  setPendingOffer(rideId, offer) {
    this.pendingOffers.set(rideId, offer);
  }

  getPendingOffer(rideId) {
    return this.pendingOffers.get(rideId);
  }

  deletePendingOffer(rideId) {
    this.pendingOffers.delete(rideId);
  }

  /**
   * Find the pending offer addressed to a driver
   * @returns {{ rideId: string, offer: object } | null}
   */
  findPendingOfferForDriver(driverId) {
    for (const [rideId, offer] of this.pendingOffers.entries()) {
      if (offer.driverId === driverId) {
        return { rideId, offer };
      }
    }
    return null;
  }

  /** Remove everything (used by tests) */
  clear() {
    this.rides.clear();
    this.pendingOffers.clear();
  }
}

module.exports = new RideStore();
