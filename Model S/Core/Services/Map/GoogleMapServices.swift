//
//  GoogleMapServices.swift
//  Model S
//
//  Google Maps implementations of map service protocols.
//  Provides location search, geocoding, and route calculation using Google Maps Platform APIs.
//
//  Created by Pritesh Desai on 11/17/25.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Google Location Search Service

/// Google Maps implementation of location autocomplete using Google Places API
/// Provides real-time search suggestions as user types
@MainActor
class GoogleLocationSearchService: LocationSearchService, ObservableObject {
    /// Current search results (updated as user types)
    @Published var searchResults: [LocationSearchResult] = []

    /// Whether a search is currently in progress
    @Published var isSearching = false

    /// Google Maps API key
    private let apiKey: String

    /// Current search region (limits results to nearby area)
    private var currentRegion: (center: CLLocationCoordinate2D, radiusMiles: Double)?

    /// Session token for billing optimization
    private var sessionToken = UUID().uuidString

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// Searches for locations matching the query string using Google Places Autocomplete API
    /// - Parameter query: The search text (e.g., "123 Main St" or "Starbucks")
    func search(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        Task {
            do {
                let results = try await performPlacesAutocomplete(query: query)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.searchResults = []
                    self.isSearching = false
                    print("Google Places Autocomplete error: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Limits search results to a region around the given center point
    /// - Parameters:
    ///   - center: The center coordinate
    ///   - radiusMiles: Radius in miles to search within
    func updateSearchRegion(center: CLLocationCoordinate2D, radiusMiles: Double) {
        currentRegion = (center, radiusMiles)
    }

    func clearResults() {
        searchResults = []
        isSearching = false
        // Generate new session token for next search session
        sessionToken = UUID().uuidString
    }

    func getCoordinate(for result: LocationSearchResult) async throws -> (CLLocationCoordinate2D, String) {
        guard let placeId = result.internalResult as? String else {
            throw RideRequestError.geocodingFailed
        }

        // Use Google Places Details API to get coordinate for place_id
        let placeDetails = try await fetchPlaceDetails(placeId: placeId)
        return placeDetails
    }

    // MARK: - Private Methods

    /// Performs Google Places Autocomplete API request
    private func performPlacesAutocomplete(query: String) async throws -> [LocationSearchResult] {
        var urlComponents = URLComponents(string: "https://maps.googleapis.com/maps/api/place/autocomplete/json")!

        var queryItems = [
            URLQueryItem(name: "input", value: query),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "sessiontoken", value: sessionToken)
        ]

        // Add location bias if region is set
        if let region = currentRegion {
            let radiusMeters = region.radiusMiles * 1609.34 // Convert miles to meters
            queryItems.append(URLQueryItem(name: "location", value: "\(region.center.latitude),\(region.center.longitude)"))
            queryItems.append(URLQueryItem(name: "radius", value: "\(Int(radiusMeters))"))
        }

        urlComponents.queryItems = queryItems

        let (data, response) = try await URLSession.shared.data(from: urlComponents.url!)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RideRequestError.geocodingFailed
        }

        let json = try JSONDecoder().decode(PlacesAutocompleteResponse.self, from: data)

        guard json.status == "OK" || json.status == "ZERO_RESULTS" else {
            print("Google Places API error: \(json.status)")
            throw RideRequestError.geocodingFailed
        }

        return json.predictions.map { prediction in
            LocationSearchResult(
                title: prediction.structuredFormatting.mainText,
                subtitle: prediction.structuredFormatting.secondaryText ?? "",
                internalResult: prediction.placeId
            )
        }
    }

    /// Fetches place details including coordinates using Google Places Details API
    private func fetchPlaceDetails(placeId: String) async throws -> (CLLocationCoordinate2D, String) {
        var urlComponents = URLComponents(string: "https://maps.googleapis.com/maps/api/place/details/json")!

        urlComponents.queryItems = [
            URLQueryItem(name: "place_id", value: placeId),
            URLQueryItem(name: "fields", value: "geometry,formatted_address,name"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "sessiontoken", value: sessionToken)
        ]

        let (data, response) = try await URLSession.shared.data(from: urlComponents.url!)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RideRequestError.geocodingFailed
        }

        let json = try JSONDecoder().decode(PlaceDetailsResponse.self, from: data)

        guard json.status == "OK",
              let result = json.result else {
            print("Google Place Details API error: \(json.status)")
            throw RideRequestError.geocodingFailed
        }

        let coordinate = CLLocationCoordinate2D(
            latitude: result.geometry.location.lat,
            longitude: result.geometry.location.lng
        )

        let name = result.name ?? result.formattedAddress

        // Clear session token after place selection
        sessionToken = UUID().uuidString

        return (coordinate, name)
    }
}

// MARK: - Google Geocoding Service

/// Google Maps implementation of GeocodingService using Google Geocoding API
class GoogleGeocodingService: GeocodingService {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func geocode(address: String) async throws -> (CLLocationCoordinate2D, String) {
        var urlComponents = URLComponents(string: "https://maps.googleapis.com/maps/api/geocode/json")!

