/**
 * Model S Backend Server
 * Real-time ride-sharing backend with automatic driver simulation
 */

const express = require('express');
const cors = require('cors');
const http = require('http');
const WebSocket = require('ws');
const { router: ridesRouter, setBroadcastFunctions } = require('./routes/rides');
const { router: driversRouter } = require('./routes/drivers');
const driverPool = require('./services/driverPool');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Request logging
app.use((req, res, next) => {
  console.log(`${req.method} ${req.path}`);
  next();
});

// WebSocket connection handling
const clients = new Map(); // rideId -> Set of WebSocket clients

wss.on('connection', (ws) => {
  console.log('🔌 New WebSocket connection');

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);

      if (data.type === 'subscribe' && data.rideId) {
        // Subscribe to ride updates
        if (!clients.has(data.rideId)) {
          clients.set(data.rideId, new Set());
        }
        clients.get(data.rideId).add(ws);

        console.log(`📡 Client subscribed to ride ${data.rideId}`);

        ws.send(JSON.stringify({
          type: 'subscribed',
          rideId: data.rideId,
          message: 'Successfully subscribed to ride updates'
        }));
      }

      if (data.type === 'unsubscribe' && data.rideId) {
        // Unsubscribe from ride updates
        if (clients.has(data.rideId)) {
          clients.get(data.rideId).delete(ws);
          console.log(`📡 Client unsubscribed from ride ${data.rideId}`);
        }
      }
    } catch (error) {
      console.error('WebSocket message error:', error);
    }
  });

  ws.on('close', () => {
    console.log('🔌 WebSocket connection closed');
    // Remove from all subscriptions
    for (const [rideId, wsSet] of clients.entries()) {
      wsSet.delete(ws);
      if (wsSet.size === 0) {
        clients.delete(rideId);
      }
    }
  });

  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

// Broadcast functions for ride updates
function broadcastRideUpdate(ride) {
  const subscribers = clients.get(ride.id);
  if (subscribers) {
    const message = JSON.stringify({
      type: 'rideUpdate',
      data: ride.toJSON()
    });

    subscribers.forEach(ws => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(message);
      }
    });

    console.log(`📡 Broadcasted ride update to ${subscribers.size} clients`);
  }
}

function broadcastDriverPosition(positionUpdate) {
  const subscribers = clients.get(positionUpdate.rideId);
  if (subscribers) {
    const message = JSON.stringify({
      type: 'driverPosition',
      data: positionUpdate
    });

    subscribers.forEach(ws => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(message);
      }
    });
  }
}

// Set broadcast functions in routes
setBroadcastFunctions(broadcastRideUpdate, broadcastDriverPosition);

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Model S Backend Server',
    version: '1.0.0',
    status: 'running',
    endpoints: {
      rides: '/api/rides',
      websocket: `ws://localhost:${PORT}`
    }
  });
});

// Health check
app.get('/health', (req, res) => {
  const availableDrivers = driverPool.getAvailableDrivers();
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    drivers: {
      total: driverPool.getAllDrivers().length,
      available: availableDrivers.length
    }
  });
});

// Drivers endpoint (for debugging)
app.get('/api/drivers', (req, res) => {
  const drivers = driverPool.getAllDrivers().map(d => d.toJSON());
  res.json({
    count: drivers.length,
    drivers
  });
});

// Rides routes
app.use('/api/rides', ridesRouter);

// Driver routes
app.use('/api/drivers', driversRouter);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not found',
    message: `Route ${req.method} ${req.path} not found`
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: err.message
  });
});

// Start server
server.listen(PORT, () => {
  console.log('');
  console.log('╔════════════════════════════════════════════════╗');
  console.log('║                                                ║');
  console.log('║      🚗  Model S Backend Server  🚗           ║');
  console.log('║                                                ║');
  console.log('╚════════════════════════════════════════════════╝');
  console.log('');
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log(`📡 WebSocket available at ws://localhost:${PORT}`);
  console.log('');
  console.log('📋 Available Endpoints:');
  console.log('');
  console.log('   Rider APIs:');
  console.log(`   POST /api/rides/request         - Request a ride`);
  console.log(`   GET  /api/rides/:rideId         - Get ride status`);
  console.log(`   POST /api/rides/:rideId/cancel  - Cancel ride`);
  console.log('');
  console.log('   Driver APIs:');
  console.log(`   POST /api/drivers/login                      - Driver login`);
  console.log(`   POST /api/drivers/:id/logout                 - Driver logout`);
  console.log(`   PUT  /api/drivers/:id/availability           - Toggle availability`);
  console.log(`   PUT  /api/drivers/:id/location               - Update location`);
  console.log(`   POST /api/drivers/:id/rides/:rideId/accept   - Accept ride`);
  console.log(`   POST /api/drivers/:id/rides/:rideId/reject   - Reject ride`);
  console.log(`   PUT  /api/drivers/:id/rides/:rideId/status   - Update ride status`);
  console.log(`   GET  /api/drivers/:id/stats                  - Get driver stats`);
  console.log('');
  console.log('   System:');
  console.log(`   GET  /                          - Server info`);
  console.log(`   GET  /health                    - Health check`);
  console.log(`   GET  /api/drivers               - View all drivers (debug)`);
  console.log('');
  console.log('💡 Ready to receive ride requests from iOS app!');
  console.log('');

  // Log available drivers
  const drivers = driverPool.getAllDrivers();
  console.log(`👥 Active drivers: ${drivers.length}`);
  drivers.slice(0, 3).forEach(d => {
    console.log(`   - ${d.name} (${d.vehicleModel}) - ${d.rating}⭐`);
  });
  if (drivers.length > 3) {
    console.log(`   ... and ${drivers.length - 3} more`);
  }
  console.log('');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
  });
});

process.on('SIGINT', () => {
  console.log('\n👋 Shutting down gracefully...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});
