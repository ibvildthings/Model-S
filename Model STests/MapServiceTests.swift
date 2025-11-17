//
//  MapServiceTests.swift
//  Model S Tests
//
//  Tests for map service factory and provider switching
//  Verifies that both Apple Maps and Google Maps implementations are properly configured
//

import XCTest
import CoreLocation
@testable import Model_S

@MainActor
final class MapServiceTests: XCTestCase {

    var factory: MapServiceFactory!

    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        factory = nil
        try await super.tearDown()
    }

    // MARK: - Factory Configuration Tests

    func testDefaultConfigurationUsesGoogleMaps() {
        // Given: Default configuration
        factory = MapServiceFactory()

        // Then: Should use Google Maps
        XCTAssertEqual(factory.configuration.provider, .google)
        XCTAssertNotNil(factory.configuration.apiKey)
    }

    func testAppleMapConfiguration() {
        // Given: Apple Maps configuration
        factory = MapServiceFactory(configuration: .apple)

        // Then: Should use Apple Maps
        XCTAssertEqual(factory.configuration.provider, .apple)
        XCTAssertNil(factory.configuration.apiKey)
    }

    func testGoogleMapConfiguration() {
        // Given: Google Maps configuration
        factory = MapServiceFactory(configuration: .google)

        // Then: Should use Google Maps
        XCTAssertEqual(factory.configuration.provider, .google)
        XCTAssertNotNil(factory.configuration.apiKey)
    }

    func testConfigurationUpdate() {
        // Given: Factory starts with Apple Maps
        factory = MapServiceFactory(configuration: .apple)
        XCTAssertEqual(factory.configuration.provider, .apple)

        // When: Configuration is updated to Google Maps
        factory.configure(with: .google)

        // Then: Should now use Google Maps
        XCTAssertEqual(factory.configuration.provider, .google)
        XCTAssertNotNil(factory.configuration.apiKey)
    }

    // MARK: - Apple Maps Service Creation Tests

    func testCreateAppleLocationSearchService() {
        // Given: Factory configured for Apple Maps
        factory = MapServiceFactory(configuration: .apple)

        // When: Creating location search service
        let service = factory.createLocationSearchService()

        // Then: Should return Apple implementation
        XCTAssertTrue(service is AppleLocationSearchService)
    }

    func testCreateAppleGeocodingService() {
        // Given: Factory configured for Apple Maps
        factory = MapServiceFactory(configuration: .apple)

        // When: Creating geocoding service
        let service = factory.createGeocodingService()

        // Then: Should return Apple implementation
        XCTAssertTrue(service is AppleGeocodingService)
    }

    func testCreateAppleRouteCalculationService() {
        // Given: Factory configured for Apple Maps
        factory = MapServiceFactory(configuration: .apple)

        // When: Creating route calculation service
        let service = factory.createRouteCalculationService()

        // Then: Should return Apple implementation
        XCTAssertTrue(service is AppleRouteCalculationService)
    }

    // MARK: - Google Maps Service Creation Tests

    func testCreateGoogleLocationSearchService() {
        // Given: Factory configured for Google Maps
        factory = MapServiceFactory(configuration: .google)

        // When: Creating location search service
        let service = factory.createLocationSearchService()

        // Then: Should return Google implementation
        XCTAssertTrue(service is GoogleLocationSearchService)
    }

    func testCreateGoogleGeocodingService() {
        // Given: Factory configured for Google Maps
        factory = MapServiceFactory(configuration: .google)

        // When: Creating geocoding service
        let service = factory.createGeocodingService()

        // Then: Should return Google implementation
        XCTAssertTrue(service is GoogleGeocodingService)
    }

    func testCreateGoogleRouteCalculationService() {
        // Given: Factory configured for Google Maps
        factory = MapServiceFactory(configuration: .google)

        // When: Creating route calculation service
        let service = factory.createRouteCalculationService()

        // Then: Should return Google implementation
        XCTAssertTrue(service is GoogleRouteCalculationService)
    }

    // MARK: - Provider Switching Tests

    func testSwitchFromAppleToGoogle() {
        // Given: Factory starts with Apple Maps
        factory = MapServiceFactory(configuration: .apple)
        let appleService = factory.createLocationSearchService()
        XCTAssertTrue(appleService is AppleLocationSearchService)

        // When: Switching to Google Maps
        factory.configure(with: .google)
        let googleService = factory.createLocationSearchService()

        // Then: Should return Google implementation
        XCTAssertTrue(googleService is GoogleLocationSearchService)
    }

    func testSwitchFromGoogleToApple() {
        // Given: Factory starts with Google Maps
        factory = MapServiceFactory(configuration: .google)
        let googleService = factory.createGeocodingService()
        XCTAssertTrue(googleService is GoogleGeocodingService)

        // When: Switching to Apple Maps
        factory.configure(with: .apple)
        let appleService = factory.createGeocodingService()

        // Then: Should return Apple implementation
        XCTAssertTrue(appleService is AppleGeocodingService)
    }

    // MARK: - Google Maps Service Functionality Tests

    func testGoogleLocationSearchServiceInitialization() {
        // Given: Google Maps API key
        let apiKey = "test_api_key"

        // When: Creating Google location search service
        let service = GoogleLocationSearchService(apiKey: apiKey)

        // Then: Service should be initialized properly
        XCTAssertEqual(service.searchResults.count, 0)
        XCTAssertFalse(service.isSearching)
    }

    func testGoogleGeocodingServiceInitialization() {
        // Given: Google Maps API key
        let apiKey = "test_api_key"

        // When: Creating Google geocoding service
        let service = GoogleGeocodingService(apiKey: apiKey)

        // Then: Service should be initialized without errors
        XCTAssertNotNil(service)
    }

    func testGoogleRouteCalculationServiceInitialization() {
        // Given: Google Maps API key
        let apiKey = "test_api_key"

        // When: Creating Google route calculation service
        let service = GoogleRouteCalculationService(apiKey: apiKey)

        // Then: Service should be initialized without errors
        XCTAssertNotNil(service)
    }

    func testGoogleLocationSearchClearResults() {
        // Given: Google location search service
        let service = GoogleLocationSearchService(apiKey: "test_key")

        // When: Clearing results
        service.clearResults()

        // Then: Results should be empty and not searching
        XCTAssertEqual(service.searchResults.count, 0)
        XCTAssertFalse(service.isSearching)
    }

    func testGoogleLocationSearchUpdateRegion() {
        // Given: Google location search service
        let service = GoogleLocationSearchService(apiKey: "test_key")
        let center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let radius = 50.0

        // When: Updating search region
        service.updateSearchRegion(center: center, radiusMiles: radius)

        // Then: Should not throw errors
        XCTAssertNotNil(service)
    }

    // MARK: - Integration Tests

    func testBothProvidersAvailable() {
        // Given: Both Apple and Google configurations
        let appleConfig = MapServiceConfiguration.apple
        let googleConfig = MapServiceConfiguration.google

        // Then: Both should be valid
        XCTAssertEqual(appleConfig.provider, .apple)
        XCTAssertEqual(googleConfig.provider, .google)
    }

    func testMapProviderEnum() {
        // Test that both providers are accessible
        let providers: [MapProvider] = [.apple, .google]
        XCTAssertEqual(providers.count, 2)
    }

    // MARK: - Location Search Result Tests

    func testLocationSearchResultEquality() {
        // Given: Two location search results
        let result1 = LocationSearchResult(
            title: "Test Location",
            subtitle: "Test City",
            internalResult: "test_id"
        )
        let result2 = LocationSearchResult(
            title: "Test Location",
            subtitle: "Test City",
            internalResult: "test_id"
        )

        // Then: Should not be equal (different IDs)
        XCTAssertNotEqual(result1, result2)
        XCTAssertNotEqual(result1.id, result2.id)
    }

    func testLocationSearchResultIdentifiable() {
        // Given: A location search result
        let result = LocationSearchResult(
            title: "Test",
            subtitle: "Test Subtitle",
            internalResult: "test"
        )

        // Then: Should have a unique ID
        XCTAssertNotNil(result.id)
    }

    // MARK: - Type-Erased Wrapper Tests

    func testAnyLocationSearchServiceWithApple() {
        // Given: Apple location search service wrapped in type eraser
        let appleService = AppleLocationSearchService()
        let wrappedService = AnyLocationSearchService(appleService)

        // Then: Should have correct initial state
        XCTAssertEqual(wrappedService.searchResults.count, 0)
        XCTAssertFalse(wrappedService.isSearching)
    }

    func testAnyLocationSearchServiceWithGoogle() {
        // Given: Google location search service wrapped in type eraser
        let googleService = GoogleLocationSearchService(apiKey: "test_key")
        let wrappedService = AnyLocationSearchService(googleService)

        // Then: Should have correct initial state
        XCTAssertEqual(wrappedService.searchResults.count, 0)
        XCTAssertFalse(wrappedService.isSearching)
    }

    func testAnyLocationSearchServiceClearResults() {
        // Given: Wrapped service
        let service = GoogleLocationSearchService(apiKey: "test_key")
        let wrappedService = AnyLocationSearchService(service)

        // When: Clearing results
        wrappedService.clearResults()

        // Then: Should be empty
        XCTAssertEqual(wrappedService.searchResults.count, 0)
        XCTAssertFalse(wrappedService.isSearching)
    }

    func testAnyLocationSearchServiceUpdateRegion() {
        // Given: Wrapped service
        let service = AppleLocationSearchService()
        let wrappedService = AnyLocationSearchService(service)
        let center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        // When: Updating region
        wrappedService.updateSearchRegion(center: center, radiusMiles: 50.0)

        // Then: Should complete without errors
        XCTAssertNotNil(wrappedService)
    }

    func testAnyLocationSearchServiceEmptySearch() {
        // Given: Wrapped service
        let service = GoogleLocationSearchService(apiKey: "test_key")
        let wrappedService = AnyLocationSearchService(service)

        // When: Searching with empty query
        wrappedService.search(query: "")

        // Then: Should not be searching
        XCTAssertFalse(wrappedService.isSearching)
    }

    // MARK: - Route Result Tests

    func testRouteResultCreation() {
        // Given: Route parameters
        let distance = 5000.0 // meters
        let travelTime = 600.0 // seconds
        let polyline = "encoded_polyline_string"

        // When: Creating route result
        let route = RouteResult(
            distance: distance,
            expectedTravelTime: travelTime,
            polyline: polyline
        )

        // Then: Should have correct values
        XCTAssertEqual(route.distance, distance)
        XCTAssertEqual(route.expectedTravelTime, travelTime)
        XCTAssertNotNil(route.polyline)
    }

    // MARK: - Configuration Presets Tests

    func testAppleConfigurationPreset() {
        let config = MapServiceConfiguration.apple
        XCTAssertEqual(config.provider, .apple)
        XCTAssertNil(config.apiKey)
    }

    func testGoogleConfigurationPreset() {
        let config = MapServiceConfiguration.google
        XCTAssertEqual(config.provider, .google)
        XCTAssertNotNil(config.apiKey)
    }

    func testDefaultConfigurationPreset() {
        let config = MapServiceConfiguration.default
        // Default should be Google Maps as per requirements
        XCTAssertEqual(config.provider, .google)
    }
}