        urlComponents.queryItems = [
            URLQueryItem(name: "address", value: address),
            URLQueryItem(name: "key", value: apiKey)
        ]

        let (data, response) = try await URLSession.shared.data(from: urlComponents.url!)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RideRequestError.geocodingFailed
        }

        let json = try JSONDecoder().decode(GeocodingResponse.self, from: data)

        guard json.status == "OK",
              let result = json.results.first else {
            print("Google Geocoding API error: \(json.status)")
            throw RideRequestError.geocodingFailed
        }

        let coordinate = CLLocationCoordinate2D(
            latitude: result.geometry.location.lat,
            longitude: result.geometry.location.lng
        )

        return (coordinate, result.formattedAddress)
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> String {
        var urlComponents = URLComponents(string: "https://maps.googleapis.com/maps/api/geocode/json")!

        urlComponents.queryItems = [
            URLQueryItem(name: "latlng", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        let (data, response) = try await URLSession.shared.data(from: urlComponents.url!)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RideRequestError.geocodingFailed
        }

        let json = try JSONDecoder().decode(GeocodingResponse.self, from: data)

        guard json.status == "OK",
              let result = json.results.first else {
            print("Google Reverse Geocoding API error: \(json.status)")
            throw RideRequestError.geocodingFailed
        }

        return result.formattedAddress
    }
}

// MARK: - Google Route Calculation Service

/// Google Maps implementation of RouteCalculationService using Google Directions API
class GoogleRouteCalculationService: RouteCalculationService {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> RouteResult {
        var urlComponents = URLComponents(string: "https://maps.googleapis.com/maps/api/directions/json")!

        urlComponents.queryItems = [
            URLQueryItem(name: "origin", value: "\(from.latitude),\(from.longitude)"),
            URLQueryItem(name: "destination", value: "\(to.latitude),\(to.longitude)"),
            URLQueryItem(name: "mode", value: "driving"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        print("🚗 Google Directions API request:")
        print("   From: \(from.latitude), \(from.longitude)")
        print("   To: \(to.latitude), \(to.longitude)")

        let (data, response) = try await URLSession.shared.data(from: urlComponents.url!)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response")
            throw RideRequestError.routeCalculationFailed
        }

        print("   HTTP Status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            print("❌ HTTP error: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Response: \(responseString)")
            }
            throw RideRequestError.routeCalculationFailed
        }

        let json = try JSONDecoder().decode(DirectionsResponse.self, from: data)
        print("   API Status: \(json.status)")

        guard json.status == "OK" else {
            print("")
            print("❌ Google Directions API Error: \(json.status)")

            // Provide specific error messages
            switch json.status {
            case "REQUEST_DENIED":
                print("   🔧 Solution: Enable 'Directions API' in Google Cloud Console")
                print("   https://console.cloud.google.com/apis/library/directions-backend.googleapis.com")
            case "OVER_QUERY_LIMIT":
                print("   🔧 You've exceeded your API quota")
            case "ZERO_RESULTS":
                print("   🔧 No route found between these locations")
            case "NOT_FOUND":
                print("   🔧 One of the locations could not be geocoded")
            default:
                print("   🔧 Unknown error - check API key and billing")
            }
            print("")

            if let errorMessage = json.errorMessage {
                print("   Error message: \(errorMessage)")
            }

            throw RideRequestError.routeCalculationFailed
        }

