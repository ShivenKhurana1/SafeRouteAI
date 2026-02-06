//
//  RouteOptimizer.swift
//  SafeRouteAI
//
//  Core route optimization engine combining all data sources
//  Generates optimal routes based on safety, health, elevation, and transit
//

import Foundation
import CoreLocation
import MapKit

class RouteOptimizer {
    private let externalDataManager: ExternalDataSourceManager
    private let routeGenerator: RouteGenerator
    
    init(externalDataManager: ExternalDataSourceManager) {
        self.externalDataManager = externalDataManager
        self.routeGenerator = RouteGenerator()
    }
    
    // MARK: - Main Route Optimization
    
    func findOptimalRoutes(
        from startLocation: CLLocationCoordinate2D,
        to endLocation: CLLocationCoordinate2D,
        preferences: RoutePreferences = RoutePreferences.default
    ) async throws -> [RouteOption] {
        
        // Get safety data for the entire route area
        let routeArea = calculateRouteArea(start: startLocation, end: endLocation)
        let safetyData = try await externalDataManager.getCombinedSafetyData(
            for: routeArea.center,
            radius: routeArea.radius
        )
        
        // Generate base route options
        let baseRoutes = try await routeGenerator.generateBaseRoutes(
            from: startLocation,
            to: endLocation
        )
        
        // Score and optimize each route
        var optimizedRoutes: [RouteOption] = []
        
        for baseRoute in baseRoutes {
            let optimizedRoute = try await optimizeRoute(
                baseRoute: baseRoute,
                safetyData: safetyData,
                preferences: preferences
            )
            optimizedRoutes.append(optimizedRoute)
        }
        
        // Generate specialized routes
        let specializedRoutes = try await generateSpecializedRoutes(
            start: startLocation,
            end: endLocation,
            safetyData: safetyData,
            preferences: preferences
        )
        
        optimizedRoutes.append(contentsOf: specializedRoutes)
        
        // Sort by overall score and return top options
        return optimizedRoutes
            .sorted { $0.overallScore > $1.overallScore }
            .prefix(5)
            .map { $0 }
    }
    
    // MARK: - Route Optimization
    
    private func optimizeRoute(
        baseRoute: OptimizedRoute,
        safetyData: CombinedSafetyData,
        preferences: RoutePreferences
    ) async throws -> RouteOption {
        
        // Calculate detailed route scores
        let safetyScore = calculateSafetyScore(route: baseRoute, safetyData: safetyData)
        let elevationScore = calculateElevationScore(route: baseRoute, preferences: preferences)
        let airQualityScore = calculateAirQualityScore(route: baseRoute, safetyData: safetyData)
        let transitScore = calculateTransitScore(route: baseRoute, safetyData: safetyData)
        let difficultyScore = calculateDifficultyScore(route: baseRoute, preferences: preferences)
        
        // Apply user preference weights
        let weightedScores = applyPreferenceWeights(
            safety: safetyScore,
            elevation: elevationScore,
            airQuality: airQualityScore,
            transit: transitScore,
            difficulty: difficultyScore,
            preferences: preferences
        )
        
        // Calculate overall score
        let overallScore = weightedScores.safety * 0.3 +
                          weightedScores.elevation * 0.2 +
                          weightedScores.airQuality * 0.2 +
                          weightedScores.transit * 0.15 +
                          weightedScores.difficulty * 0.15
        
        // Generate route characteristics
        let characteristics = generateRouteCharacteristics(
            route: baseRoute,
            scores: weightedScores,
            safetyData: safetyData
        )
        
        return RouteOption(
            route: baseRoute,
            overallScore: overallScore,
            safetyScore: weightedScores.safety,
            elevationScore: weightedScores.elevation,
            airQualityScore: weightedScores.airQuality,
            transitScore: weightedScores.transit,
            difficultyScore: weightedScores.difficulty,
            characteristics: characteristics,
            recommendations: generateRouteRecommendations(
                scores: weightedScores,
                characteristics: characteristics,
                preferences: preferences
            )
        )
    }
    
    // MARK: - Specialized Route Generation
    