// MARK: - Apple Maps Service Tests

@MainActor
final class AppleMapServicesTests: XCTestCase {

    func testAppleLocationSearchServiceInitialization() {
        // Given/When: Creating Apple location search service
        let service = AppleLocationSearchService()

        // Then: Should be initialized properly
        XCTAssertEqual(service.searchResults.count, 0)
        XCTAssertFalse(service.isSearching)
    }

    func testAppleLocationSearchClearResults() {
        // Given: Apple location search service
        let service = AppleLocationSearchService()

        // When: Clearing results
        service.clearResults()

        // Then: Results should be empty
        XCTAssertEqual(service.searchResults.count, 0)
        XCTAssertFalse(service.isSearching)
    }

    func testAppleLocationSearchEmptyQuery() {
        // Given: Apple location search service
        let service = AppleLocationSearchService()

        // When: Searching with empty query
        service.search(query: "")

        // Then: Should not be searching
        XCTAssertFalse(service.isSearching)
        XCTAssertEqual(service.searchResults.count, 0)
    }

    func testAppleLocationSearchUpdateRegion() {
        // Given: Apple location search service
        let service = AppleLocationSearchService()
        let center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let radius = 50.0

        // When: Updating search region
        service.updateSearchRegion(center: center, radiusMiles: radius)

        // Then: Should complete without errors
        XCTAssertNotNil(service)
    }

    func testAppleGeocodingServiceInitialization() {
        // Given/When: Creating Apple geocoding service
        let service = AppleGeocodingService()

        // Then: Should be initialized without errors
        XCTAssertNotNil(service)
    }

    func testAppleRouteCalculationServiceInitialization() {
        // Given/When: Creating Apple route calculation service
        let service = AppleRouteCalculationService()

        // Then: Should be initialized without errors
        XCTAssertNotNil(service)
    }
}
