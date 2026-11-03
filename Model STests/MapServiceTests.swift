//
//  MapServiceTests.swift
//  Model S Tests
//
//  Tests for map provider selection (MapProviderService), the unified
//  Apple/Google MapService implementations and their component services.
//

import XCTest
import CoreLocation
@testable import Model_S

@MainActor
final class MapServiceTests: XCTestCase {

    private let providerKey = "selectedMapProvider"
    private var savedProviderPreference: String?

    override func setUp() async throws {
        try await super.setUp()
        savedProviderPreference = UserDefaults.standard.string(forKey: providerKey)
    }

    override func tearDown() async throws {
        // Restore the user's preference and the shared service's provider
        if let saved = savedProviderPreference, let provider = MapProvider(rawValue: saved) {
            MapProviderService.shared.switchTo(provider: provider)
        }
        UserDefaults.standard.set(savedProviderPreference, forKey: providerKey)
        try await super.tearDown()
    }

    // MARK: - MapProviderService

    func testMapProviderServiceIsSingleton() {
        XCTAssertTrue(MapProviderService.shared === MapProviderService.shared)
    }

    func testAppleMapsIsAlwaysAvailable() {
        XCTAssertTrue(MapProviderService.shared.isProviderAvailable(.apple))
        XCTAssertTrue(MapProviderService.shared.availableProviders.contains(.apple))
    }

    func testSwitchToAppleUpdatesProviderServiceAndPreference() {
        let service = MapProviderService.shared

        let result = service.switchTo(provider: .apple)

        XCTAssertNoThrow(try result.get())
        XCTAssertEqual(service.currentProvider, .apple)
        XCTAssertEqual(service.currentService.provider, .apple)
        XCTAssertEqual(UserDefaults.standard.string(forKey: providerKey), "apple")
    }

    func testSwitchToGoogleDependsOnApiKey() {
        let service = MapProviderService.shared
        service.switchTo(provider: .apple)

        let result = service.switchTo(provider: .google)

        if service.isGoogleMapsAvailable {
            XCTAssertNoThrow(try result.get())
            XCTAssertEqual(service.currentProvider, .google)
            XCTAssertEqual(service.currentService.provider, .google)
        } else {
            // Without a key the switch is refused and Apple Maps stays selected
            XCTAssertThrowsError(try result.get())
            XCTAssertEqual(service.currentProvider, .apple)
        }
    }

    func testSwitchingProviderReplacesCurrentService() {
        let service = MapProviderService.shared
        service.switchTo(provider: .apple)
        let before = service.currentService

        service.switchTo(provider: .apple)

        // A fresh service is created on every switch, which is why consumers
        // must read `currentService` at call time rather than caching it.
        XCTAssertFalse(before === service.currentService)
    }

    // MARK: - Unified Services

    func testAppleMapServiceReportsProvider() {
        XCTAssertEqual(AppleMapService().provider, .apple)
    }

    func testGoogleMapServiceReportsProvider() {
        XCTAssertEqual(GoogleMapService(apiKey: "test_key").provider, .google)
    }

    func testAnyMapServiceForwardsProviderAndInitialState() {
        let wrapped = AnyMapService(AppleMapService())

        XCTAssertEqual(wrapped.provider, .apple)
        XCTAssertTrue(wrapped.searchResults.isEmpty)
        XCTAssertFalse(wrapped.isSearching)
    }

    // MARK: - MapProvider

    func testMapProviderRawValue() {
        XCTAssertEqual(MapProvider.apple.rawValue, "apple")
        XCTAssertEqual(MapProvider.google.rawValue, "google")

        XCTAssertEqual(MapProvider(rawValue: "apple"), .apple)
        XCTAssertEqual(MapProvider(rawValue: "google"), .google)
        XCTAssertNil(MapProvider(rawValue: "invalid"))
    }

    func testMapProviderDisplayName() {
        XCTAssertEqual(MapProvider.apple.displayName, "Apple Maps")
        XCTAssertEqual(MapProvider.google.displayName, "Google Maps")
    }

    func testMapProviderIcon() {
        XCTAssertEqual(MapProvider.apple.icon, "map.fill")
        XCTAssertEqual(MapProvider.google.icon, "globe.americas.fill")
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

    // MARK: - Route Result Tests

    func testRouteResultCreation() {
        // Given: Route parameters
        let distance = 5000.0 // meters
        let travelTime = 600.0 // seconds
        let coordinates = [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 37.8049, longitude: -122.3994)
        ]

        // When: Creating route result
        let route = RouteResult(
            distance: distance,
            expectedTravelTime: travelTime,
            coordinates: coordinates
        )

        // Then: Should have correct values
        XCTAssertEqual(route.distance, distance)
        XCTAssertEqual(route.expectedTravelTime, travelTime)
        XCTAssertEqual(route.coordinates.count, 2)
        XCTAssertEqual(route.polyline.count, 2) // polyline is computed property
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