    private func generateSpecializedRoutes(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        safetyData: CombinedSafetyData,
        preferences: RoutePreferences
    ) async throws -> [RouteOption] {
        
        var specializedRoutes: [RouteOption] = []
        
        // Safest Route
        if preferences.prioritizeSafety {
            let safestRoute = try await generateSafestRoute(
                start: start,
                end: end,
                safetyData: safetyData
            )
            specializedRoutes.append(safestRoute)
        }
        
        // Flattest Route
        if preferences.avoidHills {
            let flattestRoute = try await generateFlattestRoute(
                start: start,
                end: end,
                safetyData: safetyData
            )
            specializedRoutes.append(flattestRoute)
        }
        
        // Cleanest Air Route
        if preferences.avoidPollution {
            let cleanestRoute = try await generateCleanestAirRoute(
                start: start,
                end: end,
                safetyData: safetyData
            )
            specializedRoutes.append(cleanestRoute)
        }
        
        // Best Transit Route
        if preferences.preferTransit {
            let transitRoute = try await generateBestTransitRoute(
                start: start,
                end: end,
                safetyData: safetyData
            )
            specializedRoutes.append(transitRoute)
        }
        
        // Best Cycling Route
        if preferences.transportMode == .cycling {
            let cyclingRoute = try await generateBestCyclingRoute(
                start: start,
                end: end,
                safetyData: safetyData
            )
            specializedRoutes.append(cyclingRoute)
        }
        
        return specializedRoutes
    }
    
    // MARK: - Score Calculations
    
    private func calculateSafetyScore(route: OptimizedRoute, safetyData: CombinedSafetyData) -> Double {
        var safetyScore = 1.0 // Start with perfect score
        
        // Check incidents along route
        for coordinate in route.coordinates {
            let nearbyIncidents = safetyData.getNearbyIncidents(
                location: coordinate,
                radius: 100.0
            )
            
            for incident in nearbyIncidents {
                let distance = calculateDistance(coordinate, incident.location)
                let impact = max(0, 1.0 - (distance / incident.radius))
                let severityWeight = incident.severity.score
                let typeWeight = incident.type.safetyWeight
                
                safetyScore -= (impact * severityWeight * typeWeight * 0.1)
            }
        }
        
        // Check infrastructure issues
        for coordinate in route.coordinates {
            let nearbyIssues = safetyData.getInfrastructureIssues(
                location: coordinate,
                radius: 100.0
            )
            
            for issue in nearbyIssues {
                let distance = calculateDistance(coordinate, issue.location)
                let impact = max(0, 1.0 - (distance / sqrt(issue.affectedArea)))
                let severityWeight = issue.severity.score
                let typeWeight = issue.type.safetyImpact
                
                safetyScore -= (impact * severityWeight * typeWeight * 0.1)
            }
        }
        
        return max(0, safetyScore)
    }
    
    private func calculateElevationScore(route: OptimizedRoute, preferences: RoutePreferences) -> Double {
        var elevationScore = 1.0
        let totalElevationGain = route.elevationProfile.totalGain
        let totalDistance = route.distance
        
        // Calculate elevation difficulty
        let elevationRatio = totalElevationGain / totalDistance
        
        if preferences.avoidHills {
            // Penalize steep routes heavily
            elevationScore = max(0, 1.0 - (elevationRatio * 5))
        } else {
            // Moderate penalty for hills
            elevationScore = max(0, 1.0 - (elevationRatio * 2))
        }
        
        // Consider maximum elevation
        let maxElevation = route.elevationProfile.maximumElevation
        if maxElevation > 1000 && preferences.avoidHills {
            elevationScore *= 0.8 // Additional penalty for high altitude
        }
        
        return elevationScore
    }
    
    private func calculateAirQualityScore(route: OptimizedRoute, safetyData: CombinedSafetyData) -> Double {
        var airQualityScore = 1.0
        var totalAQI = 0.0
        var sampleCount = 0
        
        // Sample air quality along route
        for coordinate in route.coordinates {
            if let airQualityData = safetyData.airQualityData {
                let distance = calculateDistance(coordinate, airQualityData.location)
                if distance < 1000 { // Within 1km
                    totalAQI += Double(airQualityData.combinedAQI)
                    sampleCount += 1
                }
            }
        }
        
        if sampleCount > 0 {
            let averageAQI = totalAQI / Double(sampleCount)
            
            // Convert AQI to score (lower AQI = higher score)
            if averageAQI <= 50 {
                airQualityScore = 1.0
            } else if averageAQI <= 100 {
                airQualityScore = 0.8
            } else if averageAQI <= 150 {
                airQualityScore = 0.6
            } else if averageAQI <= 200 {
                airQualityScore = 0.4
            } else {
                airQualityScore = 0.2
            }
        }
        
        return airQualityScore
    }
    
