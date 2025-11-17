# Testing Guide for Model S

This guide explains how to run the comprehensive unit tests that have been added to the Model S ride-sharing application.

## Overview

The test suite focuses on **critical business logic** rather than just achieving coverage. Tests are organized into two main categories:

### Backend Tests (Node.js + Jest)
- **geoUtils** - Geographic calculations (Haversine distance, ETA, interpolation, bearing)
- **driverMatcher** - Driver matching algorithm (nearest driver selection)

### iOS Tests (Swift + XCTest)
- **RideStateMachine** - Passenger ride flow state transitions (13+ states)
- **DriverStateMachine** - Driver flow state transitions (10+ states)

## Why These Tests?

Each test file validates **core business logic** that is:
1. **Mission-critical** - State machines control the entire ride flow
2. **Algorithm-heavy** - Distance calculations and driver matching use complex math
3. **Pure logic** - No external dependencies, making them easy to test in isolation
4. **Error-prone** - State transitions and geographic calculations are easy to get wrong

## Backend Tests

### Setup

1. Navigate to the backend directory:
```bash
cd backend
```

2. Install Jest (if not already installed):
```bash
npm install
```

This will install Jest 29.7.0 as specified in `package.json`.

### Running Tests

Run all backend tests:
```bash
npm test
```

Run tests in watch mode (re-runs on file changes):
```bash
npm run test:watch
```

Run tests with coverage report:
```bash
npm run test:coverage
```

### Test Files

#### `backend/utils/__tests__/geoUtils.test.js`

Tests the geographic utility functions that power the ride-sharing logic:

**calculateDistance** (Haversine formula)
- ✅ Calculates SF to LA distance (~559 km)
- ✅ Returns 0 for same location
- ✅ Handles short distances (1 km)
- ✅ Handles crossing prime meridian
- ✅ Handles crossing equator

**interpolate** (point interpolation for animations)
- ✅ Returns start point at progress 0
- ✅ Returns end point at progress 1
- ✅ Returns midpoint at progress 0.5
- ✅ Handles negative coordinates

**calculateETA** (time estimation)
- ✅ Calculates ETA for typical city distances
- ✅ Uses 40 km/h average speed assumption
- ✅ Handles very short distances
- ✅ Returns 0 for 0 distance

**randomLocationInRadius** (driver spawning)
- ✅ Generates location within specified radius
- ✅ Generates different locations on multiple calls
- ✅ Handles small radius (100m)
- ✅ Validates coordinate ranges

**randomLocationInDonut** (realistic driver distribution)
- ✅ Generates location between min and max radius
- ✅ Never generates location inside minimum radius
- ✅ Ensures drivers spawn at realistic distances

**generateRoutePolyline** (route visualization)
- ✅ Generates correct number of points
- ✅ First point is start location
- ✅ Last point is end location
- ✅ Intermediate points are between start and end

**calculateBearing** (navigation direction)
- ✅ Calculates north bearing (0°)
- ✅ Calculates east bearing (90°)
- ✅ Calculates south bearing (180°)
- ✅ Calculates west bearing (270°)
- ✅ Returns value between 0 and 360

#### `backend/services/__tests__/driverMatcher.test.js`

Tests the critical driver matching algorithm:

**findNearestDriver**
- ✅ Finds nearest driver when multiple available
- ✅ Returns null when no drivers available
- ✅ Handles single available driver
- ✅ Correctly calculates distance to each driver
- ✅ Includes ETA in result
- ✅ Selects closest driver regardless of rating
- ✅ Handles drivers at exact same location as pickup
- ✅ Handles edge case of very close drivers

**matchRideToDriver**
- ✅ Calls callback with matched driver after delay
- ✅ Calls callback with null when no drivers available
- ✅ Simulates realistic search delay (2-4 seconds)

### Expected Output

When you run `npm test`, you should see:
```
PASS  utils/__tests__/geoUtils.test.js
  geoUtils
    calculateDistance
      ✓ calculates distance between two points correctly
      ✓ returns 0 for same location
      ✓ calculates short distances accurately
      ...

PASS  services/__tests__/driverMatcher.test.js
  DriverMatcher
    findNearestDriver
      ✓ finds nearest driver when multiple drivers available
      ✓ returns null when no drivers available
      ...

Test Suites: 2 passed, 2 total
Tests:       XX passed, XX total
```

