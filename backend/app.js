/**
 * Express application (HTTP routes only).
 * Kept separate from server.js so tests can exercise routes with supertest
 * without opening a port or a WebSocket server.
 */

const express = require('express');
const cors = require('cors');
const { router: ridesRouter } = require('./routes/rides');
const { router: driversRouter } = require('./routes/drivers');
const driverPool = require('./services/driverPool');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Request logging (quiet under test)
if (process.env.NODE_ENV !== 'test') {
  app.use((req, res, next) => {
    console.log(`${req.method} ${req.path}`);
    next();
  });
}

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Model S Backend Server',
    version: '1.0.0',
    status: 'running',
    endpoints: {
      rides: '/api/rides',
      websocket: `ws://${req.headers.host || 'localhost'}`
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

module.exports = app;
