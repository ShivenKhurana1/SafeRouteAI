//
//  RouteGenerator.swift
//  SafeRouteAI
//
//  Base route generation using Apple MapKit
//  Provides foundation for route optimization
//

import Foundation
import CoreLocation
import MapKit

class RouteGenerator {
    
    // MARK: - Base Route Generation
    
    func generateBaseRoutes(
        from startLocation: CLLocationCoordinate2D,
        to endLocation: CLLocationCoordinate2D
    ) async throws -> [OptimizedRoute] {
        
        // Generate multiple route options using MapKit
        let mapKitRoutes = try await generateMapKitRoutes(
            from: startLocation,
            to: endLocation
        )
        
        // Convert MapKit routes to our Route model
        var routes: [OptimizedRoute] = []
        
        for (index, mapKitRoute) in mapKitRoutes.enumerated() {
            let route = try await convertMapKitRoute(
                mapKitRoute: mapKitRoute,
                transportMode: determineTransportMode(for: mapKitRoute),
                index: index
            )
            routes.append(route)
        }
        
        return routes
    }
    
    // MARK: - MapKit Route Generation
    
    private func generateMapKitRoutes(
        from startLocation: CLLocationCoordinate2D,
        to endLocation: CLLocationCoordinate2D
    ) async throws -> [MKRoute] {
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: startLocation))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: endLocation))
            request.transportType = [.walking, .automobile] // Include both for variety
            request.requestsAlternateRoutes = true
            
            let directions = MKDirections(request: request)
            directions.calculate { response, error in
                if let error = error {
                    continuation.resume(throwing: RouteGenerationError.mapKitError(error))
                    return
                }
                
                guard let response = response, !response.routes.isEmpty else {
                    continuation.resume(throwing: RouteGenerationError.noRoutesFound)
                    return
                }
                
                let routes = response.routes
                
                continuation.resume(returning: routes)
            }
        }
    }
    
    // MARK: - Route Conversion
    
    private func convertMapKitRoute(
        mapKitRoute: MKRoute,
        transportMode: TransportMode,
        index: Int
    ) async throws -> OptimizedRoute {
        
        // Extract coordinates from route polyline
        let coordinates = extractCoordinates(from: mapKitRoute)
        
        // Generate elevation profile
        let elevationProfile = try await generateElevationProfile(for: coordinates)
        
        // Create route
        let route = OptimizedRoute(
            id: "route_\(index)",
            coordinates: coordinates,
            distance: mapKitRoute.distance,
            estimatedTime: mapKitRoute.expectedTravelTime,
            elevationProfile: elevationProfile,
            transportMode: transportMode
        )
        
        // Analyze route features
        return await analyzeRouteFeatures(route: route)
    }
    
    private func extractCoordinates(from mapKitRoute: MKRoute) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        
        for step in mapKitRoute.steps {
            // Add coordinates from this step's polyline
            let stepCoordinates = extractCoordinates(from: step.polyline)
            coordinates.append(contentsOf: stepCoordinates)
        }
        
        return coordinates
    }
    
    private func extractCoordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        let count = polyline.pointCount
        
        for i in 0..<count {
            let coordinate = polyline.coordinates()[i]
            coordinates.append(coordinate)
        }
        
        return coordinates
    }
    
    // MARK: - Elevation Profile Generation
    
    private func generateElevationProfile(for coordinates: [CLLocationCoordinate2D]) async throws -> ElevationProfile {
        var elevations: [Double] = []
        var distances: [Double] = []
        var currentDistance: Double = 0
        
        // Sample elevation at regular intervals
        let sampleInterval = max(1, coordinates.count / 50) // Sample up to 50 points
        
        for (index, coordinate) in coordinates.enumerated() {
            if index % sampleInterval == 0 || index == coordinates.count - 1 {
                // Get elevation for this coordinate
                let elevation = try await getElevation(for: coordinate)
                elevations.append(elevation)
                distances.append(currentDistance)
            }
            
            // Update distance
            if index < coordinates.count - 1 {
                let nextCoordinate = coordinates[index + 1]
                let stepDistance = calculateDistance(coordinate, nextCoordinate)
                currentDistance += stepDistance
            }
        }
        
        return ElevationProfile(elevations: elevations, distances: distances)
    }
    
    private func getElevation(for coordinate: CLLocationCoordinate2D) async throws -> Double {
        // Use Open Elevation API
        let urlString = "https://api.open-elevation.com/api/v1/lookup?locations=\(coordinate.latitude),\(coordinate.longitude)"
        
        guard let url = URL(string: urlString) else {
            throw RouteGenerationError.elevationError
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(OpenElevationResponse.self, from: data)
            
            return response.results.first?.elevation ?? 0.0
        } catch {
            // Fallback to estimated elevation based on location
            return estimateElevation(for: coordinate)
        }
    }
    
    private func estimateElevation(for coordinate: CLLocationCoordinate2D) -> Double {
        // Simple estimation based on latitude (very rough)
        // This is just a fallback - real implementation would use better estimation
        let baseElevation = 100.0
        let latitudeFactor = abs(coordinate.latitude) / 90.0 * 200.0
        return baseElevation + latitudeFactor
    }
    
    // MARK: - Route Feature Analysis
    
    private func analyzeRouteFeatures(route: OptimizedRoute) async -> OptimizedRoute {
        var analyzedRoute = route
        
        // Analyze route for various features
        analyzedRoute.hasBikeLanes = await checkForBikeLanes(along: route.coordinates)
        analyzedRoute.hasSidewalks = await checkForSidewalks(along: route.coordinates)
        analyzedRoute.isWellLit = await checkForLighting(along: route.coordinates)
        analyzedRoute.passesThroughParks = await checkForParks(along: route.coordinates)
        
        return analyzedRoute
    }
    
    private func checkForBikeLanes(along coordinates: [CLLocationCoordinate2D]) async -> Bool {
        // Sample points along the route to check for bike infrastructure
        let samplePoints = coordinates.filter { _ in Bool.random() } // Random sampling
        
        for coordinate in samplePoints.prefix(10) { // Check up to 10 points
            if await hasBikeInfrastructure(at: coordinate) {
                return true
            }
        }
        
        return false
    }
    
    private func checkForSidewalks(along coordinates: [CLLocationCoordinate2D]) async -> Bool {
        // Similar to bike lanes check
        let samplePoints = coordinates.filter { _ in Bool.random() }
        
        for coordinate in samplePoints.prefix(10) {
            if await hasSidewalkInfrastructure(at: coordinate) {
                return true
            }
        }
        
        return false
    }
    
    private func checkForLighting(along coordinates: [CLLocationCoordinate2D]) async -> Bool {
        // Check for street lighting infrastructure
        let samplePoints = coordinates.filter { _ in Bool.random() }
        
        for coordinate in samplePoints.prefix(10) {
            if await hasLightingInfrastructure(at: coordinate) {
                return true
            }
        }
        
        return false
    }
    
    private func checkForParks(along coordinates: [CLLocationCoordinate2D]) async -> Bool {
        // Check if route passes through parks or green spaces
        for coordinate in coordinates.prefix(20) { // Check up to 20 points
            if await isInParkArea(at: coordinate) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Infrastructure Checks
    
    private func hasBikeInfrastructure(at coordinate: CLLocationCoordinate2D) async -> Bool {
        // Use OpenStreetMap Overpass API to check for bike infrastructure
        let query = """
        [out:json];
        (
          way["cycleway"](around:50,\(coordinate.latitude),\(coordinate.longitude));
          way["bicycle"="designated"](around:50,\(coordinate.latitude),\(coordinate.longitude));
        );
        out count;
        """
        
        do {
            let urlString = "https://overpass-api.de/api/interpreter?data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            guard let url = URL(string: urlString) else { return false }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(OverpassCountResponse.self, from: data)
            
            return response.elements.count > 0
        } catch {
            return false
        }
    }
    
    private func hasSidewalkInfrastructure(at coordinate: CLLocationCoordinate2D) async -> Bool {
        let query = """
        [out:json];
        (
          way["sidewalk"](around:50,\(coordinate.latitude),\(coordinate.longitude));
          way["highway"~"residential|tertiary|secondary"](around:50,\(coordinate.latitude),\(coordinate.longitude));
        );
        out count;
        """
        
        do {
            let urlString = "https://overpass-api.de/api/interpreter?data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            guard let url = URL(string: urlString) else { return false }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(OverpassCountResponse.self, from: data)
            
            return response.elements.count > 0
        } catch {
            return false
        }
    }
    
    private func hasLightingInfrastructure(at coordinate: CLLocationCoordinate2D) async -> Bool {
        let query = """
        [out:json];
        (
          node["highway"="street_lamp"](around:100,\(coordinate.latitude),\(coordinate.longitude));
          way["lit"="yes"](around:50,\(coordinate.latitude),\(coordinate.longitude));
        );
        out count;
        """
        
        do {
            let urlString = "https://overpass-api.de/api/interpreter?data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            guard let url = URL(string: urlString) else { return false }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(OverpassCountResponse.self, from: data)
            
            return response.elements.count > 0
        } catch {
            return false
        }
    }
    
    private func isInParkArea(at coordinate: CLLocationCoordinate2D) async -> Bool {
        let query = """
        [out:json];
        (
          way["leisure"~"park|garden"](around:100,\(coordinate.latitude),\(coordinate.longitude));
          relation["leisure"="park"](around:100,\(coordinate.latitude),\(coordinate.longitude));
        );
        out count;
        """
        
        do {
            let urlString = "https://overpass-api.de/api/interpreter?data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            guard let url = URL(string: urlString) else { return false }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(OverpassCountResponse.self, from: data)
            
            return response.elements.count > 0
        } catch {
            return false
        }
    }
    
    // MARK: - Helper Functions
    
    private func determineTransportMode(for mapKitRoute: MKRoute) -> TransportMode {
        // Determine transport mode based on route characteristics
        if mapKitRoute.transportType == .walking {
            return .walking
        } else if mapKitRoute.transportType == .automobile {
            // Check if this might be a cycling route
            if mapKitRoute.distance > 2000 && mapKitRoute.expectedTravelTime < Double(mapKitRoute.distance) / 3.0 {
                return .cycling // Faster than walking suggests cycling
            }
            return .transit // Assume transit for automotive routes
        } else {
            return .walking // Default
        }
    }
    
    private func calculateDistance(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }
}

// MARK: - API Response Models

struct OverpassCountResponse: Codable {
    let elements: [RouteOverpassElement]
}

struct RouteOverpassElement: Codable {
    // Minimal structure for count queries
}

// MARK: - Error Types

enum RouteGenerationError: Error {
    case mapKitError(Error)
    case noRoutesFound
    case elevationError
    case infrastructureError
}
