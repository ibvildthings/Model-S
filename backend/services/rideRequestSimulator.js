/**
 * Ride Request Simulator
 * Generates simulated ride requests for driver app testing
 */

// Predefined locations around San Francisco featuring famous landmarks
const PICKUP_LOCATIONS = [
  // Iconic Landmarks
  { lat: 37.8199, lng: -122.4783, address: 'Golden Gate Bridge Welcome Center' },
  { lat: 37.8267, lng: -122.4230, address: 'Alcatraz Ferry Terminal' },
  { lat: 37.8024, lng: -122.4058, address: 'Pier 39' },
  { lat: 37.8080, lng: -122.4177, address: 'Fisherman\'s Wharf' },
  { lat: 37.8025, lng: -122.4382, address: 'Palace of Fine Arts' },
  { lat: 37.8324, lng: -122.4795, address: 'Point Bonita Lighthouse' },

  // Downtown & Financial District
  { lat: 37.7952, lng: -122.4028, address: 'Transamerica Pyramid' },
  { lat: 37.7897, lng: -122.3969, address: 'Salesforce Tower' },
  { lat: 37.7955, lng: -122.3937, address: 'Ferry Building Marketplace' },
  { lat: 37.7879, lng: -122.4074, address: 'Union Square' },
  { lat: 37.7941, lng: -122.3951, address: 'Embarcadero Center' },

  // Cultural Neighborhoods
  { lat: 37.7941, lng: -122.4078, address: 'Chinatown Gate' },
  { lat: 37.7989, lng: -122.4117, address: 'North Beach - Little Italy' },
  { lat: 37.7692, lng: -122.4481, address: 'Haight-Ashbury' },
  { lat: 37.7609, lng: -122.4350, address: 'Castro Theatre' },
  { lat: 37.7599, lng: -122.4148, address: 'Mission Dolores' },

  // Parks & Nature
  { lat: 37.7694, lng: -122.4862, address: 'Ocean Beach' },
  { lat: 37.7701, lng: -122.4686, address: 'Japanese Tea Garden' },
  { lat: 37.7699, lng: -122.4661, address: 'California Academy of Sciences' },
  { lat: 37.7749, lng: -122.4194, address: 'Civic Center Plaza' },
  { lat: 37.7756, lng: -122.4193, address: 'San Francisco City Hall' },

  // Scenic Viewpoints
  { lat: 37.8022, lng: -122.4060, address: 'Coit Tower' },
  { lat: 37.8021, lng: -122.4186, address: 'Lombard Street - Crooked Street' },
  { lat: 37.7763, lng: -122.4351, address: 'Painted Ladies - Alamo Square' },
  { lat: 37.7544, lng: -122.4477, address: 'Twin Peaks Summit' }
];

const DESTINATION_LOCATIONS = [
  // Iconic Landmarks
  { lat: 37.8199, lng: -122.4783, address: 'Golden Gate Bridge Vista Point' },
  { lat: 37.8267, lng: -122.4230, address: 'Alcatraz Island Ferry' },
  { lat: 37.8080, lng: -122.4177, address: 'Fisherman\'s Wharf' },
  { lat: 37.8006, lng: -122.3982, address: 'Exploratorium' },
  { lat: 37.8025, lng: -122.4382, address: 'Palace of Fine Arts Theatre' },

  // Sports & Entertainment
  { lat: 37.7786, lng: -122.3893, address: 'Oracle Park - Giants Stadium' },
  { lat: 37.7680, lng: -122.3875, address: 'Chase Center - Warriors Arena' },
  { lat: 37.8071, lng: -122.4340, address: 'Fort Mason Center' },
  { lat: 37.7853, lng: -122.4089, address: 'San Francisco Museum of Modern Art' },

  // Shopping & Dining
  { lat: 37.8085, lng: -122.4180, address: 'Ghirardelli Square' },
  { lat: 37.7879, lng: -122.4074, address: 'Union Square Shopping' },
  { lat: 37.7955, lng: -122.3937, address: 'Ferry Building Farmers Market' },
  { lat: 37.8026, lng: -122.4184, address: 'Pier 39 Sea Lions' },

  // Neighborhoods
  { lat: 37.7989, lng: -122.4117, address: 'North Beach Cafes' },
  { lat: 37.7941, lng: -122.4078, address: 'Chinatown' },
  { lat: 37.7692, lng: -122.4481, address: 'Haight Street' },
  { lat: 37.7609, lng: -122.4350, address: 'Castro District' },
  { lat: 37.7599, lng: -122.4148, address: 'Mission District' },

  // Parks & Recreation
  { lat: 37.7694, lng: -122.4862, address: 'Ocean Beach Sunset' },
  { lat: 37.7695, lng: -122.4663, address: 'de Young Museum' },
  { lat: 37.7700, lng: -122.5112, address: 'Cliff House & Sutro Baths' },
  { lat: 37.8004, lng: -122.4597, address: 'Presidio Main Post' },

  // Transportation Hubs
  { lat: 37.6213, lng: -122.3790, address: 'San Francisco International Airport' },
  { lat: 37.7764, lng: -122.4168, address: 'Civic Center BART Station' },
  { lat: 37.7847, lng: -122.4089, address: 'Powell Street Cable Car' }
];

