/**
 * Ride Request Simulator
 * Generates simulated ride requests for driver app testing
 */

// Predefined locations around San Francisco for realistic ride requests
// Featuring famous San Francisco landmarks and neighborhoods
const PICKUP_LOCATIONS = [
  // Classic SF Landmarks
  { lat: 37.8199, lng: -122.4783, address: 'Golden Gate Bridge Vista Point' },
  { lat: 37.8267, lng: -122.4230, address: 'Alcatraz Ferry Terminal (Pier 33)' },
  { lat: 37.8024, lng: -122.4058, address: 'Coit Tower' },
  { lat: 37.7952, lng: -122.4028, address: 'Transamerica Pyramid' },
  { lat: 37.7847, lng: -122.4089, address: 'Cable Car Turnaround (Powell & Market)' },
  { lat: 37.7941, lng: -122.4078, address: 'Chinatown Gate (Grant Avenue)' },
  { lat: 37.8058, lng: -122.4227, address: 'Ghirardelli Square' },
  { lat: 37.8020, lng: -122.4485, address: 'Palace of Fine Arts' },
  { lat: 37.7544, lng: -122.4477, address: 'Twin Peaks Summit' },
  { lat: 37.7786, lng: -122.3893, address: 'Oracle Park (Giants Stadium)' },

  // Popular Neighborhoods
  { lat: 37.7749, lng: -122.4194, address: 'Union Square' },
  { lat: 37.7599, lng: -122.3934, address: 'Mission District (Valencia St)' },
  { lat: 37.7692, lng: -122.4481, address: 'Haight-Ashbury' },
  { lat: 37.7609, lng: -122.4350, address: 'Castro Theatre' },
  { lat: 37.7764, lng: -122.4330, address: 'Alamo Square (Painted Ladies)' },
  { lat: 37.7989, lng: -122.4662, address: 'Presidio Main Post' },
  { lat: 37.8080, lng: -122.4177, address: 'Fisherman\'s Wharf' },
  { lat: 37.7955, lng: -122.3937, address: 'Ferry Building Marketplace' },

  // Waterfront & Parks
  { lat: 37.8024, lng: -122.4058, address: 'Pier 39' },
  { lat: 37.7694, lng: -122.5107, address: 'Ocean Beach' },
  { lat: 37.7577, lng: -122.4376, address: 'Golden Gate Park (de Young Museum)' },
  { lat: 37.7946, lng: -122.3999, address: 'Embarcadero Center' },
  { lat: 37.8029, lng: -122.4484, address: 'Marina Green' },
  { lat: 37.7699, lng: -122.4661, address: 'UCSF Medical Center' }
];

const DESTINATION_LOCATIONS = [
  // Airports & Transit Hubs
  { lat: 37.6213, lng: -122.3790, address: 'San Francisco International Airport (SFO)' },
  { lat: 37.7126, lng: -122.2197, address: 'Oakland International Airport (OAK)' },
  { lat: 37.7765, lng: -122.3947, address: 'Caltrain Station (4th & King)' },

  // Classic SF Landmarks
  { lat: 37.8199, lng: -122.4783, address: 'Golden Gate Bridge Welcome Center' },
  { lat: 37.8024, lng: -122.4058, address: 'Pier 39 (Sea Lions)' },
  { lat: 37.7955, lng: -122.3937, address: 'Ferry Building Marketplace' },
  { lat: 37.8058, lng: -122.4227, address: 'Ghirardelli Square' },
  { lat: 37.8020, lng: -122.4485, address: 'Palace of Fine Arts Theatre' },
  { lat: 37.7697, lng: -122.4665, address: 'California Academy of Sciences' },
  { lat: 37.7855, lng: -122.4009, address: 'SFMOMA (Museum of Modern Art)' },

  // Bay Area Destinations
  { lat: 37.8590, lng: -122.4852, address: 'Sausalito Downtown' },
  { lat: 37.8715, lng: -122.2730, address: 'UC Berkeley Campus' },
  { lat: 37.8044, lng: -122.2712, address: 'Jack London Square (Oakland)' },
  { lat: 37.4275, lng: -122.1697, address: 'Stanford University' },
  { lat: 37.3382, lng: -121.8863, address: 'San Jose Downtown' },

  // Shopping & Entertainment
  { lat: 37.7749, lng: -122.4194, address: 'Union Square Shopping' },
  { lat: 37.7856, lng: -122.4089, address: 'Westfield San Francisco Centre' },
  { lat: 37.7786, lng: -122.3893, address: 'Oracle Park (Giants Game)' },
  { lat: 37.7679, lng: -122.3874, address: 'Chase Center (Warriors Arena)' },

  // Neighborhoods
  { lat: 37.7525, lng: -122.4475, address: 'Noe Valley' },
  { lat: 37.7879, lng: -122.4702, address: 'Inner Richmond' },
  { lat: 37.7648, lng: -122.4185, address: 'Dolores Park' },
  { lat: 37.7941, lng: -122.4078, address: 'Chinatown (Portsmouth Square)' },
  { lat: 37.7849, lng: -122.4094, address: 'Moscone Center' }
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