## iOS Tests

### Setup

The iOS test files have been created in the `Model S Tests/` directory, but they need to be added to your Xcode project.

#### Adding Tests to Xcode

1. Open `Model S.xcodeproj` in Xcode

2. Create a new test target (if one doesn't exist):
   - File → New → Target
   - Select "Unit Testing Bundle"
   - Name it "Model S Tests"
   - Click "Finish"

3. Add the test files to the test target:
   - In Xcode's Project Navigator, right-click on "Model S Tests" folder
   - Select "Add Files to 'Model S'..."
   - Navigate to `Model S Tests/` directory
   - Select:
     - `RideStateMachineTests.swift`
     - `DriverStateMachineTests.swift`
   - Make sure "Model S Tests" target is checked
   - Click "Add"

4. Ensure the test target can access the app code:
   - Select your project in the Project Navigator
   - Select the "Model S Tests" target
   - Go to "Build Phases" tab
   - Under "Dependencies", add "Model S" app target
   - Under "Link Binary With Libraries", add "Model S.app"

### Running Tests

#### In Xcode

1. Select the test scheme: Product → Scheme → Model S Tests
2. Run tests: Product → Test (or press ⌘U)
3. View results in the Test Navigator (⌘6)

#### Command Line

```bash
# Run all tests
xcodebuild test -scheme "Model S" -destination "platform=iOS Simulator,name=iPhone 15"

# Run specific test file
xcodebuild test -scheme "Model S" -destination "platform=iOS Simulator,name=iPhone 15" -only-testing:Model_S_Tests/RideStateMachineTests
```

### Test Files

#### `Model S Tests/RideStateMachineTests.swift`

Tests the passenger ride flow state machine with **30+ test cases** covering:

**Valid Transitions**
- idle → selectingLocations
- selectingLocations → routeReady
- routeReady → submittingRequest
- submittingRequest → searchingForDriver
- searchingForDriver → driverAssigned
- driverAssigned → driverEnRoute
- driverEnRoute → driverArriving
- driverArriving → rideInProgress
- rideInProgress → approachingDestination
- approachingDestination → rideCompleted
- rideCompleted → idle
- error → idle / selectingLocations

**Invalid Transitions (should be blocked)**
- idle → driverAssigned (can't skip states)
- routeReady → idle (must go through selectingLocations)
- rideInProgress → searchingForDriver (can't go backwards)
- submittingRequest → routeReady (can't go backwards)
- rideCompleted → selectingLocations (should reset to idle first)

**Special Cases**
- User can cancel at any point (→ idle)
- Can update location selection while in selectingLocations
- Can skip approaching destination (rideInProgress → rideCompleted)

#### `Model S Tests/DriverStateMachineTests.swift`

Tests the driver flow state machine with **35+ test cases** covering:

**Valid Transitions**
- offline → loggingIn
- loggingIn → online
- online → rideOffered
- rideOffered → headingToPickup (accepted)
- rideOffered → online (rejected/expired)
- headingToPickup → arrivedAtPickup
- arrivedAtPickup → rideInProgress
- rideInProgress → approachingDestination
- approachingDestination → rideCompleted
- rideCompleted → online / offline

**Invalid Transitions (should be blocked)**
- offline → online (must login first)
- online → headingToPickup (must receive offer first)
- headingToPickup → rideInProgress (must arrive at pickup first)
- rideInProgress → online (can't abandon active ride)

**Helper Method Tests**
- login() creates loggingIn state
- loginComplete() creates online state
- acceptRide() creates headingToPickup state
- rejectRide() creates online state

**Special Cases**
- Driver can cancel before passenger is picked up
- Error states can transition to offline or online
- Can skip approaching destination for short rides

### Expected Output

When you run tests in Xcode (⌘U), you should see:
```
Test Suite 'All tests' started
Test Suite 'RideStateMachineTests' started
Test Case '-[Model_S_Tests.RideStateMachineTests testTransition_idleToSelectingLocations_isValid]' passed (0.001 seconds)
Test Case '-[Model_S_Tests.RideStateMachineTests testTransition_idleToError_isValid]' passed (0.000 seconds)
...

Test Suite 'DriverStateMachineTests' started
Test Case '-[Model_S_Tests.DriverStateMachineTests testTransition_offlineToLoggingIn_isValid]' passed (0.000 seconds)
...

Test Suite 'All tests' passed
     Executed XX tests, with 0 failures in Y.ZZZ seconds
```

## Understanding Test Coverage

### What IS Tested ✅

1. **State Machine Logic**
   - All valid state transitions
   - All invalid transitions are blocked
   - Edge cases (cancellations, errors)
   - Helper methods for state creation

2. **Geographic Calculations**
   - Haversine distance formula accuracy
   - ETA calculations (assumes 40 km/h)
   - Coordinate interpolation for animations
   - Bearing calculations for navigation
   - Random location generation for drivers

3. **Driver Matching Algorithm**
   - Nearest driver selection
   - Distance calculations
   - ETA computation
   - Edge cases (no drivers, same location, very close)

### What is NOT Tested ❌

These are intentionally not tested because they require complex mocking or are integration tests:

1. **Network/API calls** - Would require mocking HTTP requests
2. **UI/View logic** - Better suited for UI tests
3. **Database operations** - No database in this app (in-memory storage)
4. **Real-time WebSocket communication** - Integration test concern
5. **Location services** - Requires device/simulator
6. **Map rendering** - Requires MapKit integration testing
7. **Timer/Animation logic** - Would require time-based testing frameworks

## Test Philosophy

These tests follow the principle of **testing behavior, not implementation**:

- ✅ Tests verify that state machines enforce business rules
- ✅ Tests verify that calculations produce correct results
- ✅ Tests are independent and can run in any order
- ✅ Tests use realistic data (actual SF/LA coordinates)
- ✅ Tests include edge cases and error scenarios
- ❌ Tests don't mock internal methods (tests behavior, not implementation details)
- ❌ Tests don't test private methods directly
- ❌ Tests don't test trivial getters/setters

## Continuous Integration

To add these tests to CI/CD:

### GitHub Actions (Backend)

```yaml
name: Backend Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - name: Install dependencies
        run: cd backend && npm install
      - name: Run tests
        run: cd backend && npm test
```

### GitHub Actions (iOS)

```yaml
name: iOS Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: xcodebuild test -scheme "Model S" -destination "platform=iOS Simulator,name=iPhone 15"
```

## Troubleshooting

### Backend Tests

**Error: `jest: command not found`**
- Run `npm install` in the `backend/` directory

**Error: `Cannot find module '../utils/geoUtils'`**
- Ensure you're running tests from the `backend/` directory
- Check that file paths are correct

**Tests are timing out**
- `matchRideToDriver` tests use fake timers
- Make sure Jest fake timers are working correctly

### iOS Tests

**Error: `No such module 'Model_S'`**
- Make sure the test target has access to the app code
- Check that `@testable import Model_S` is correct (use underscore, not space)
- Ensure the app target is added as a dependency

**Error: `Use of unresolved identifier 'RideStateMachine'`**
- Verify that the source files are included in the app target
- Check the test target's "Build Phases" → "Compile Sources"

**Tests not appearing in Xcode**
- Clean build folder: Product → Clean Build Folder (⌘⇧K)
- Restart Xcode
- Ensure test files have the test target checked in File Inspector

## Next Steps

To expand test coverage, consider adding:

1. **Integration Tests** for RideFlowController with mocked services
2. **API Client Tests** for RideAPIClient with mocked network responses
3. **Model Encoding/Decoding Tests** for JSON serialization
4. **UI Tests** for critical user flows (request ride, complete ride)
5. **Performance Tests** for expensive operations (route calculations)

## Questions?

- Review the test files themselves - they're heavily commented
- Check the inline documentation in the source files
- Refer to the main architecture docs (ARCHITECTURE.md, JUNIOR_ENGINEER_GUIDE.md)