// Active simulators for each driver
const activeSimulators = new Map(); // driverId -> interval

/**
 * Start generating simulated ride requests for a driver
 */
function startSimulation(driverId, onRideRequest) {
  // Don't start if already running
  if (activeSimulators.has(driverId)) {
    console.log(`⚠️ Ride request simulator already running for driver ${driverId}`);
    return;
  }

  console.log(`🎬 Starting ride request simulator for driver ${driverId}`);

  // Generate first request immediately
  setTimeout(() => generateRideRequest(driverId, onRideRequest), 2000);

  // Then generate periodic requests
  const interval = setInterval(() => {
    generateRideRequest(driverId, onRideRequest);
  }, 15000); // New request every 15 seconds

  activeSimulators.set(driverId, interval);
}

/**
 * Stop generating simulated ride requests
 */
function stopSimulation(driverId) {
  const interval = activeSimulators.get(driverId);

  if (interval) {
    clearInterval(interval);
    activeSimulators.delete(driverId);
    console.log(`🛑 Stopped ride request simulator for driver ${driverId}`);
  }
}

/**
 * Generate a single ride request immediately (useful after rejection)
 */
function generateSingleRequest(driverId, onRideRequest) {
  generateRideRequest(driverId, onRideRequest);
}

/**
 * Generate a random ride request
 */
function generateRideRequest(driverId, onRideRequest) {
  // Random pickup and destination
  const pickup = PICKUP_LOCATIONS[Math.floor(Math.random() * PICKUP_LOCATIONS.length)];
  const destination = DESTINATION_LOCATIONS[Math.floor(Math.random() * DESTINATION_LOCATIONS.length)];

  // Avoid same pickup and destination
  if (pickup.address === destination.address) {
    return generateRideRequest(driverId, onRideRequest);
  }

  // Calculate distance
  const distance = calculateDistance(pickup.lat, pickup.lng, destination.lat, destination.lng);

  // Calculate estimated earnings
  const distanceKm = distance / 1000;
  const baseFare = 2.0;
  const perKm = 1.5;
  const estimatedEarnings = parseFloat((baseFare + distanceKm * perKm).toFixed(2));

  const rideRequest = {
    pickup,
    destination,
    distance: Math.round(distance),
    estimatedEarnings,
    expiresAt: new Date(Date.now() + 30000).toISOString() // 30 second expiry
  };

  console.log(`📱 Simulated ride request for driver ${driverId}:`);
  console.log(`   Pickup: ${pickup.address}`);
  console.log(`   Destination: ${destination.address}`);
  console.log(`   Distance: ${Math.round(distance)}m`);
  console.log(`   Earnings: $${estimatedEarnings}`);

  // Notify callback
  if (onRideRequest) {
    onRideRequest(rideRequest);
  }
}

/**
 * Simple distance calculation (Haversine formula)
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Earth's radius in meters
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

module.exports = {
  startSimulation,
  stopSimulation,
  generateSingleRequest
};
