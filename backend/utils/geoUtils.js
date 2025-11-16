/**
 * Geo Utilities
 * Helper functions for geographic calculations
 */

/**
 * Calculate distance between two coordinates using Haversine formula
 * @param {number} lat1 - Latitude of point 1
 * @param {number} lng1 - Longitude of point 1
 * @param {number} lat2 - Latitude of point 2
 * @param {number} lng2 - Longitude of point 2
 * @returns {number} Distance in meters
 */
function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371e3; // Earth's radius in meters
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lng2 - lng1) * Math.PI / 180;

  const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) *
    Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Distance in meters
}

/**
 * Interpolate between two points
 * @param {object} start - Start point {lat, lng}
 * @param {object} end - End point {lat, lng}
 * @param {number} progress - Progress from 0 to 1
 * @returns {object} Interpolated point {lat, lng}
 */
function interpolate(start, end, progress) {
  return {
    lat: start.lat + (end.lat - start.lat) * progress,
    lng: start.lng + (end.lng - start.lng) * progress
  };
}

/**
 * Calculate estimated time based on distance
 * Assumes average speed of 40 km/h in city
 * @param {number} distanceMeters - Distance in meters
 * @returns {number} Estimated time in seconds
 */
function calculateETA(distanceMeters) {
  const averageSpeedKmh = 40; // 40 km/h average city speed
  const averageSpeedMs = averageSpeedKmh * 1000 / 3600; // Convert to m/s
  return Math.round(distanceMeters / averageSpeedMs);
}

/**
 * Generate random location within radius of a point
 * @param {number} lat - Center latitude
 * @param {number} lng - Center longitude
 * @param {number} radiusMeters - Radius in meters
 * @returns {object} Random point {lat, lng}
 */
function randomLocationInRadius(lat, lng, radiusMeters) {
  // Convert radius from meters to degrees (rough approximation)
  const radiusDegrees = radiusMeters / 111320; // 1 degree ≈ 111.32 km

  // Random angle
  const angle = Math.random() * 2 * Math.PI;

  // Random distance within radius
  const distance = Math.random() * radiusDegrees;

  // Calculate new position
  const newLat = lat + distance * Math.cos(angle);
  const newLng = lng + distance * Math.sin(angle);

  return { lat: newLat, lng: newLng };
}

module.exports = {
  calculateDistance,
  interpolate,
  calculateETA,
  randomLocationInRadius
};
