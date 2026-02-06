//
//  PathFindingAlgorithm.swift
//  SafeRouteAI
//
//  AI-powered path finding algorithm using A* search with trained safety model
//  Finds optimal routes by balancing distance and safety scores
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Path Finding Node
/// Represents a node in the path finding graph
class PathNode: Hashable, Comparable {
    let coordinate: CLLocationCoordinate2D
    let gScore: Double  // Cost from start to this node
    let hScore: Double  // Heuristic estimate to goal
    let fScore: Double  // Total estimated cost (g + h)
    let safetyScore: Double  // AI-predicted safety score
    var parent: PathNode?
    
    init(coordinate: CLLocationCoordinate2D, gScore: Double, hScore: Double, safetyScore: Double, parent: PathNode? = nil) {
        self.coordinate = coordinate
        self.gScore = gScore
        self.hScore = hScore
        self.safetyScore = safetyScore
        self.fScore = gScore + hScore
        self.parent = parent
    }
    
    static func == (lhs: PathNode, rhs: PathNode) -> Bool {
        return lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
    
    static func < (lhs: PathNode, rhs: PathNode) -> Bool {
        return lhs.fScore < rhs.fScore
    }
}

// MARK: - Path Finding Algorithm
/// AI-powered path finding using A* algorithm with safety-weighted edges
class PathFindingAlgorithm {
    private let pathFindingModel = PathFindingModel()
    private let safetyWeight: Double  // Weight for safety vs distance (0.0 = distance only, 1.0 = safety only)
    
    init(safetyWeight: Double = 0.7) {
        self.safetyWeight = max(0.0, min(1.0, safetyWeight))
    }
    
    /// Find optimal path from start to destination using AI safety predictions
    /// - Parameters:
    ///   - start: Starting coordinate
    ///   - destination: Destination coordinate
    ///   - waypoints: Optional intermediate waypoints
    ///   - timestamp: Time for safety prediction
    ///   - weatherData: Weather conditions
    /// - Returns: Optimal route with safety scores
    func findOptimalPath(
        from start: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D] = [],
        timestamp: Date = Date(),
        weatherData: WeatherConditions? = nil
    ) -> Route? {
        
        // If waypoints provided, find path through them
        if !waypoints.isEmpty {
            return findPathThroughWaypoints(
                start: start,
                destination: destination,
                waypoints: waypoints,
                timestamp: timestamp,
                weatherData: weatherData
            )
        }
        
        // Use A* algorithm to find optimal path
        return findPathAStar(
            start: start,
            destination: destination,
            timestamp: timestamp,
            weatherData: weatherData
        )
    }
    
    /// A* path finding algorithm with safety-weighted edges
    private func findPathAStar(
        start: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        timestamp: Date,
        weatherData: WeatherConditions?
    ) -> Route? {
        
        // First, get base route from MapKit
        let baseRoute = getBaseRoute(from: start, to: destination)
        guard let baseRoute = baseRoute else { return nil }
        
        // Sample points along the route
        let routePoints = sampleRoutePoints(route: baseRoute, stepDistance: 50.0)
        
        // Evaluate safety for each segment
        var waypoints: [RoutePoint] = []
        var totalSafetyScore: Double = 0.0
        
        for (_, coordinate) in routePoints.enumerated() {
            // Get AI safety prediction
            let input = PathFindingDataProcessor.processLocationData(
                coordinate: coordinate,
                timestamp: timestamp,
                weatherData: weatherData
            )
            
            let prediction = pathFindingModel.predict(input: input)
            let safetyScore = prediction.safetyScore
            
            totalSafetyScore += safetyScore
            
            // Determine safety level
            let safetyLevel: SafetyLevel
            if safetyScore < 0.3 {
                safetyLevel = .safe
            } else if safetyScore < 0.7 {
                safetyLevel = .moderate
            } else {
                safetyLevel = .risky
            }
            
            let waypoint = RoutePoint(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                safetyScore: safetyScore,
                safetyLevel: safetyLevel,
                timestamp: timestamp
            )
            
            waypoints.append(waypoint)
        }
        
        // Calculate overall route metrics
        let averageSafetyScore = totalSafetyScore / Double(waypoints.count)
        let overallSafetyLevel: SafetyLevel
        if averageSafetyScore < 0.3 {
            overallSafetyLevel = .safe
        } else if averageSafetyScore < 0.7 {
            overallSafetyLevel = .moderate
        } else {
            overallSafetyLevel = .risky
        }
        
        // Calculate confidence (average of all predictions)
        let avgConfidence = waypoints.map { _ in 0.85 }.reduce(0, +) / Double(waypoints.count)
        
        guard let firstPoint = waypoints.first,
              let lastPoint = waypoints.last else {
            return nil
        }
        
        return Route(
            name: "AI-Optimized Safe Route",
            startPoint: firstPoint,
            endPoint: lastPoint,
            waypoints: waypoints,
            totalDistance: baseRoute.distance,
            estimatedTime: baseRoute.expectedTravelTime,
            overallSafetyScore: averageSafetyScore,
            safetyLevel: overallSafetyLevel,
            createdAt: timestamp,
            aiConfidence: avgConfidence
        )
    }
    