        guard let route = json.routes.first,
              let leg = route.legs.first else {
            print("❌ No routes found in response")
            throw RideRequestError.routeCalculationFailed
        }

        // Decode polyline into coordinates for visualization
        let coordinates = decodePolyline(route.overviewPolyline.points)

        print("✅ Route calculated: \(leg.distance.value)m, \(leg.duration.value)s")

        return RouteResult(
            distance: leg.distance.value,
            expectedTravelTime: leg.duration.value,
            coordinates: coordinates // Provider-agnostic coordinate array
        )
    }

    // MARK: - Private Methods

    /// Decodes Google's encoded polyline format into coordinates
    /// Algorithm: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
    private func decodePolyline(_ encodedPolyline: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        var index = encodedPolyline.startIndex
        var lat = 0
        var lng = 0

        while index < encodedPolyline.endIndex {
            // Decode latitude
            var result = 0
            var shift = 0
            var byte: Int

            repeat {
                byte = Int(encodedPolyline[index].asciiValue! - 63)
                index = encodedPolyline.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20

            let deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lat += deltaLat

            // Decode longitude
            result = 0
            shift = 0

            repeat {
                byte = Int(encodedPolyline[index].asciiValue! - 63)
                index = encodedPolyline.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20

            let deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lng += deltaLng

            let coordinate = CLLocationCoordinate2D(
                latitude: Double(lat) / 1e5,
                longitude: Double(lng) / 1e5
            )
            coordinates.append(coordinate)
        }

        return coordinates
    }
}

// MARK: - Google API Response Models

/// Response model for Google Places Autocomplete API
private struct PlacesAutocompleteResponse: Codable {
    let predictions: [Prediction]
    let status: String

    struct Prediction: Codable {
        let placeId: String
        let structuredFormatting: StructuredFormatting

        enum CodingKeys: String, CodingKey {
            case placeId = "place_id"
            case structuredFormatting = "structured_formatting"
        }
    }

    struct StructuredFormatting: Codable {
        let mainText: String
        let secondaryText: String?

        enum CodingKeys: String, CodingKey {
            case mainText = "main_text"
            case secondaryText = "secondary_text"
        }
    }
}

/// Response model for Google Place Details API
private struct PlaceDetailsResponse: Codable {
    let result: PlaceResult?
    let status: String

    struct PlaceResult: Codable {
        let geometry: Geometry
        let formattedAddress: String
        let name: String?

        enum CodingKeys: String, CodingKey {
            case geometry
            case formattedAddress = "formatted_address"
            case name
        }
    }

    struct Geometry: Codable {
        let location: Location
    }

    struct Location: Codable {
        let lat: Double
        let lng: Double
    }
}

/// Response model for Google Geocoding API
private struct GeocodingResponse: Codable {
    let results: [GeocodingResult]
    let status: String

    struct GeocodingResult: Codable {
        let formattedAddress: String
        let geometry: Geometry

        enum CodingKeys: String, CodingKey {
            case formattedAddress = "formatted_address"
            case geometry
        }
    }

    struct Geometry: Codable {
        let location: Location
    }

    struct Location: Codable {
        let lat: Double
        let lng: Double
    }
}

/// Response model for Google Directions API
private struct DirectionsResponse: Codable {
    let routes: [Route]
    let status: String
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case routes
        case status
        case errorMessage = "error_message"
    }

    struct Route: Codable {
        let legs: [Leg]
        let overviewPolyline: Polyline

        enum CodingKeys: String, CodingKey {
            case legs
            case overviewPolyline = "overview_polyline"
        }
    }

    struct Leg: Codable {
        let distance: Distance
        let duration: Duration
    }

    struct Distance: Codable {
        let value: Double // meters
    }

    struct Duration: Codable {
        let value: TimeInterval // seconds
    }

    struct Polyline: Codable {
        let points: String // Encoded polyline
    }
}
