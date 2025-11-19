/**
 * Centralized Geographic Configuration
 * Single source of truth for all mock data locations, driver spawning, and ride patterns
 */

const activeRegion = process.env.MOCK_REGION || 'sf_bay_area';

const regions = {
  sf_bay_area: {
    name: 'San Francisco Bay Area',
    // Unified center point - Union Square area
    center: { lat: 37.7879, lng: -122.4074 },

    // Default map span for zooming
    defaultSpan: { latDelta: 0.05, lngDelta: 0.05 },

    // Driver spawn configuration
    driverSpawn: {
      minRadius: 1000,  // 1 km
      maxRadius: 5000   // 5 km
    },

    // Categorized locations for realistic ride patterns
    locations: {
      residential: [
        { lat: 37.7599, lng: -122.4148, address: 'Mission Dolores' },
        { lat: 37.7692, lng: -122.4481, address: 'Haight-Ashbury' },
        { lat: 37.7609, lng: -122.4350, address: 'Castro District' },
        { lat: 37.7544, lng: -122.4477, address: 'Twin Peaks' },
        { lat: 37.7763, lng: -122.4351, address: 'Alamo Square' },
        { lat: 37.7850, lng: -122.4383, address: 'Western Addition' },
        { lat: 37.8021, lng: -122.4186, address: 'Russian Hill' },
        { lat: 37.7989, lng: -122.4269, address: 'Pacific Heights' }
      ],

      business: [
        { lat: 37.7952, lng: -122.4028, address: 'Transamerica Pyramid' },
        { lat: 37.7897, lng: -122.3969, address: 'Salesforce Tower' },
        { lat: 37.7941, lng: -122.3951, address: 'Embarcadero Center' },
        { lat: 37.7879, lng: -122.4074, address: 'Union Square' },
        { lat: 37.7853, lng: -122.4089, address: 'SFMOMA' },
        { lat: 37.7786, lng: -122.3893, address: 'Oracle Park' },
        { lat: 37.7680, lng: -122.3875, address: 'Chase Center' },
        { lat: 37.7749, lng: -122.4194, address: 'Civic Center' }
      ],

      entertainment: [
        { lat: 37.8080, lng: -122.4177, address: 'Fisherman\'s Wharf' },
        { lat: 37.8024, lng: -122.4058, address: 'Pier 39' },
        { lat: 37.8085, lng: -122.4180, address: 'Ghirardelli Square' },
        { lat: 37.8025, lng: -122.4382, address: 'Palace of Fine Arts' },
        { lat: 37.8071, lng: -122.4340, address: 'Fort Mason Center' },
        { lat: 37.7989, lng: -122.4117, address: 'North Beach' },
        { lat: 37.7941, lng: -122.4078, address: 'Chinatown' },
        { lat: 37.7694, lng: -122.4862, address: 'Ocean Beach' }
      ],

      transit: [
        { lat: 37.6213, lng: -122.3790, address: 'San Francisco International Airport' },
        { lat: 37.7764, lng: -122.4168, address: 'Civic Center BART' },
        { lat: 37.7847, lng: -122.4089, address: 'Powell Street Station' },
        { lat: 37.7955, lng: -122.3937, address: 'Ferry Building' },
        { lat: 37.7793, lng: -122.4139, address: 'Montgomery Street BART' },
        { lat: 37.7844, lng: -122.4080, address: 'Powell Street Cable Car' }
      ],

      landmarks: [
        { lat: 37.8199, lng: -122.4783, address: 'Golden Gate Bridge' },
        { lat: 37.8267, lng: -122.4230, address: 'Alcatraz Ferry' },
        { lat: 37.8022, lng: -122.4060, address: 'Coit Tower' },
        { lat: 37.7756, lng: -122.4193, address: 'City Hall' },
        { lat: 37.7699, lng: -122.4661, address: 'California Academy of Sciences' },
        { lat: 37.7701, lng: -122.4686, address: 'Japanese Tea Garden' }
      ]
    },

    // Driver distribution zones for realistic spawning
    driverZones: [
      { name: 'downtown', center: { lat: 37.7879, lng: -122.4074 }, weight: 0.25, radius: 1500 },
      { name: 'soma', center: { lat: 37.7785, lng: -122.3950 }, weight: 0.20, radius: 1200 },
      { name: 'mission', center: { lat: 37.7599, lng: -122.4148 }, weight: 0.15, radius: 1500 },
      { name: 'marina', center: { lat: 37.8025, lng: -122.4382 }, weight: 0.10, radius: 1000 },
      { name: 'richmond', center: { lat: 37.7800, lng: -122.4700 }, weight: 0.10, radius: 1500 },
      { name: 'sunset', center: { lat: 37.7600, lng: -122.4800 }, weight: 0.10, radius: 1500 },
      { name: 'airport', center: { lat: 37.6213, lng: -122.3790 }, weight: 0.10, radius: 2000 }
    ]
  }
};