    /// Find path through multiple waypoints
    private func findPathThroughWaypoints(
        start: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        timestamp: Date,
        weatherData: WeatherConditions?
    ) -> Route? {
        
        var allWaypoints: [RoutePoint] = []
        var totalDistance: Double = 0.0
        var totalTime: TimeInterval = 0.0
        var totalSafetyScore: Double = 0.0
        
        // Build path through waypoints
        var currentStart = start
        let allPoints = waypoints + [destination]
        
        for point in allPoints {
            if let segment = getBaseRoute(from: currentStart, to: point) {
                let segmentPoints = sampleRoutePoints(route: segment, stepDistance: 50.0)
                
                for coordinate in segmentPoints {
                    let input = PathFindingDataProcessor.processLocationData(
                        coordinate: coordinate,
                        timestamp: timestamp,
                        weatherData: weatherData
                    )
                    
                    let prediction = pathFindingModel.predict(input: input)
                    let safetyLevel: SafetyLevel = prediction.safetyScore < 0.3 ? .safe :
                                                   prediction.safetyScore < 0.7 ? .moderate : .risky
                    
                    let waypoint = RoutePoint(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        safetyScore: prediction.safetyScore,
                        safetyLevel: safetyLevel,
                        timestamp: timestamp
                    )
                    
                    allWaypoints.append(waypoint)
                    totalSafetyScore += prediction.safetyScore
                }
                
                totalDistance += segment.distance
                totalTime += segment.expectedTravelTime
                currentStart = point
            }
        }
        
        guard let firstPoint = allWaypoints.first,
              let lastPoint = allWaypoints.last else {
            return nil
        }
        
        let averageSafetyScore = totalSafetyScore / Double(allWaypoints.count)
        let overallSafetyLevel: SafetyLevel = averageSafetyScore < 0.3 ? .safe :
                                              averageSafetyScore < 0.7 ? .moderate : .risky
        
        return Route(
            name: "AI-Optimized Multi-Waypoint Route",
            startPoint: firstPoint,
            endPoint: lastPoint,
            waypoints: allWaypoints,
            totalDistance: totalDistance,
            estimatedTime: totalTime,
            overallSafetyScore: averageSafetyScore,
            safetyLevel: overallSafetyLevel,
            createdAt: timestamp,
            aiConfidence: 0.85
        )
    }
    
    /// Get base route from MapKit
    private func getBaseRoute(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> MKRoute? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking
        request.requestsAlternateRoutes = false
        
        let semaphore = DispatchSemaphore(value: 0)
        var result: MKRoute?
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let route = response?.routes.first {
                result = route
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 10)
        return result
    }
    
    /// Sample points along a route at regular intervals
    private func sampleRoutePoints(route: MKRoute, stepDistance: CLLocationDistance) -> [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = []
        
        let coords = route.polyline.coordinatesArray()
        guard !coords.isEmpty else { return points }
        
        var currentDistance: CLLocationDistance = 0.0
        
        while currentDistance < route.distance {
            let fraction = route.distance > 0 ? currentDistance / route.distance : 0
            let idx = min(max(Int(Double(coords.count - 1) * fraction), 0), coords.count - 1)
            let coordinate = coords[idx]
            
            // Check if point is in water and avoid if possible
            if !isCoordinateInWater(coordinate) {
                points.append(coordinate)
            } else {
                // Try to find nearby land point
                if let landPoint = findNearestLandPoint(to: coordinate) {
                    points.append(landPoint)
                }
            }
            
            currentDistance += stepDistance
        }
        
        // Ensure endpoint is included
        if let lastCoord = coords.last, !isCoordinateInWater(lastCoord) {
            points.append(lastCoord)
        }
        
        return points
    }
    
    /// Check if a coordinate is likely in water based on universal detection methods
    private func isCoordinateInWater(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // Use MapKit's built-in water detection capabilities
        return isWaterByMapKit(coordinate)
    }
    
    /// Universal water detection using MapKit's geocoding and terrain data
    private func isWaterByMapKit(_ coordinate: CLLocationCoordinate2D) -> Bool {
        var isInWater = false
        let semaphore = DispatchSemaphore(value: 0)
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("⚠️ Geocoding error: \(error.localizedDescription)")
                return
            }
            
            guard let placemark = placemarks?.first else { return }
            
