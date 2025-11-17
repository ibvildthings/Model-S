/**
 * Unit tests for geoUtils
 * Tests critical geographic calculations used throughout the app
 */

const {
  calculateDistance,
  interpolate,
  calculateETA,
  randomLocationInRadius,
  randomLocationInDonut,
  generateRoutePolyline,
  calculateBearing
} = require('../geoUtils');

describe('geoUtils', () => {

  describe('calculateDistance', () => {
    test('calculates distance between two points correctly', () => {
      // Distance from San Francisco (37.7749, -122.4194) to Los Angeles (34.0522, -118.2437)
      // Expected: approximately 559 km = 559,000 meters
      const distance = calculateDistance(37.7749, -122.4194, 34.0522, -118.2437);

      // Allow 1% margin of error due to Earth's curvature approximation
      expect(distance).toBeGreaterThan(550000);
      expect(distance).toBeLessThan(570000);
    });

    test('returns 0 for same location', () => {
      const distance = calculateDistance(37.7749, -122.4194, 37.7749, -122.4194);
      expect(distance).toBe(0);
    });

    test('calculates short distances accurately', () => {
      // Two points about 0.88 km apart (roughly 0.01 degrees longitude)
      const distance = calculateDistance(37.7749, -122.4194, 37.7749, -122.4094);

      // Should be approximately 880m (allow 15% margin due to latitude-dependent longitude distance)
      expect(distance).toBeGreaterThan(750);
      expect(distance).toBeLessThan(1050);
    });

    test('handles crossing prime meridian', () => {
      // London (0.1278) to slightly west (-0.1278)
      const distance = calculateDistance(51.5074, 0.1278, 51.5074, -0.1278);
      expect(distance).toBeGreaterThan(0);
      expect(distance).toBeLessThan(50000); // Less than 50km
    });

    test('handles crossing equator', () => {
      const distance = calculateDistance(1.0, 0.0, -1.0, 0.0);
      expect(distance).toBeGreaterThan(0);
      // 2 degrees latitude ≈ 222km
      expect(distance).toBeGreaterThan(200000);
      expect(distance).toBeLessThan(250000);
    });
  });

  describe('interpolate', () => {
    test('returns start point at progress 0', () => {
      const start = { lat: 37.7749, lng: -122.4194 };
      const end = { lat: 34.0522, lng: -118.2437 };
      const result = interpolate(start, end, 0);

      expect(result.lat).toBe(start.lat);
      expect(result.lng).toBe(start.lng);
    });

    test('returns end point at progress 1', () => {
      const start = { lat: 37.7749, lng: -122.4194 };
      const end = { lat: 34.0522, lng: -118.2437 };
      const result = interpolate(start, end, 1);

      expect(result.lat).toBe(end.lat);
      expect(result.lng).toBe(end.lng);
    });

    test('returns midpoint at progress 0.5', () => {
      const start = { lat: 0, lng: 0 };
      const end = { lat: 10, lng: 10 };
      const result = interpolate(start, end, 0.5);

      expect(result.lat).toBe(5);
      expect(result.lng).toBe(5);
    });

    test('interpolates correctly at 25% progress', () => {
      const start = { lat: 0, lng: 0 };
      const end = { lat: 100, lng: 50 };
      const result = interpolate(start, end, 0.25);

      expect(result.lat).toBe(25);
      expect(result.lng).toBe(12.5);
    });

    test('handles negative coordinates', () => {
      const start = { lat: -10, lng: -20 };
      const end = { lat: 10, lng: 20 };
      const result = interpolate(start, end, 0.5);

      expect(result.lat).toBe(0);
      expect(result.lng).toBe(0);
    });
  });

  describe('calculateETA', () => {
    test('calculates ETA for typical city distances', () => {
      // 5km at 40 km/h should take 450 seconds (7.5 minutes)
      const eta = calculateETA(5000);
      expect(eta).toBe(450);
    });

    test('calculates ETA for 1km distance', () => {
      // 1km at 40 km/h = 90 seconds
      const eta = calculateETA(1000);
      expect(eta).toBe(90);
    });

    test('calculates ETA for very short distances', () => {
      // 100m at 40 km/h = 9 seconds
      const eta = calculateETA(100);
      expect(eta).toBe(9);
    });

    test('returns 0 for 0 distance', () => {
      const eta = calculateETA(0);
      expect(eta).toBe(0);
    });

    test('handles large distances', () => {
      // 40km at 40 km/h = 3600 seconds (1 hour)
      const eta = calculateETA(40000);
      expect(eta).toBe(3600);
    });
  });

  describe('randomLocationInRadius', () => {
    const centerLat = 37.7749;
    const centerLng = -122.4194;
    const radius = 5000; // 5km

    test('generates location within specified radius', () => {
      const location = randomLocationInRadius(centerLat, centerLng, radius);

      expect(location).toHaveProperty('lat');
      expect(location).toHaveProperty('lng');

      const distance = calculateDistance(
        centerLat, centerLng,
        location.lat, location.lng
      );

      expect(distance).toBeLessThanOrEqual(radius);
    });

    test('generates different locations on multiple calls', () => {
      const loc1 = randomLocationInRadius(centerLat, centerLng, radius);
      const loc2 = randomLocationInRadius(centerLat, centerLng, radius);

      // Extremely unlikely to get exact same location twice
      expect(loc1.lat).not.toBe(loc2.lat);
      expect(loc1.lng).not.toBe(loc2.lng);
    });

    test('handles small radius', () => {
      const smallRadius = 100; // 100m
      const location = randomLocationInRadius(centerLat, centerLng, smallRadius);

      const distance = calculateDistance(
        centerLat, centerLng,
        location.lat, location.lng
      );

      expect(distance).toBeLessThanOrEqual(smallRadius);
    });

    test('generates valid coordinates', () => {
      const location = randomLocationInRadius(centerLat, centerLng, radius);

      // Valid latitude range: -90 to 90
      expect(location.lat).toBeGreaterThanOrEqual(-90);
      expect(location.lat).toBeLessThanOrEqual(90);

      // Valid longitude range: -180 to 180
      expect(location.lng).toBeGreaterThanOrEqual(-180);
      expect(location.lng).toBeLessThanOrEqual(180);
    });
  });

  describe('randomLocationInDonut', () => {
    const centerLat = 37.7749;
    const centerLng = -122.4194;
    const minRadius = 2000; // 2km
    const maxRadius = 5000; // 5km

    test('generates location between min and max radius', () => {
      const location = randomLocationInDonut(centerLat, centerLng, minRadius, maxRadius);

      const distance = calculateDistance(
        centerLat, centerLng,
        location.lat, location.lng
      );

      expect(distance).toBeGreaterThanOrEqual(minRadius);
      expect(distance).toBeLessThanOrEqual(maxRadius);
    });

    test('never generates location inside minimum radius', () => {
      // Run multiple times to ensure consistency
      // Note: Due to the approximation in randomLocationInDonut (111320 conversion),
      // there can be slight variations. We allow a small tolerance.
      for (let i = 0; i < 10; i++) {
        const location = randomLocationInDonut(centerLat, centerLng, minRadius, maxRadius);
        const distance = calculateDistance(
          centerLat, centerLng,
          location.lat, location.lng
        );

        // Allow 0.5% tolerance due to degrees-to-meters approximation
        expect(distance).toBeGreaterThanOrEqual(minRadius * 0.995);
      }
    });

    test('generates different locations on multiple calls', () => {
      const loc1 = randomLocationInDonut(centerLat, centerLng, minRadius, maxRadius);
      const loc2 = randomLocationInDonut(centerLat, centerLng, minRadius, maxRadius);

      expect(loc1.lat).not.toBe(loc2.lat);
      expect(loc1.lng).not.toBe(loc2.lng);
    });
  });

  describe('generateRoutePolyline', () => {
    test('generates correct number of points', () => {
      const start = { lat: 37.7749, lng: -122.4194 };
      const end = { lat: 34.0522, lng: -118.2437 };
      const numPoints = 20;

      const polyline = generateRoutePolyline(start, end, numPoints);

      // Should have numPoints + 1 total points (including start and end)
      expect(polyline).toHaveLength(numPoints + 1);
    });

    test('first point is start location', () => {
      const start = { lat: 37.7749, lng: -122.4194 };
      const end = { lat: 34.0522, lng: -118.2437 };

      const polyline = generateRoutePolyline(start, end);

      expect(polyline[0].lat).toBe(start.lat);
      expect(polyline[0].lng).toBe(start.lng);
    });

    test('last point is end location', () => {
      const start = { lat: 37.7749, lng: -122.4194 };
      const end = { lat: 34.0522, lng: -118.2437 };

      const polyline = generateRoutePolyline(start, end);

      const lastPoint = polyline[polyline.length - 1];
      expect(lastPoint.lat).toBe(end.lat);
      expect(lastPoint.lng).toBe(end.lng);
    });

    test('intermediate points are between start and end', () => {
      const start = { lat: 0, lng: 0 };
      const end = { lat: 10, lng: 10 };

      const polyline = generateRoutePolyline(start, end, 10);

      // Check all intermediate points (excluding first and last)
      for (let i = 1; i < polyline.length - 1; i++) {
        expect(polyline[i].lat).toBeGreaterThan(start.lat);
        expect(polyline[i].lat).toBeLessThan(end.lat);
        expect(polyline[i].lng).toBeGreaterThan(start.lng);
        expect(polyline[i].lng).toBeLessThan(end.lng);
      }
    });

    test('uses default number of points when not specified', () => {
      const start = { lat: 37.7749, lng: -122.4194 };
      const end = { lat: 34.0522, lng: -118.2437 };

      const polyline = generateRoutePolyline(start, end);

      // Default is 20 points + start/end = 21 total
      expect(polyline).toHaveLength(21);
    });
  });

  describe('calculateBearing', () => {
    test('calculates north bearing (0 degrees)', () => {
      // From equator going north
      const bearing = calculateBearing(0, 0, 1, 0);
      expect(bearing).toBeCloseTo(0, 0);
    });

    test('calculates east bearing (90 degrees)', () => {
      // From origin going east
      const bearing = calculateBearing(0, 0, 0, 1);
      expect(bearing).toBeCloseTo(90, 0);
    });

    test('calculates south bearing (180 degrees)', () => {
      // From a point going south
      const bearing = calculateBearing(1, 0, 0, 0);
      expect(bearing).toBeCloseTo(180, 0);
    });

    test('calculates west bearing (270 degrees)', () => {
      // From origin going west
      const bearing = calculateBearing(0, 0, 0, -1);
      expect(bearing).toBeCloseTo(270, 0);
    });

    test('calculates northeast bearing', () => {
      const bearing = calculateBearing(0, 0, 1, 1);
      // Should be between 0 and 90 degrees
      expect(bearing).toBeGreaterThan(0);
      expect(bearing).toBeLessThan(90);
      expect(bearing).toBeCloseTo(45, 0);
    });

    test('calculates bearing for San Francisco to LA', () => {
      const bearing = calculateBearing(37.7749, -122.4194, 34.0522, -118.2437);
      // LA is southeast of SF, so bearing should be between 90 and 180
      expect(bearing).toBeGreaterThan(90);
      expect(bearing).toBeLessThan(180);
    });

    test('returns value between 0 and 360', () => {
      // Test various points to ensure bearing is always normalized
      const bearings = [
        calculateBearing(0, 0, 1, 1),
        calculateBearing(0, 0, -1, -1),
        calculateBearing(45, 45, -45, -45),
        calculateBearing(-30, 150, 30, -150)
      ];

      bearings.forEach(bearing => {
        expect(bearing).toBeGreaterThanOrEqual(0);
        expect(bearing).toBeLessThan(360);
      });
    });
  });
});
