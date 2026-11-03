/**
 * HTTP route tests (supertest against app.js — no port, no WebSocket).
 * Timer-driven simulations are mocked so tests are fast and deterministic.
 */

jest.mock('../../services/driverMatcher', () => ({
  matchRideToDriver: jest.fn()
}));
jest.mock('../../services/driverSimulator', () => ({
  startSimulation: jest.fn(),
  stopSimulation: jest.fn()
}));
jest.mock('../../services/rideRequestSimulator', () => ({
  startSimulation: jest.fn(),
  stopSimulation: jest.fn()
}));

const request = require('supertest');
const app = require('../../app');
const rideStore = require('../../store/rideStore');
const driverStore = require('../../store/driverStore');
const driverPool = require('../../services/driverPool');
const driverMatcher = require('../../services/driverMatcher');
const driverSimulator = require('../../services/driverSimulator');

const UNION_SQUARE = { lat: 37.7879, lng: -122.4074 };
const TRANSAMERICA = { lat: 37.7952, lng: -122.4028 };

beforeAll(() => {
  jest.spyOn(console, 'log').mockImplementation(() => {});
});

afterAll(() => {
  console.log.mockRestore();
});

beforeEach(() => {
  rideStore.clear();
  driverStore.clear();
  jest.clearAllMocks();
  driverPool.getAllDrivers().forEach(d => {
    d.available = true;
    d.currentRideId = null;
  });
});

function requestRide(body = { pickup: UNION_SQUARE, destination: TRANSAMERICA }) {
  return request(app).post('/api/rides/request').send(body);
}

describe('POST /api/rides/request', () => {
  it('creates a ride and returns 201 with its id', async () => {
    const res = await requestRide();

    expect(res.status).toBe(201);
    expect(res.body.rideId).toEqual(expect.any(String));
    expect(res.body.pickup).toEqual(UNION_SQUARE);
    expect(rideStore.get(res.body.rideId)).toBeDefined();
  });

  it('uses a simulated driver when no driver is logged in', async () => {
    await requestRide();
    expect(driverMatcher.matchRideToDriver).toHaveBeenCalledTimes(1);
  });

  it.each([
    ['missing pickup', { destination: TRANSAMERICA }, 'Invalid pickup location'],
    ['non-numeric pickup', { pickup: { lat: 'a', lng: 1 }, destination: TRANSAMERICA }, 'Invalid pickup location'],
    ['out-of-range destination', { pickup: UNION_SQUARE, destination: { lat: 120, lng: 0 } }, 'Invalid destination location']
  ])('rejects %s with 400', async (_, body, error) => {
    const res = await requestRide(body);

    expect(res.status).toBe(400);
    expect(res.body.error).toBe(error);
    expect(rideStore.all()).toHaveLength(0);
  });

  it('accepts coordinates of 0 (equator / prime meridian)', async () => {
    const res = await requestRide({ pickup: { lat: 0, lng: 0 }, destination: { lat: 0.01, lng: 0 } });
    expect(res.status).toBe(201);
  });
});

describe('GET /api/rides/:rideId', () => {
  it('returns the ride', async () => {
    const { body: created } = await requestRide();

    const res = await request(app).get(`/api/rides/${created.rideId}`);

    expect(res.status).toBe(200);
    expect(res.body.rideId).toBe(created.rideId);
    expect(res.body.status).toBe('searching');
    expect(res.body.driver).toBeNull();
  });

  it('returns 404 for an unknown ride', async () => {
    const res = await request(app).get('/api/rides/does-not-exist');
    expect(res.status).toBe(404);
  });
});

describe('POST /api/rides/:rideId/cancel', () => {
  it('cancels the ride and stops its simulation', async () => {
    const { body: created } = await requestRide();

    const res = await request(app).post(`/api/rides/${created.rideId}/cancel`);

    expect(res.status).toBe(200);
    expect(res.body.ride.status).toBe('cancelled');
    expect(driverSimulator.stopSimulation).toHaveBeenCalledWith(created.rideId);
  });

  it('returns 404 for an unknown ride', async () => {
    const res = await request(app).post('/api/rides/nope/cancel');
    expect(res.status).toBe(404);
  });
});

describe('real driver flow (driver app logged in)', () => {
  const driver = () => driverPool.getAllDrivers()[0];

  async function login() {
    const res = await request(app)
      .post('/api/drivers/login')
      .send({ driverId: driver().id, location: UNION_SQUARE });
    expect(res.status).toBe(200);
  }

  it('offers the ride to the logged-in driver instead of simulating', async () => {
    await login();

    const { body: created } = await requestRide();
    const offers = await request(app).get(`/api/drivers/${driver().id}/offers`);

    expect(driverMatcher.matchRideToDriver).not.toHaveBeenCalled();
    expect(offers.body.hasOffer).toBe(true);
    expect(offers.body.offer.rideId).toBe(created.rideId);
  });

  it('assigns the driver to the ride on accept', async () => {
    await login();
    const { body: created } = await requestRide();

    const accept = await request(app).post(`/api/drivers/${driver().id}/rides/${created.rideId}/accept`);
    const ride = await request(app).get(`/api/rides/${created.rideId}`);

    expect(accept.status).toBe(200);
    expect(ride.body.driver.id).toBe(driver().id);
    expect(rideStore.getPendingOffer(created.rideId)).toBeUndefined();
  });

  it('withdraws the pending offer when the rider cancels', async () => {
    await login();
    const { body: created } = await requestRide();

    await request(app).post(`/api/rides/${created.rideId}/cancel`);
    const offers = await request(app).get(`/api/drivers/${driver().id}/offers`);

    expect(offers.body.offer?.rideId).not.toBe(created.rideId);
  });
});

describe('POST /api/drivers/login', () => {
  it('requires a driver id', async () => {
    const res = await request(app).post('/api/drivers/login').send({});
    expect(res.status).toBe(400);
  });

  it('returns 404 for an unknown driver', async () => {
    const res = await request(app).post('/api/drivers/login').send({ driverId: 'ghost' });
    expect(res.status).toBe(404);
  });
});

describe('fallbacks', () => {
  it('returns JSON 404 for unknown routes', async () => {
    const res = await request(app).get('/api/nope');
    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Not found');
  });
});