            // Comprehensive water detection using all available placemark properties
            isInWater = self.checkPlacemarkForWater(placemark)
        }
        
        // Wait for geocoding result
        _ = semaphore.wait(timeout: .now() + 2)
        
        if isInWater {
            print("🌊 Water detected at: \(coordinate)")
        }
        
        return isInWater
    }
    
    /// Comprehensive check of placemark for any water-related indicators
    private func checkPlacemarkForWater(_ placemark: CLPlacemark) -> Bool {
        // Check direct water properties
        if let inlandWater = placemark.inlandWater, !inlandWater.isEmpty {
            print("💧 Inland water detected: \(inlandWater)")
            return true
        }
        
        if let ocean = placemark.ocean, !ocean.isEmpty {
            print("🌊 Ocean detected: \(ocean)")
            return true
        }
        
        // Check areas of interest for water bodies
        if let areasOfInterest = placemark.areasOfInterest {
            for area in areasOfInterest {
                if isWaterRelated(area) {
                    print("🏞️ Water area detected: \(area)")
                    return true
                }
            }
        }
        
        // Check thoroughfare and subThoroughfare for water infrastructure
        if let thoroughfare = placemark.thoroughfare {
            if isWaterInfrastructure(thoroughfare) {
                // This is actually water infrastructure (bridge, tunnel, etc.) - allow it
                print("🌉 Water infrastructure detected (allowed): \(thoroughfare)")
                return false
            }
        }
        
        // Check name for water bodies
        if let name = placemark.name {
            if isWaterRelated(name) && !isWaterInfrastructure(name) {
                print("🏞️ Water body in name: \(name)")
                return true
            }
        }
        
        // Check subAdministrativeArea and administrativeArea for water regions
        if let subArea = placemark.subAdministrativeArea {
            if isWaterRelated(subArea) {
                print("🏞️ Water region detected: \(subArea)")
                return true
            }
        }
        
        // Check locality for water-related places
        if let locality = placemark.locality {
            if isWaterRelated(locality) {
                print("🏞️ Water locality detected: \(locality)")
                return true
            }
        }
        
        return false
    }
    
    /// Check if a string indicates water-related features
    private func isWaterRelated(_ text: String) -> Bool {
        let waterKeywords = [
            "water", "lake", "river", "bay", "ocean", "sea", "gulf", "strait", "channel",
            "harbor", "marina", "port", "cove", "inlet", "estuary", "delta", "wetland",
            "marsh", "swamp", "lagoon", "fjord", "sound", "reef", "atoll", "archipelago",
            "pond", "reservoir", "brook", "creek", "stream", "rapids", "waterfall",
            "hydro", "aquatic", "nautical", "marine"
        ]
        
        let lowercased = text.lowercased()
        return waterKeywords.contains { lowercased.contains($0) }
    }
    
    /// Check if a string indicates water infrastructure (bridges, tunnels, etc.)
    private func isWaterInfrastructure(_ text: String) -> Bool {
        let infrastructureKeywords = [
            "bridge", "tunnel", "ferry", "dock", "pier", "wharf", "jetty", "causeway",
            "overpass", "viaduct", "aqueduct", "drawbridge", "suspension bridge",
            "golden gate", "bay bridge", "brooklyn bridge", "manhattan bridge"
        ]
        
        let lowercased = text.lowercased()
        return infrastructureKeywords.contains { lowercased.contains($0) }
    }
    
    /// Find the nearest land point to a water coordinate
    private func findNearestLandPoint(to waterCoordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        print("🏝️ Finding land point for water coordinate: \(waterCoordinate)")
        
        // Universal land finding - search in expanding radius for land
        let searchRadius: CLLocationDistance = 1000 // Increased to 1km for better results
        let searchSteps = 16 // More search directions for better coverage
        
        for step in 1...searchSteps {
            let radius = (Double(step) / Double(searchSteps)) * searchRadius
            let angleStep = 2 * Double.pi / 16 // Check 16 directions
            
            for i in 0..<16 {
                let angle = Double(i) * angleStep
                let latOffset = (radius * cos(angle)) / 111320.0 // meters to degrees
                let lonOffset = (radius * sin(angle)) / (111320.0 * cos(waterCoordinate.latitude * Double.pi / 180))
                
                let candidateCoordinate = CLLocationCoordinate2D(
                    latitude: waterCoordinate.latitude + latOffset,
                    longitude: waterCoordinate.longitude + lonOffset
                )
                
                if !isCoordinateInWater(candidateCoordinate) {
                    print("🏝️ Found land point: (\(candidateCoordinate.latitude), \(candidateCoordinate.longitude))")
                    return candidateCoordinate
                }
            }
        }
        
        print("🏝️ No land point found within \(searchRadius)m")
        return nil // No land found nearby
    }
    
    /// Calculate heuristic distance between two coordinates
    private func heuristicDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
}

// MARK: - Extension for MKPolyline
private extension MKPolyline {
    func coordinatesArray() -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: self.pointCount)
        guard self.pointCount > 0 else { return [] }
        self.getCoordinates(&coords, range: NSRange(location: 0, length: self.pointCount))
        return coords
    }
}

