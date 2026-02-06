//
//  LocationManager.swift
//  SafeRouteAI
//
//  Manages location services, permissions, and route planning
//  Integrates with CoreLocation and MapKit for navigation
//

import Foundation
import CoreLocation
import MapKit
import Combine

// Helper to extract MKPolyline coordinates as an array
private extension MKPolyline {
    func coordinatesArray() -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: self.pointCount)
        guard self.pointCount > 0 else { return [] }
        self.getCoordinates(&coords, range: NSRange(location: 0, length: self.pointCount))
        return coords
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    // Published properties for SwiftUI
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationAvailable = false
    @Published var locationError: String?
    
    // Route planning
    @Published var currentRoute: Route?
    @Published var alternativeRoutes: [Route] = []
    @Published var isCalculatingRoutes = false
    
    // AI Path Finding
    private let pathFindingAlgorithm = PathFindingAlgorithm(safetyWeight: 0.7)
    
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.pausesLocationUpdatesAutomatically = true
        // Avoid enabling background updates unless the app is configured for it.
        // Enabling this without Background Modes (Location updates) or "Always" authorization
        // can trigger CoreLocation assertions like CLClientIsBackgroundable.
        locationManager.allowsBackgroundLocationUpdates = false

        // Request location permission
        requestLocationPermission()
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
            isLocationAvailable = true
        }
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.isLocationAvailable = true
                self.startLocationUpdates()
            case .denied, .restricted:
                self.isLocationAvailable = false
                self.locationError = "Location access denied. Please enable location services in Settings."
            case .notDetermined:
                self.isLocationAvailable = false
            @unknown default:
                self.isLocationAvailable = false
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.userLocation = location
            self.locationError = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = "Location error: \(error.localizedDescription)"
            self.isLocationAvailable = false
        }
    }
    
    // MARK: - Route Planning
    
    func calculateSafeRoutes(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, 
                           travelMode: TravelMode = .walking, completion: @escaping ([Route]) -> Void) {
        
        isCalculatingRoutes = true
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        
        // Set transport type based on travel mode with accessibility preferences
        switch travelMode {
        case .walking:
            request.transportType = .walking
            // Prefer footpaths and sidewalks
            request.requestsAlternateRoutes = true
        case .biking:
            request.transportType = .automobile // Use automobile as biking isn't directly supported
            // Will filter for bike-friendly routes later
            request.requestsAlternateRoutes = true
        case .wheelchair:
            request.transportType = .walking
            // Will filter for wheelchair accessible routes
            request.requestsAlternateRoutes = true
        }
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isCalculatingRoutes = false
                
                if let error = error {
                    self.locationError = "Route calculation error: \(error.localizedDescription)"
                    completion([])
                    return
                }
                
                guard let response = response else {
                    self.locationError = "No routes found"
                    completion([])
                    return
                }
                
                // Use AI path finding algorithm for optimal route selection
                Task {
                    if let optimalRoute = await self.pathFindingAlgorithm.findOptimalPath(
                        from: start,
                        to: destination,
                        timestamp: Date(),
                        weatherData: nil
                    ) {
                        // Also process MapKit routes for comparison
                        let mapKitRoutes = self.processMapKitRoutes(response.routes, travelMode: travelMode)
                        
                        // Combine AI-optimized route with MapKit alternatives
                        var allRoutes = [optimalRoute]
                        allRoutes.append(contentsOf: mapKitRoutes)
                        
                        completion(allRoutes)
                    } else {
                        // Fallback to MapKit routes only
                        let routes = self.processMapKitRoutes(response.routes, travelMode: travelMode)
                        completion(routes)
                    }
                }
            }
        }
    }
    
    private func processMapKitRoutes(_ mkRoutes: [MKRoute], travelMode: TravelMode) -> [Route] {
        var processedRoutes: [Route] = []
        
        for (index, mkRoute) in mkRoutes.enumerated() {
            // Convert MKRoute points to our RoutePoint model
            let waypoints = convertRouteToWaypoints(mkRoute, travelMode: travelMode)
            
            // Safety check: ensure we have valid waypoints
            guard !waypoints.isEmpty, let startPoint = waypoints.first, let endPoint = waypoints.last else {
                print("⚠️ Warning: Route \(index + 1) has no valid waypoints, skipping")
                continue
            }
            
            // Apply travel mode-specific accessibility filtering
            if isRouteSuitableForTravelMode(waypoints: waypoints, travelMode: travelMode) {
                print("✅ Route \(index + 1) PASSED \(travelMode.rawValue) accessibility filter")
                // Calculate safety scores for this route
                let safetyAnalysis = analyzeRouteSafety(waypoints: waypoints)
                
                let route = Route(
                    name: "Route \(index + 1)",
                    startPoint: startPoint,
                    endPoint: endPoint,
                    waypoints: waypoints,
                    totalDistance: mkRoute.distance,
                    estimatedTime: mkRoute.expectedTravelTime,
                    overallSafetyScore: safetyAnalysis.overallScore,
                    safetyLevel: safetyAnalysis.safetyLevel,
                    createdAt: Date(),
                    aiConfidence: safetyAnalysis.confidence
                )
                
                processedRoutes.append(route)
            } else {
                print("🚫 Route \(index + 1) REJECTED - not suitable for \(travelMode.rawValue)")
            }
        }
        
        return processedRoutes
    }
    
    // MARK: - Travel Mode Accessibility Filtering
    
    private func isRouteSuitableForTravelMode(waypoints: [RoutePoint], travelMode: TravelMode) -> Bool {
        switch travelMode {
        case .walking:
            return isRouteSuitableForWalking(waypoints: waypoints)
        case .biking:
            return isRouteSuitableForBiking(waypoints: waypoints)
        case .wheelchair:
            return isRouteSuitableForWheelchair(waypoints: waypoints)
        }
    }
    
    private func isRouteSuitableForWalking(waypoints: [RoutePoint]) -> Bool {
        // Prefer routes with higher safety scores (indicating footpaths/sidewalks)
        // Check if route avoids high-risk areas (likely major highways)
        var safePathScore = 0
        var highRiskPenalty = 0
        
        for waypoint in waypoints {
            // Higher safety scores suggest pedestrian-friendly areas
            if waypoint.safetyScore < 0.3 { // Lower score = safer
                safePathScore += 1
            }
            
            // Penalize routes through high-risk areas (likely major roads)
            if waypoint.safetyScore > 0.7 { // Higher score = more dangerous
                highRiskPenalty += 2
            }
        }
        
        // Route is suitable if it has safe areas or minimal high-risk sections
        let isSuitable = safePathScore > 0 || highRiskPenalty < waypoints.count / 2
        print("  🚶 Walking filter: safePathScore=\(safePathScore), highRiskPenalty=\(highRiskPenalty), suitable=\(isSuitable)")
        return isSuitable
    }
    
    private func isRouteSuitableForBiking(waypoints: [RoutePoint]) -> Bool {
        // Allow moderate safety areas (bikes can use roads but prefer safer paths)
        // Heavily penalize extremely dangerous areas
        var bikeFriendlyScore = 0
        var extremeRiskPenalty = 0
        
        for waypoint in waypoints {
            // Moderate to good safety is acceptable for biking
            if waypoint.safetyScore < 0.5 {
                bikeFriendlyScore += 1
            }
            
            // Extreme penalty for very dangerous areas
            if waypoint.safetyScore > 0.8 {
                extremeRiskPenalty += 2
            }
        }
        
        // Route is suitable if it has bike-friendly areas or minimal extreme risk
        let isSuitable = bikeFriendlyScore > 0 || extremeRiskPenalty < waypoints.count / 4
        print("  🚴 Biking filter: bikeFriendlyScore=\(bikeFriendlyScore), extremeRiskPenalty=\(extremeRiskPenalty), suitable=\(isSuitable)")
        return isSuitable
    }
    
    private func isRouteSuitableForWheelchair(waypoints: [RoutePoint]) -> Bool {
        // Require high safety (indicating smooth surfaces, accessibility)
        // Very strict filtering for wheelchair accessibility
        var accessibleScore = 0
        var obstaclePenalty = 0
        
        for waypoint in waypoints {
            // Only consider very safe areas for wheelchair access
            if waypoint.safetyScore < 0.2 { // Very safe = likely accessible
                accessibleScore += 2
            } else if waypoint.safetyScore < 0.4 { // Moderately safe
                accessibleScore += 1
            }
            
            // Heavy penalty for any risky areas
            if waypoint.safetyScore > 0.6 {
                obstaclePenalty += 3
            }
        }
        
        // Route is suitable if it's highly accessible with minimal obstacles
        let isSuitable = accessibleScore >= 2 && obstaclePenalty == 0
        print("  ♿ Wheelchair filter: accessibleScore=\(accessibleScore), obstaclePenalty=\(obstaclePenalty), suitable=\(isSuitable)")
        return isSuitable
    }
    
    private func convertRouteToWaypoints(_ route: MKRoute, travelMode: TravelMode) -> [RoutePoint] {
        var waypoints: [RoutePoint] = []

        // Extract polyline coordinates once; if empty, return no waypoints
        let coords = route.polyline.coordinatesArray()
        guard !coords.isEmpty else { return waypoints }

        // Sample points along the route (every 50 meters)
        let stepDistance: CLLocationDistance = 50.0
        var currentDistance: CLLocationDistance = 0.0

        while currentDistance < route.distance {
            let fraction = route.distance > 0 ? currentDistance / route.distance : 0
            // Pick a coordinate based on fraction of total distance
            let idx = min(max(Int(Double(coords.count - 1) * fraction), 0), coords.count - 1)
            let coordinate = coords[idx]
            
            // Use AI model to predict safety score for this point
            let safetyData = SafetyDataProcessor.processLocationData(
                coordinate: coordinate,
                timestamp: Date()
            )
            
            let predictionModel = SafetyPredictionModel()
            let prediction = predictionModel.prediction(input: safetyData)
            
            let safetyLevel: SafetyLevel
            if prediction.safetyScore < 0.3 {
                safetyLevel = .safe
            } else if prediction.safetyScore < 0.7 {
                safetyLevel = .moderate
            } else {
                safetyLevel = .risky
            }
            
            let waypoint = RoutePoint(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                safetyScore: prediction.safetyScore,
                safetyLevel: safetyLevel,
                timestamp: Date()
            )
            
            waypoints.append(waypoint)
            currentDistance += stepDistance
        }
        
        return waypoints
    }
    
    private func analyzeRouteSafety(waypoints: [RoutePoint]) -> (overallScore: Double, safetyLevel: SafetyLevel, confidence: Double) {
        let safetyScores = waypoints.map { $0.safetyScore }
        let overallScore = safetyScores.reduce(0, +) / Double(safetyScores.count)
        
        let safetyLevel: SafetyLevel
        if overallScore < 0.3 {
            safetyLevel = .safe
        } else if overallScore < 0.7 {
            safetyLevel = .moderate
        } else {
            safetyLevel = .risky
        }
        
        // Calculate confidence based on data quality and consistency
        let scoreVariance = calculateVariance(safetyScores)
        let confidence = max(0.5, 1.0 - scoreVariance)
        
        return (overallScore: overallScore, safetyLevel: safetyLevel, confidence: confidence)
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
    
    // MARK: - Utility Methods
    
    func getCurrentLocation() -> CLLocationCoordinate2D? {
        return userLocation?.coordinate
    }
    
    func getLocationAuthorizationStatus() -> String {
        switch authorizationStatus {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "When In Use"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }
}