    private func calculateTransitScore(route: OptimizedRoute, safetyData: CombinedSafetyData) -> Double {
        var transitScore = 0.0
        
        guard let transitData = safetyData.transitData else { return 0.0 }
        
        // Check proximity to transit stops
        for coordinate in route.coordinates {
            let nearbyStops = transitData.nearbyStops.filter { stop in
                calculateDistance(coordinate, stop.location) < 200.0 // Within 200m
            }
            
            if !nearbyStops.isEmpty {
                transitScore += 0.1
            }
        }
        
        // Consider service level
        transitScore += transitData.serviceLevel * 0.3
        
        // Consider transit alerts
        let alertPenalty = Double(transitData.alerts.count) * 0.05
        transitScore = max(0, transitScore - alertPenalty)
        
        return min(1.0, transitScore)
    }
    
    private func calculateDifficultyScore(route: OptimizedRoute, preferences: RoutePreferences) -> Double {
        var difficultyScore = 1.0
        
        // Base difficulty on distance
        let distance = route.distance
        if distance > preferences.maxWalkingDistance {
            difficultyScore *= 0.5
        }
        
        // Consider elevation
        let elevationRatio = route.elevationProfile.totalGain / distance
        if elevationRatio > 0.05 { // More than 5% grade average
            difficultyScore *= (1.0 - elevationRatio)
        }
        
        // Consider transport mode
        switch preferences.transportMode {
        case .walking:
            // Walking is baseline
            break
        case .cycling:
            // Cycling can handle hills better
            difficultyScore = min(1.0, difficultyScore * 1.2)
        case .transit:
            // Transit reduces walking difficulty
            difficultyScore = min(1.0, difficultyScore * 1.5)
        }
        
        return max(0, difficultyScore)
    }
    
    // MARK: - Preference Weighting
    
    private func applyPreferenceWeights(
        safety: Double,
        elevation: Double,
        airQuality: Double,
        transit: Double,
        difficulty: Double,
        preferences: RoutePreferences
    ) -> WeightedScores {
        
        return WeightedScores(
            safety: safety * preferences.safetyWeight,
            elevation: elevation * preferences.elevationWeight,
            airQuality: airQuality * preferences.airQualityWeight,
            transit: transit * preferences.transitWeight,
            difficulty: difficulty * preferences.difficultyWeight
        )
    }
    
    // MARK: - Route Characteristics
    
    private func generateRouteCharacteristics(
        route: OptimizedRoute,
        scores: WeightedScores,
        safetyData: CombinedSafetyData
    ) -> RouteCharacteristics {
        
        return RouteCharacteristics(
            distance: route.distance,
            estimatedTime: route.estimatedTime,
            elevationGain: route.elevationProfile.totalGain,
            maxElevation: route.elevationProfile.maximumElevation,
            averageAQI: calculateAverageAQI(route: route, safetyData: safetyData),
            safetyLevel: determineSafetyLevel(score: scores.safety),
            difficultyLevel: determineDifficultyLevel(score: scores.difficulty),
            transitAccessibility: determineTransitLevel(score: scores.transit),
            healthImpact: determineHealthImpact(score: scores.airQuality),
            features: identifyRouteFeatures(route: route, safetyData: safetyData)
        )
    }
    
    // MARK: - Route Recommendations
    
