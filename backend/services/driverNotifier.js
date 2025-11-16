/**
 * Driver Notifier Service
 * Manages notifications to drivers about new ride requests
 */

class DriverNotifier {
  constructor() {
    // Map of driverId -> WebSocket connection
    this.driverConnections = new Map();

    // Map of driverId -> pending ride offers
    this.pendingOffers = new Map();
  }

  /**
   * Register a driver's WebSocket connection
   */
  registerDriver(driverId, ws) {
    this.driverConnections.set(driverId, ws);
    console.log(`🔔 Driver ${driverId} registered for notifications`);
  }

  /**
   * Unregister a driver's WebSocket connection
   */
  unregisterDriver(driverId) {
    this.driverConnections.delete(driverId);
    this.pendingOffers.delete(driverId);
    console.log(`🔕 Driver ${driverId} unregistered from notifications`);
  }

  /**
   * Notify a driver about a ride request
   */
  notifyDriver(driverId, rideRequest) {
    const ws = this.driverConnections.get(driverId);

    if (!ws || ws.readyState !== 1) { // 1 = OPEN
      console.log(`⚠️  Cannot notify driver ${driverId} - no active connection`);
      return false;
    }

    const notification = {
      type: 'rideRequest',
      data: {
        rideId: rideRequest.id,
        pickup: rideRequest.pickup,
        destination: rideRequest.destination,
        distance: rideRequest.distance,
        estimatedEarnings: this.calculateEstimatedEarnings(rideRequest.distance),
        expiresAt: Date.now() + 30000 // 30 seconds to accept
      }
    };

    try {
      ws.send(JSON.stringify(notification));

      // Store pending offer
      this.pendingOffers.set(driverId, {
        rideId: rideRequest.id,
        sentAt: Date.now()
      });

      console.log(`🔔 Notified driver ${driverId} about ride ${rideRequest.id}`);
      return true;
    } catch (error) {
      console.error(`Error notifying driver ${driverId}:`, error);
      return false;
    }
  }

  /**
   * Notify multiple drivers about a ride request
   * (Useful for broadcasting to nearby drivers)
   */
  notifyMultipleDrivers(driverIds, rideRequest) {
    const notified = [];

    for (const driverId of driverIds) {
      if (this.notifyDriver(driverId, rideRequest)) {
        notified.push(driverId);
      }
    }

    console.log(`🔔 Notified ${notified.length}/${driverIds.length} drivers about ride ${rideRequest.id}`);
    return notified;
  }

  /**
   * Cancel a ride offer to a driver
   */
  cancelOffer(driverId, rideId) {
    const ws = this.driverConnections.get(driverId);

    if (ws && ws.readyState === 1) {
      ws.send(JSON.stringify({
        type: 'rideCancelled',
        data: { rideId }
      }));
    }

    this.pendingOffers.delete(driverId);
    console.log(`🚫 Cancelled ride offer to driver ${driverId}`);
  }

  /**
   * Send status update to driver
   */
  sendStatusUpdate(driverId, update) {
    const ws = this.driverConnections.get(driverId);

    if (!ws || ws.readyState !== 1) {
      return false;
    }

    try {
      ws.send(JSON.stringify({
        type: 'statusUpdate',
        data: update
      }));
      return true;
    } catch (error) {
      console.error(`Error sending status update to driver ${driverId}:`, error);
      return false;
    }
  }

  /**
   * Get all connected drivers
   */
  getConnectedDrivers() {
    return Array.from(this.driverConnections.keys());
  }

  /**
   * Check if driver is connected
   */
  isDriverConnected(driverId) {
    const ws = this.driverConnections.get(driverId);
    return ws && ws.readyState === 1;
  }

  /**
   * Calculate estimated earnings for a ride
   */
  calculateEstimatedEarnings(distance) {
    // Simple calculation: $2 base + $1.50 per km
    const distanceKm = distance / 1000;
    const earnings = 2 + (distanceKm * 1.5);
    return parseFloat(earnings.toFixed(2));
  }

  /**
   * Clean up expired offers
   */
  cleanupExpiredOffers() {
    const now = Date.now();
    const expiredOffers = [];

    for (const [driverId, offer] of this.pendingOffers.entries()) {
      if (now - offer.sentAt > 30000) { // 30 seconds
        expiredOffers.push(driverId);
      }
    }

    for (const driverId of expiredOffers) {
      this.pendingOffers.delete(driverId);
    }

    if (expiredOffers.length > 0) {
      console.log(`🧹 Cleaned up ${expiredOffers.length} expired offers`);
    }
  }
}

// Singleton instance
const driverNotifier = new DriverNotifier();

// Clean up expired offers every 10 seconds
setInterval(() => {
  driverNotifier.cleanupExpiredOffers();
}, 10000);

module.exports = driverNotifier;
