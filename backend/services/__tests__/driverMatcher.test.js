/**
 * Unit tests for driverMatcher
 * Tests the critical driver matching algorithm that finds nearest available drivers
 */

const driverMatcher = require('../driverMatcher');
const driverPool = require('../driverPool');

// Mock the driverPool to control test scenarios
jest.mock('../driverPool');

describe('DriverMatcher', () => {

  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks();
  });

  describe('findNearestDriver', () => {
    test('finds nearest driver when multiple drivers available', () => {
      const pickupLocation = { lat: 37.7749, lng: -122.4194 }; // San Francisco

      const mockDrivers = [
        {
          id: 'driver1',
          name: 'John Doe',
          location: { lat: 37.7849, lng: -122.4094 }, // ~1.4 km away (closest)
          rating: 4.8,
          vehicle: { make: 'Toyota', model: 'Camry', color: 'Silver', plate: 'ABC123' }
        },
        {
          id: 'driver2',
          name: 'Jane Smith',
          location: { lat: 37.7649, lng: -122.4294 }, // ~1.6 km away
          rating: 4.9,
          vehicle: { make: 'Honda', model: 'Accord', color: 'Black', plate: 'XYZ789' }
        },
        {
          id: 'driver3',
          name: 'Bob Johnson',
          location: { lat: 37.8049, lng: -122.3994 }, // ~3 km away
          rating: 4.7,
          vehicle: { make: 'Ford', model: 'Fusion', color: 'White', plate: 'DEF456' }
        }
      ];

      driverPool.getAvailableDrivers.mockReturnValue(mockDrivers);

      const result = driverMatcher.findNearestDriver(pickupLocation);

      expect(result).not.toBeNull();
      expect(result.driver.id).toBe('driver1'); // John is closest
      expect(result.distance).toBeLessThan(2000); // Less than 2km
      expect(result.eta).toBeGreaterThan(0);
    });

    test('returns null when no drivers available', () => {
      const pickupLocation = { lat: 37.7749, lng: -122.4194 };

      driverPool.getAvailableDrivers.mockReturnValue([]);

      const result = driverMatcher.findNearestDriver(pickupLocation);

      expect(result).toBeNull();
      expect(driverPool.getAvailableDrivers).toHaveBeenCalledTimes(1);
    });

    test('handles single available driver', () => {
      const pickupLocation = { lat: 37.7749, lng: -122.4194 };

      const mockDrivers = [
        {
          id: 'driver1',
          name: 'John Doe',
          location: { lat: 37.7849, lng: -122.4094 },
          rating: 4.8,
          vehicle: { make: 'Toyota', model: 'Camry', color: 'Silver', plate: 'ABC123' }
        }
      ];

      driverPool.getAvailableDrivers.mockReturnValue(mockDrivers);

      const result = driverMatcher.findNearestDriver(pickupLocation);

      expect(result).not.toBeNull();
      expect(result.driver.id).toBe('driver1');
      expect(result.distance).toBeGreaterThan(0);
    });

    test('correctly calculates distance to each driver', () => {
      const pickupLocation = { lat: 37.7749, lng: -122.4194 };

      const mockDrivers = [
        {
          id: 'driver1',
          name: 'John Doe',
          location: { lat: 37.7849, lng: -122.4094 }, // About 1.5 km
          rating: 4.8,
          vehicle: { make: 'Toyota', model: 'Camry', color: 'Silver', plate: 'ABC123' }
        }
      ];

      driverPool.getAvailableDrivers.mockReturnValue(mockDrivers);

      const result = driverMatcher.findNearestDriver(pickupLocation);

      // Distance should be roughly 1500m (allow 500m margin due to approximation)
      expect(result.distance).toBeGreaterThan(1000);
      expect(result.distance).toBeLessThan(2000);
    });

    test('includes ETA in result', () => {
      const pickupLocation = { lat: 37.7749, lng: -122.4194 };

      const mockDrivers = [
        {
          id: 'driver1',
          name: 'John Doe',
          location: { lat: 37.7799, lng: -122.4194 }, // About 550m north
          rating: 4.8,
          vehicle: { make: 'Toyota', model: 'Camry', color: 'Silver', plate: 'ABC123' }
        }
      ];

      driverPool.getAvailableDrivers.mockReturnValue(mockDrivers);

      const result = driverMatcher.findNearestDriver(pickupLocation);

      expect(result.eta).toBeGreaterThan(0);
      expect(typeof result.eta).toBe('number');
      // For ~500m at 40 km/h, ETA should be around 45 seconds
      expect(result.eta).toBeGreaterThan(30);
      expect(result.eta).toBeLessThan(90);
    });

    test('selects closest driver regardless of rating', () => {
      const pickupLocation = { lat: 37.7749, lng: -122.4194 };

      const mockDrivers = [
        {
          id: 'driver1',
          name: 'High Rating Far',
          location: { lat: 37.8049, lng: -122.3994 }, // ~3 km away
          rating: 5.0, // Highest rating
          vehicle: { make: 'Tesla', model: 'Model S', color: 'Black', plate: 'TESLA1' }
        },
        {
          id: 'driver2',
          name: 'Low Rating Close',
          location: { lat: 37.7759, lng: -122.4204 }, // ~100m away (closest)
          rating: 4.0, // Lower rating
          vehicle: { make: 'Toyota', model: 'Corolla', color: 'White', plate: 'ABC123' }
        }
      ];

      driverPool.getAvailableDrivers.mockReturnValue(mockDrivers);

      const result = driverMatcher.findNearestDriver(pickupLocation);

      // Should select driver2 despite lower rating because they're closest
      expect(result.driver.id).toBe('driver2');
    });

    test('handles drivers at exact same location as pickup', () => {
      const pickupLocation = { lat: 37.7749, lng: -122.4194 };

      const mockDrivers = [
        {
          id: 'driver1',
          name: 'Same Location',
          location: { lat: 37.7749, lng: -122.4194 }, // Exact same location
          rating: 4.5,
          vehicle: { make: 'Toyota', model: 'Camry', color: 'Silver', plate: 'ABC123' }
        }
      ];

      driverPool.getAvailableDrivers.mockReturnValue(mockDrivers);

      const result = driverMatcher.findNearestDriver(pickupLocation);

      expect(result).not.toBeNull();
      expect(result.driver.id).toBe('driver1');
      expect(result.distance).toBe(0);
      expect(result.eta).toBe(0);
    });

    test('handles edge case of very close drivers', () => {
      const pickupLocation = { lat: 37.7749, lng: -122.4194 };

      // Two drivers within 10 meters of each other
      const mockDrivers = [
        {
          id: 'driver1',
          name: 'Driver 1',
          location: { lat: 37.77491, lng: -122.41941 },
          rating: 4.5,
          vehicle: { make: 'Toyota', model: 'Camry', color: 'Silver', plate: 'ABC123' }
        },
        {
          id: 'driver2',
          name: 'Driver 2',
          location: { lat: 37.77492, lng: -122.41942 },
          rating: 4.5,
          vehicle: { make: 'Honda', model: 'Civic', color: 'Black', plate: 'XYZ789' }
        }
      ];

      driverPool.getAvailableDrivers.mockReturnValue(mockDrivers);

      const result = driverMatcher.findNearestDriver(pickupLocation);

      expect(result).not.toBeNull();
      // Should pick one of them (driver1 is slightly closer)
      expect(['driver1', 'driver2']).toContain(result.driver.id);
      expect(result.distance).toBeLessThan(20); // Very close
    });
  });

  describe('matchRideToDriver', () => {
    beforeEach(() => {
      // Use fake timers to control setTimeout
      jest.useFakeTimers();
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    test('calls callback with matched driver after delay', () => {
      const ride = {
        id: 'ride123',
        pickup: { lat: 37.7749, lng: -122.4194 },
        destination: { lat: 37.8049, lng: -122.3994 }
      };

      const mockDrivers = [
        {
          id: 'driver1',
          name: 'John Doe',
          location: { lat: 37.7799, lng: -122.4194 },
          rating: 4.8,
          vehicle: { make: 'Toyota', model: 'Camry', color: 'Silver', plate: 'ABC123' }
        }
      ];

      driverPool.getAvailableDrivers.mockReturnValue(mockDrivers);

      const onMatchCallback = jest.fn();
      driverMatcher.matchRideToDriver(ride, onMatchCallback);

      // Callback should not be called immediately
      expect(onMatchCallback).not.toHaveBeenCalled();

      // Fast-forward time by 5 seconds (max delay is 4 seconds)
      jest.advanceTimersByTime(5000);

      // Now callback should have been called
      expect(onMatchCallback).toHaveBeenCalledTimes(1);
      expect(onMatchCallback).toHaveBeenCalledWith(
        expect.objectContaining({
          driver: expect.objectContaining({ id: 'driver1' }),
          distance: expect.any(Number),
          eta: expect.any(Number)
        })
      );
    });

    test('calls callback with null when no drivers available', () => {
      const ride = {
        id: 'ride123',
        pickup: { lat: 37.7749, lng: -122.4194 },
        destination: { lat: 37.8049, lng: -122.3994 }
      };

      driverPool.getAvailableDrivers.mockReturnValue([]);

      const onMatchCallback = jest.fn();
      driverMatcher.matchRideToDriver(ride, onMatchCallback);

      // Fast-forward time
      jest.advanceTimersByTime(5000);

      expect(onMatchCallback).toHaveBeenCalledTimes(1);
      expect(onMatchCallback).toHaveBeenCalledWith(null);
    });

    test('simulates realistic search delay', () => {
      const ride = {
        id: 'ride123',
        pickup: { lat: 37.7749, lng: -122.4194 },
        destination: { lat: 37.8049, lng: -122.3994 }
      };

      const mockDrivers = [
        {
          id: 'driver1',
          name: 'John Doe',
          location: { lat: 37.7799, lng: -122.4194 },
          rating: 4.8,
          vehicle: { make: 'Toyota', model: 'Camry', color: 'Silver', plate: 'ABC123' }
        }
      ];

      driverPool.getAvailableDrivers.mockReturnValue(mockDrivers);

      const onMatchCallback = jest.fn();
      driverMatcher.matchRideToDriver(ride, onMatchCallback);

      // Should not be called after 1 second (min delay is 2 seconds)
      jest.advanceTimersByTime(1000);
      expect(onMatchCallback).not.toHaveBeenCalled();

      // Should be called after 5 seconds (max delay is 4 seconds)
      jest.advanceTimersByTime(4000);
      expect(onMatchCallback).toHaveBeenCalledTimes(1);
    });
  });
});