    private func generateRouteRecommendations(
        scores: WeightedScores,
        characteristics: RouteCharacteristics,
        preferences: RoutePreferences
    ) -> [RouteRecommendation] {
        
        var recommendations: [RouteRecommendation] = []
        
        // Safety recommendations
        if scores.safety < 0.7 {
            recommendations.append(RouteRecommendation(
                type: .safety,
                message: "This route has some safety concerns. Consider using during daylight hours.",
                priority: .medium
            ))
        }
        
        // Elevation recommendations
        if characteristics.elevationGain > 100 && preferences.avoidHills {
            recommendations.append(RouteRecommendation(
                type: .elevation,
                message: "This route includes significant elevation changes. Consider alternatives if you prefer flatter terrain.",
                priority: .high
            ))
        }
        
        // Air quality recommendations
        if characteristics.averageAQI > 100 {
            recommendations.append(RouteRecommendation(
                type: .health,
                message: "Air quality along this route may be concerning for sensitive individuals.",
                priority: .medium
            ))
        }
        
        // Transit recommendations
        if scores.transit > 0.7 && preferences.preferTransit {
            recommendations.append(RouteRecommendation(
                type: .transit,
                message: "Great transit connections available along this route.",
                priority: .low
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Helper Functions
    
    private func calculateRouteArea(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) -> (center: CLLocationCoordinate2D, radius: Double) {
        let center = CLLocationCoordinate2D(
            latitude: (start.latitude + end.latitude) / 2,
            longitude: (start.longitude + end.longitude) / 2
        )
        
        let distance = calculateDistance(start, end)
        let radius = distance / 2 + 1000 // Add 1km buffer
        
        return (center: center, radius: radius)
    }
    
    private func calculateDistance(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }
    
    private func calculateAverageAQI(route: OptimizedRoute, safetyData: CombinedSafetyData) -> Double {
        guard let airQualityData = safetyData.airQualityData else { return 50.0 }
        return Double(airQualityData.combinedAQI)
    }
    
    private func determineSafetyLevel(score: Double) -> SafetyLevel {
        switch score {
        case 0.8...1.0: return .safe
        case 0.5..<0.8: return .moderate
        case 0.2..<0.5: return .risky
        default: return .risky
        }
    }
    
    private func determineDifficultyLevel(score: Double) -> DifficultyLevel {
        switch score {
        case 0.8...1.0: return .easy
        case 0.6..<0.8: return .moderate
        case 0.4..<0.6: return .challenging
        case 0.2..<0.4: return .difficult
        default: return .extreme
        }
    }
    
    private func determineTransitLevel(score: Double) -> TransitLevel {
        switch score {
        case 0.8...1.0: return .excellent
        case 0.6..<0.8: return .good
        case 0.4..<0.6: return .moderate
        case 0.2..<0.4: return .poor
        default: return .none
        }
    }
    
    private func determineHealthImpact(score: Double) -> HealthImpact {
        switch score {
        case 0.8...1.0: return .excellent
        case 0.6..<0.8: return .good
        case 0.4..<0.6: return .moderate
        case 0.2..<0.4: return .poor
        default: return .hazardous
        }
    }
    
    private func identifyRouteFeatures(route: OptimizedRoute, safetyData: CombinedSafetyData) -> [RouteFeature] {
        var features: [RouteFeature] = []
        
        // Check for bike lanes
        if route.hasBikeLanes {
            features.append(.bikeLanes)
        }
        
        // Check for sidewalks
        if route.hasSidewalks {
            features.append(.sidewalks)
        }
        
        // Check for lighting
        if route.isWellLit {
            features.append(.wellLit)
        }
        
        // Check for transit access
        if safetyData.transitData?.nearbyStops.isEmpty == false {
            features.append(.transitAccess)
        }
        
        // Check for green spaces
        if route.passesThroughParks {
            features.append(.greenSpaces)
        }
        
        return features
    }
}

// MARK: - Specialized Route Generators

extension RouteOptimizer {
    
    private func generateSafestRoute(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        safetyData: CombinedSafetyData
    ) async throws -> RouteOption {
        
        let preferences = RoutePreferences(
            prioritizeSafety: true,
            avoidHills: false,
            preferTransit: false,
            avoidPollution: false,
            maxWalkingDistance: 5000,
            transportMode: .walking,
            safetyWeight: 1.0,
            elevationWeight: 0.2,
            airQualityWeight: 0.3,
            transitWeight: 0.1,
            difficultyWeight: 0.2
        )
        
        let baseRoutes = try await routeGenerator.generateBaseRoutes(from: start, to: end)
        guard let safestBaseRoute = baseRoutes.min(by: { 
            calculateSafetyScore(route: $0, safetyData: safetyData) > 
            calculateSafetyScore(route: $1, safetyData: safetyData) 
        }) else {
            throw RouteOptimizerError.noRouteFound
        }
        
        return try await optimizeRoute(
            baseRoute: safestBaseRoute,
            safetyData: safetyData,
            preferences: preferences
        )
    }
    
    private func generateFlattestRoute(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        safetyData: CombinedSafetyData
    ) async throws -> RouteOption {
        
        let preferences = RoutePreferences(
            prioritizeSafety: false,
            avoidHills: true,
            preferTransit: false,
            avoidPollution: false,
            maxWalkingDistance: 5000,
            transportMode: .walking,
            safetyWeight: 0.4,
            elevationWeight: 1.0,
            airQualityWeight: 0.2,
            transitWeight: 0.1,
            difficultyWeight: 0.6
        )
        
        let baseRoutes = try await routeGenerator.generateBaseRoutes(from: start, to: end)
        guard let flattestBaseRoute = baseRoutes.min(by: { 
            $0.elevationProfile.totalGain < $1.elevationProfile.totalGain 
        }) else {
            throw RouteOptimizerError.noRouteFound
        }
        
        return try await optimizeRoute(
            baseRoute: flattestBaseRoute,
            safetyData: safetyData,
            preferences: preferences
        )
    }
    
    private func generateCleanestAirRoute(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        safetyData: CombinedSafetyData
    ) async throws -> RouteOption {
        
        let preferences = RoutePreferences(
            prioritizeSafety: false,
            avoidHills: false,
            preferTransit: false,
            avoidPollution: true,
            maxWalkingDistance: 5000,
            transportMode: .walking,
            safetyWeight: 0.3,
            elevationWeight: 0.2,
            airQualityWeight: 1.0,
            transitWeight: 0.1,
            difficultyWeight: 0.2
        )
        
        let baseRoutes = try await routeGenerator.generateBaseRoutes(from: start, to: end)
        
        // Find route with best air quality
        var bestRoute: OptimizedRoute?
        var bestAirQualityScore: Double = 0
        
        for route in baseRoutes {
            let score = calculateAirQualityScore(route: route, safetyData: safetyData)
            if score > bestAirQualityScore {
                bestAirQualityScore = score
                bestRoute = route
            }
        }
        
        guard let cleanestRoute = bestRoute else {
            throw RouteOptimizerError.noRouteFound
        }
        
        return try await optimizeRoute(
            baseRoute: cleanestRoute,
            safetyData: safetyData,
            preferences: preferences
        )
    }
    
    private func generateBestTransitRoute(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        safetyData: CombinedSafetyData
    ) async throws -> RouteOption {
        
        let preferences = RoutePreferences(
            prioritizeSafety: false,
            avoidHills: false,
            preferTransit: true,
            avoidPollution: false,
            maxWalkingDistance: 2000, // Shorter walking for transit
            transportMode: .transit,
            safetyWeight: 0.3,
            elevationWeight: 0.1,
            airQualityWeight: 0.2,
            transitWeight: 1.0,
            difficultyWeight: 0.4
        )
        
        let baseRoutes = try await routeGenerator.generateBaseRoutes(from: start, to: end)
        
        // Find route with best transit access
        var bestRoute: OptimizedRoute?
        var bestTransitScore: Double = 0
        
        for route in baseRoutes {
            let score = calculateTransitScore(route: route, safetyData: safetyData)
            if score > bestTransitScore {
                bestTransitScore = score
                bestRoute = route
            }
        }
        
        guard let transitRoute = bestRoute else {
            throw RouteOptimizerError.noRouteFound
        }
        
        return try await optimizeRoute(
            baseRoute: transitRoute,
            safetyData: safetyData,
            preferences: preferences
        )
    }
    
    private func generateBestCyclingRoute(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        safetyData: CombinedSafetyData
    ) async throws -> RouteOption {
        
        let preferences = RoutePreferences(
            prioritizeSafety: true,
            avoidHills: false,
            preferTransit: false,
            avoidPollution: true,
            maxWalkingDistance: 10000, // Longer distance for cycling
            transportMode: .cycling,
            safetyWeight: 0.5,
            elevationWeight: 0.3,
            airQualityWeight: 0.4,
            transitWeight: 0.0,
            difficultyWeight: 0.2
        )
        
        let baseRoutes = try await routeGenerator.generateBaseRoutes(from: start, to: end)
        
        // Find route best suited for cycling
        var bestRoute: OptimizedRoute?
        var bestCyclingScore: Double = 0
        
        for route in baseRoutes {
            let safetyScore = calculateSafetyScore(route: route, safetyData: safetyData)
            let elevationScore = calculateElevationScore(route: route, preferences: preferences)
            let airQualityScore = calculateAirQualityScore(route: route, safetyData: safetyData)
            
            // Cycling prefers safe routes with moderate elevation and good air quality
            let cyclingScore = safetyScore * 0.5 + elevationScore * 0.3 + airQualityScore * 0.2
            
            if cyclingScore > bestCyclingScore {
                bestCyclingScore = cyclingScore
                bestRoute = route
            }
        }
        
        guard let cyclingRoute = bestRoute else {
            throw RouteOptimizerError.noRouteFound
        }
        
        return try await optimizeRoute(
            baseRoute: cyclingRoute,
            safetyData: safetyData,
            preferences: preferences
        )
    }
}

// MARK: - Error Types

enum RouteOptimizerError: Error {
    case noRouteFound
    case invalidPreferences
    case dataUnavailable
}