// Ride patterns that model real-world Uber behavior
const ridePatterns = {
  morning_commute: {
    weight: 0.35,
    pickup: ['residential'],
    destination: ['business', 'transit'],
    timeRange: [6, 10],
    description: 'Morning commute to work'
  },
  evening_commute: {
    weight: 0.25,
    pickup: ['business'],
    destination: ['residential', 'entertainment'],
    timeRange: [17, 20],
    description: 'Evening commute home or to dinner'
  },
  airport_dropoff: {
    weight: 0.10,
    pickup: ['residential', 'business'],
    destination: ['transit'],
    timeRange: 'all',
    description: 'Trip to airport/station'
  },
  airport_pickup: {
    weight: 0.10,
    pickup: ['transit'],
    destination: ['residential', 'business'],
    timeRange: 'all',
    description: 'Trip from airport/station'
  },
  tourist: {
    weight: 0.10,
    pickup: ['landmarks', 'entertainment'],
    destination: ['landmarks', 'entertainment'],
    timeRange: [9, 18],
    description: 'Tourist sightseeing'
  },
  nightlife: {
    weight: 0.10,
    pickup: ['entertainment', 'business'],
    destination: ['residential'],
    timeRange: [21, 3],
    description: 'Late night return home'
  }
};

/**
 * Get the active region configuration
 */
function getActiveRegion() {
  return regions[activeRegion];
}

/**
 * Get all locations flattened into pickup and destination arrays
 * (For backwards compatibility)
 */
function getAllLocations() {
  const region = getActiveRegion();
  const allLocations = [];

  Object.values(region.locations).forEach(categoryLocations => {
    allLocations.push(...categoryLocations);
  });

  return allLocations;
}

/**
 * Get locations by category
 */
function getLocationsByCategory(category) {
  const region = getActiveRegion();
  return region.locations[category] || [];
}

/**
 * Get a random location from specified categories
 */
function getRandomLocation(categories) {
  const region = getActiveRegion();
  const categoryArray = Array.isArray(categories) ? categories : [categories];

  // Collect all locations from specified categories
  const locations = [];
  categoryArray.forEach(cat => {
    if (region.locations[cat]) {
      locations.push(...region.locations[cat]);
    }
  });

  if (locations.length === 0) {
    // Fallback to all locations
    return getAllLocations()[Math.floor(Math.random() * getAllLocations().length)];
  }

  return locations[Math.floor(Math.random() * locations.length)];
}

/**
 * Select a ride pattern based on current time and weights
 */
function selectRidePattern() {
  const currentHour = new Date().getHours();

  // Filter patterns that are active at current time
  const activePatterns = Object.entries(ridePatterns).filter(([_, pattern]) => {
    if (pattern.timeRange === 'all') return true;

    const [start, end] = pattern.timeRange;
    if (start <= end) {
      return currentHour >= start && currentHour < end;
    } else {
      // Handles overnight ranges like [21, 3]
      return currentHour >= start || currentHour < end;
    }
  });

  // If no patterns match current time, use all patterns
  const patternsToUse = activePatterns.length > 0 ? activePatterns : Object.entries(ridePatterns);

  // Weighted random selection
  const totalWeight = patternsToUse.reduce((sum, [_, p]) => sum + p.weight, 0);
  let random = Math.random() * totalWeight;

  for (const [name, pattern] of patternsToUse) {
    random -= pattern.weight;
    if (random <= 0) {
      return { name, ...pattern };
    }
  }

  // Fallback
  const [name, pattern] = patternsToUse[0];
  return { name, ...pattern };
}

/**
 * Generate a ride based on realistic patterns
 */
function generatePatternBasedRide() {
  const pattern = selectRidePattern();

  const pickup = getRandomLocation(pattern.pickup);
  let destination = getRandomLocation(pattern.destination);

  // Ensure pickup and destination are different
  let attempts = 0;
  while (pickup.address === destination.address && attempts < 10) {
    destination = getRandomLocation(pattern.destination);
    attempts++;
  }

  return {
    pickup,
    destination,
    pattern: pattern.name,
    description: pattern.description
  };
}

/**
 * Get driver zones for distributed spawning
 */
function getDriverZones() {
  return getActiveRegion().driverZones;
}

/**
 * Select a zone for driver spawning based on weights
 */
function selectDriverZone() {
  const zones = getDriverZones();
  const totalWeight = zones.reduce((sum, z) => sum + z.weight, 0);
  let random = Math.random() * totalWeight;

  for (const zone of zones) {
    random -= zone.weight;
    if (random <= 0) {
      return zone;
    }
  }

  return zones[0];
}

module.exports = {
  activeRegion,
  regions,
  ridePatterns,
  getActiveRegion,
  getAllLocations,
  getLocationsByCategory,
  getRandomLocation,
  selectRidePattern,
  generatePatternBasedRide,
  getDriverZones,
  selectDriverZone
};
