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
 * Uses latitude-corrected conversion for accurate distances
 * @param {number} lat - Center latitude
 * @param {number} lng - Center longitude
 * @param {number} radiusMeters - Radius in meters
 * @returns {object} Random point {lat, lng}
 */
function randomLocationInRadius(lat, lng, radiusMeters) {
  // Convert radius from meters to degrees with latitude correction
  // At the equator: 1 degree ≈ 111.32 km
  // At latitude φ: 1 degree longitude ≈ 111.32 * cos(φ) km
  const latRadians = lat * Math.PI / 180;
  const metersPerDegreeLat = 111320;
  const metersPerDegreeLng = 111320 * Math.cos(latRadians);

  // Random angle
  const angle = Math.random() * 2 * Math.PI;

  // Random distance within radius (using sqrt for uniform distribution)
  const distance = Math.sqrt(Math.random()) * radiusMeters;

  // Calculate offset in degrees
  const latOffset = (distance * Math.cos(angle)) / metersPerDegreeLat;
  const lngOffset = (distance * Math.sin(angle)) / metersPerDegreeLng;

  return {
    lat: lat + latOffset,
    lng: lng + lngOffset
  };
}

/**
 * Generate random location in a donut-shaped area (between minRadius and maxRadius)
 * This ensures drivers spawn at a realistic distance, not too close or too far
 * Uses latitude-corrected conversion for accurate distances
 * @param {number} lat - Center latitude
 * @param {number} lng - Center longitude
 * @param {number} minRadiusMeters - Minimum distance from center in meters
 * @param {number} maxRadiusMeters - Maximum distance from center in meters
 * @returns {object} Random point {lat, lng}
 */
function randomLocationInDonut(lat, lng, minRadiusMeters, maxRadiusMeters) {
  // Latitude correction for accurate distance calculation
  const latRadians = lat * Math.PI / 180;
  const metersPerDegreeLat = 111320;
  const metersPerDegreeLng = 111320 * Math.cos(latRadians);

  // Random angle (0 to 360 degrees)
  const angle = Math.random() * 2 * Math.PI;

  // Random distance between min and max radius
  // Use sqrt for uniform distribution in the donut area
  const minRadiusSq = minRadiusMeters * minRadiusMeters;
  const maxRadiusSq = maxRadiusMeters * maxRadiusMeters;
  const distance = Math.sqrt(minRadiusSq + Math.random() * (maxRadiusSq - minRadiusSq));

  // Calculate offset in degrees with latitude correction
  const latOffset = (distance * Math.cos(angle)) / metersPerDegreeLat;
  const lngOffset = (distance * Math.sin(angle)) / metersPerDegreeLng;

  return {
    lat: lat + latOffset,
    lng: lng + lngOffset
  };
}

/**
 * Generate a simple route polyline between two points
 * Creates intermediate waypoints for smooth route visualization
 * @param {object} start - Start point {lat, lng}
 * @param {object} end - End point {lat, lng}
 * @param {number} numPoints - Number of points in the route (default: 20)
 * @returns {array} Array of {lat, lng} points forming the route
 */
function generateRoutePolyline(start, end, numPoints = 20) {
  const points = [];

  for (let i = 0; i <= numPoints; i++) {
    const progress = i / numPoints;
    points.push(interpolate(start, end, progress));
  }

  return points;
}

/**
 * Calculate bearing between two points
 * @param {number} lat1 - Start latitude
 * @param {number} lng1 - Start longitude
 * @param {number} lat2 - End latitude
 * @param {number} lng2 - End longitude
 * @returns {number} Bearing in degrees (0-360)
 */
function calculateBearing(lat1, lng1, lat2, lng2) {
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δλ = (lng2 - lng1) * Math.PI / 180;

  const y = Math.sin(Δλ) * Math.cos(φ2);
  const x = Math.cos(φ1) * Math.sin(φ2) -
    Math.sin(φ1) * Math.cos(φ2) * Math.cos(Δλ);

  const θ = Math.atan2(y, x);
  const bearing = (θ * 180 / Math.PI + 360) % 360;

  return bearing;
}

module.exports = {
  calculateDistance,
  interpolate,
  calculateETA,
  randomLocationInRadius,
  randomLocationInDonut,
  generateRoutePolyline,
  calculateBearing
};
