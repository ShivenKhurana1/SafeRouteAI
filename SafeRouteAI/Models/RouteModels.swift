//
//  RouteModels.swift
//  SafeRouteAI
//
//  Data models for route planning and safety analysis
//  Designed for AI-powered route optimization and community safety
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Safety Level Enum
enum SafetyLevel: String, CaseIterable, Codable {
    case safe = "Safe"
    case moderate = "Moderate"
    case risky = "Risky"
    
    var color: String {
        switch self {
        case .safe: return "SafetyGreen"
        case .moderate: return "SafetyYellow"
        case .risky: return "SafetyRed"
        }
    }
    
    var riskScore: Double {
        switch self {
        case .safe: return 0.0
        case .moderate: return 0.5
        case .risky: return 1.0
        }
    }
}

// MARK: - Route Point
struct RoutePoint: Identifiable, Codable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let safetyScore: Double
    let safetyLevel: SafetyLevel
    let timestamp: Date
    
    init(id: UUID = UUID(), latitude: Double, longitude: Double, safetyScore: Double, safetyLevel: SafetyLevel, timestamp: Date) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.safetyScore = safetyScore
        self.safetyLevel = safetyLevel
        self.timestamp = timestamp
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case latitude
        case longitude
        case safetyScore
        case safetyLevel
        case timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.latitude = try container.decode(Double.self, forKey: .latitude)
        self.longitude = try container.decode(Double.self, forKey: .longitude)
        self.safetyScore = try container.decode(Double.self, forKey: .safetyScore)
        // Decode SafetyLevel via raw value
        let levelRaw = try container.decode(String.self, forKey: .safetyLevel)
        guard let level = SafetyLevel(rawValue: levelRaw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.safetyLevel], debugDescription: "Invalid SafetyLevel raw value: \(levelRaw)"))
        }
        self.safetyLevel = level
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(safetyScore, forKey: .safetyScore)
        try container.encode(safetyLevel.rawValue, forKey: .safetyLevel)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

// MARK: - Route
struct Route: Identifiable, Codable {
    let id: UUID
    let name: String
    let startPoint: RoutePoint
    let endPoint: RoutePoint
    let waypoints: [RoutePoint]
    let totalDistance: Double // in meters
    let estimatedTime: TimeInterval // in seconds
    let overallSafetyScore: Double // 0.0 to 1.0 (higher is riskier)
    let safetyLevel: SafetyLevel
    let createdAt: Date
    let aiConfidence: Double // AI model confidence score
    
    init(id: UUID = UUID(), name: String, startPoint: RoutePoint, endPoint: RoutePoint, waypoints: [RoutePoint], totalDistance: Double, estimatedTime: TimeInterval, overallSafetyScore: Double, safetyLevel: SafetyLevel, createdAt: Date, aiConfidence: Double) {
        self.id = id
        self.name = name
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.waypoints = waypoints
        self.totalDistance = totalDistance
        self.estimatedTime = estimatedTime
        self.overallSafetyScore = overallSafetyScore
        self.safetyLevel = safetyLevel
        self.createdAt = createdAt
        self.aiConfidence = aiConfidence
    }
    
    // Computed properties
    var distanceInMiles: Double {
        totalDistance / 1609.34
    }
    
    var timeInMinutes: Double {
        estimatedTime / 60
    }
    
    var polyline: MKPolyline {
        let coordinates = waypoints.map { $0.coordinate }
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }
    
    // Average safety score across all waypoints
    var averageSafetyScore: Double {
        let scores = waypoints.map { $0.safetyScore }
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    // Risk factors identified by AI
    var riskFactors: [RiskFactor] {
        var factors: [RiskFactor] = []
        
        // Analyze waypoints for risk patterns
        let lowLightingCount = waypoints.filter { $0.safetyScore > 0.7 }.count
        if lowLightingCount > waypoints.count / 3 {
            factors.append(RiskFactor(type: .poorLighting, severity: .medium))
        }
        
        let highRiskAreas = waypoints.filter { $0.safetyLevel == .risky }.count
        if highRiskAreas > waypoints.count / 4 {
            factors.append(RiskFactor(type: .highCrimeArea, severity: .high))
        }
        
        return factors
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case startPoint
        case endPoint
        case waypoints
        case totalDistance
        case estimatedTime
        case overallSafetyScore
        case safetyLevel
        case createdAt
        case aiConfidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.startPoint = try container.decode(RoutePoint.self, forKey: .startPoint)
        self.endPoint = try container.decode(RoutePoint.self, forKey: .endPoint)
        self.waypoints = try container.decode([RoutePoint].self, forKey: .waypoints)
        self.totalDistance = try container.decode(Double.self, forKey: .totalDistance)
        self.estimatedTime = try container.decode(TimeInterval.self, forKey: .estimatedTime)
        self.overallSafetyScore = try container.decode(Double.self, forKey: .overallSafetyScore)
        let levelRaw = try container.decode(String.self, forKey: .safetyLevel)
        guard let level = SafetyLevel(rawValue: levelRaw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.safetyLevel], debugDescription: "Invalid SafetyLevel raw value: \(levelRaw)"))
        }
        self.safetyLevel = level
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.aiConfidence = try container.decode(Double.self, forKey: .aiConfidence)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(startPoint, forKey: .startPoint)
        try container.encode(endPoint, forKey: .endPoint)
        try container.encode(waypoints, forKey: .waypoints)
        try container.encode(totalDistance, forKey: .totalDistance)
        try container.encode(estimatedTime, forKey: .estimatedTime)
        try container.encode(overallSafetyScore, forKey: .overallSafetyScore)
        try container.encode(safetyLevel.rawValue, forKey: .safetyLevel)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(aiConfidence, forKey: .aiConfidence)
    }
}

// MARK: - Risk Factor
struct RiskFactor: Identifiable, Codable {
    let id: UUID
    let type: RiskType
    let severity: RiskSeverity
    let description: String
    let recommendation: String
    let location: CLLocationCoordinate2D? // Add location for map navigation
    let waypointIndex: Int? // Add waypoint index for reference
    
    init(id: UUID = UUID(), type: RiskType, severity: RiskSeverity, location: CLLocationCoordinate2D? = nil, waypointIndex: Int? = nil) {
        self.id = id
        self.type = type
        self.severity = severity
        self.description = type.description
        self.recommendation = type.recommendation
        self.location = location
        self.waypointIndex = waypointIndex
    }
}

enum RiskType: String, CaseIterable, Codable {
    case poorLighting = "Poor Lighting"
    case highCrimeArea = "High Crime Area"
    case isolatedPath = "Isolated Path"
    case constructionZone = "Construction Zone"
    case heavyTraffic = "Heavy Traffic"
    case weatherHazard = "Weather Hazard"
    case lowVisibility = "Low Visibility"
    
    var description: String {
        switch self {
        case .poorLighting: return "Limited street lighting detected"
        case .highCrimeArea: return "Area with higher incident reports"
        case .isolatedPath: return "Path with low foot traffic"
        case .constructionZone: return "Active construction area"
        case .heavyTraffic: return "High vehicle traffic area"
        case .weatherHazard: return "Weather-related safety concern"
        case .lowVisibility: return "Reduced visibility conditions"
        }
    }
    
    var recommendation: String {
        switch self {
        case .poorLighting: return "Consider well-lit alternative routes"
        case .highCrimeArea: return "Travel during busier hours if possible"
        case .isolatedPath: return "Share your location with trusted contacts"
        case .constructionZone: return "Follow posted safety signs and detours"
        case .heavyTraffic: return "Use designated crosswalks and signals"
        case .weatherHazard: return "Check weather conditions before traveling"
        case .lowVisibility: return "Wear reflective clothing and use lights"
        }
    }
}

enum RiskSeverity: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: String {
        switch self {
        case .low: return "SafetyGreen"
        case .medium: return "SafetyYellow"
        case .high: return "SafetyRed"
        }
    }
}

// MARK: - Route Request
struct RouteRequest: Codable {
    let startLocation: CLLocationCoordinate2D
    let endLocation: CLLocationCoordinate2D
    let travelMode: TravelMode
    let timeOfDay: Date
    let userPreferences: UserPreferences
    let weatherConditions: WeatherConditions?
}

enum TravelMode: String, CaseIterable, Codable {
    case walking = "Walking"
    case biking = "Biking"
    case wheelchair = "Wheelchair"
    
    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .biking: return "bicycle"
        case .wheelchair: return "figure.roll"
        }
    }
}

struct UserPreferences: Codable {
    let avoidHighCrimeAreas: Bool
    let preferWellLitRoutes: Bool
    let maxWalkingTime: TimeInterval?
    let accessibilityRequired: Bool
    let avoidBusyRoads: Bool
}

struct WeatherConditions: Codable {
    let temperature: Double
    let precipitation: Double // 0.0 to 1.0
    let visibility: Double // in meters
    let windSpeed: Double // in km/h
    let condition: WeatherCondition
}

enum WeatherCondition: String, CaseIterable, Codable {
    case clear = "Clear"
    case cloudy = "Cloudy"
    case rainy = "Rainy"
    case snowy = "Snowy"
    case foggy = "Foggy"
    case stormy = "Stormy"
}

// MARK: - Route Safety Summary
/// Lightweight model used for AI safety scoring and explanations.
/// Matches the mocked backend response shape so we can easily
/// swap in a real networked implementation later.
struct RouteSafety: Identifiable {
    let id: UUID
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
    let score: Int        // 0-100 (higher is safer)
    let summary: String   // Human-readable AI explanation
    let confidence: Double // AI confidence (0.0-1.0)
    let riskFactors: [String] // List of identified risk factors
    
    init(
        id: UUID = UUID(),
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        score: Int,
        summary: String,
        confidence: Double = 0.85,
        riskFactors: [String] = []
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.score = score
        self.summary = summary
        self.confidence = confidence
        self.riskFactors = riskFactors
    }
}

// MARK: - Route Optimization Models

struct RoutePreferences {
    let prioritizeSafety: Bool
    let avoidHills: Bool
    let preferTransit: Bool
    let avoidPollution: Bool
    let maxWalkingDistance: Double
    let transportMode: TransportMode
    
    // Scoring weights (should sum to 1.0)
    let safetyWeight: Double
    let elevationWeight: Double
    let airQualityWeight: Double
    let transitWeight: Double
    let difficultyWeight: Double
    
    static let `default` = RoutePreferences(
        prioritizeSafety: true,
        avoidHills: false,
        preferTransit: false,
        avoidPollution: false,
        maxWalkingDistance: 3000,
        transportMode: .walking,
        safetyWeight: 0.4,
        elevationWeight: 0.2,
        airQualityWeight: 0.2,
        transitWeight: 0.1,
        difficultyWeight: 0.1
    )
}

enum TransportMode: String, CaseIterable {
    case walking = "walking"
    case cycling = "cycling"
    case transit = "transit"
    
    var displayName: String {
        switch self {
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .transit: return "Transit"
        }
    }
    
    var icon: String {
        switch self {
        case .walking: return "🚶‍♂️"
        case .cycling: return "🚴‍♂️"
        case .transit: return "🚌"
        }
    }
}

struct OptimizedRoute {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let distance: Double
    let estimatedTime: TimeInterval
    let elevationProfile: ElevationProfile
    let transportMode: TransportMode
    
    var hasBikeLanes: Bool = false
    var hasSidewalks: Bool = false
    var isWellLit: Bool = false
    var passesThroughParks: Bool = false
    
    init(
        id: String = UUID().uuidString,
        coordinates: [CLLocationCoordinate2D],
        distance: Double,
        estimatedTime: TimeInterval,
        elevationProfile: ElevationProfile,
        transportMode: TransportMode
    ) {
        self.id = id
        self.coordinates = coordinates
        self.distance = distance
        self.estimatedTime = estimatedTime
        self.elevationProfile = elevationProfile
        self.transportMode = transportMode
    }
}

struct ElevationProfile {
    let elevations: [Double]
    let distances: [Double]
    
    var totalGain: Double {
        var gain: Double = 0
        for i in 1..<elevations.count {
            let diff = elevations[i] - elevations[i-1]
            if diff > 0 {
                gain += diff
            }
        }
        return gain
    }
    
    var totalLoss: Double {
        var loss: Double = 0
        for i in 1..<elevations.count {
            let diff = elevations[i] - elevations[i-1]
            if diff < 0 {
                loss += abs(diff)
            }
        }
        return loss
    }
    
    var maximumElevation: Double {
        return elevations.max() ?? 0
    }
    
    var minimumElevation: Double {
        return elevations.min() ?? 0
    }
    
    var averageElevation: Double {
        return elevations.reduce(0, +) / Double(elevations.count)
    }
    
    var maximumGrade: Double {
        var maxGrade: Double = 0
        for i in 1..<elevations.count {
            let elevationDiff = abs(elevations[i] - elevations[i-1])
            let distance = distances[i] - distances[i-1]
            let grade = (elevationDiff / distance) * 100
            maxGrade = max(maxGrade, grade)
        }
        return maxGrade
    }
}

struct RouteOption {
    let route: OptimizedRoute
    let overallScore: Double
    let safetyScore: Double
    let elevationScore: Double
    let airQualityScore: Double
    let transitScore: Double
    let difficultyScore: Double
    let characteristics: RouteCharacteristics
    let recommendations: [RouteRecommendation]
    
    var routeType: RouteType {
        if safetyScore > 0.8 && overallScore > 0.8 {
            return .safest
        } else if elevationScore > 0.8 {
            return .flattest
        } else if airQualityScore > 0.8 {
            return .cleanestAir
        } else if transitScore > 0.7 {
            return .bestTransit
        } else if route.transportMode == .cycling {
            return .bestCycling
        } else {
            return .balanced
        }
    }
    
    var displayName: String {
        switch routeType {
        case .safest: return "🛡️ Safest Route"
        case .flattest: return "⛰️ Flattest Route"
        case .cleanestAir: return "🌬️ Cleanest Air Route"
        case .bestTransit: return "🚌 Best Transit Route"
        case .bestCycling: return "🚴‍♂️ Best Cycling Route"
        case .balanced: return "⚖️ Balanced Route"
        }
    }
}

enum RouteType {
    case safest
    case flattest
    case cleanestAir
    case bestTransit
    case bestCycling
    case balanced
}

struct RouteCharacteristics {
    let distance: Double
    let estimatedTime: TimeInterval
    let elevationGain: Double
    let maxElevation: Double
    let averageAQI: Double
    let safetyLevel: SafetyLevel
    let difficultyLevel: DifficultyLevel
    let transitAccessibility: TransitLevel
    let healthImpact: HealthImpact
    let features: [RouteFeature]
    
    var formattedDistance: String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    var formattedTime: String {
        let minutes = Int(estimatedTime / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)min"
        }
    }
    
    var formattedElevation: String {
        if elevationGain < 1000 {
            return "\(Int(elevationGain))m gain"
        } else {
            return String(format: "%.1fm gain", elevationGain)
        }
    }
}

enum DifficultyLevel: String, CaseIterable {
    case easy = "Easy"
    case moderate = "Moderate"
    case challenging = "Challenging"
    case difficult = "Difficult"
    case extreme = "Extreme"
    
    var color: String {
        switch self {
        case .easy: return "#00E400"
        case .moderate: return "#FFFF00"
        case .challenging: return "#FF7E00"
        case .difficult: return "#FF0000"
        case .extreme: return "#8F3F97"
        }
    }
    
    var score: Double {
        switch self {
        case .easy: return 1.0
        case .moderate: return 0.8
        case .challenging: return 0.6
        case .difficult: return 0.4
        case .extreme: return 0.2
        }
    }
}

enum TransitLevel: String, CaseIterable {
    case none = "None"
    case poor = "Poor"
    case moderate = "Moderate"
    case good = "Good"
    case excellent = "Excellent"
    
    var color: String {
        switch self {
        case .none: return "#CCCCCC"
        case .poor: return "#FF7E00"
        case .moderate: return "#FFFF00"
        case .good: return "#7E0023"
        case .excellent: return "#00E400"
        }
    }
    
    var score: Double {
        switch self {
        case .none: return 0.0
        case .poor: return 0.25
        case .moderate: return 0.5
        case .good: return 0.75
        case .excellent: return 1.0
        }
    }
}

enum HealthImpact: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case moderate = "Moderate"
    case poor = "Poor"
    case hazardous = "Hazardous"
    
    var color: String {
        switch self {
        case .excellent: return "#00E400"
        case .good: return "#FFFF00"
        case .moderate: return "#FF7E00"
        case .poor: return "#FF0000"
        case .hazardous: return "#8F3F97"
        }
    }
    
    var score: Double {
        switch self {
        case .excellent: return 1.0
        case .good: return 0.8
        case .moderate: return 0.6
        case .poor: return 0.4
        case .hazardous: return 0.2
        }
    }
}

enum RouteFeature: String, CaseIterable {
    case bikeLanes = "Bike Lanes"
    case sidewalks = "Sidewalks"
    case wellLit = "Well Lit"
    case transitAccess = "Transit Access"
    case greenSpaces = "Green Spaces"
    case lowTraffic = "Low Traffic"
    case scenicViews = "Scenic Views"
    case restStops = "Rest Stops"
    
    var icon: String {
        switch self {
        case .bikeLanes: return "🚴"
        case .sidewalks: return "🚶"
        case .wellLit: return "💡"
        case .transitAccess: return "🚌"
        case .greenSpaces: return "🌳"
        case .lowTraffic: return "🚗"
        case .scenicViews: return "🏞️"
        case .restStops: return "🪑"
        }
    }
}

struct RouteRecommendation {
    let type: RouteRecommendationType
    let message: String
    let priority: RouteRecommendationPriority
}

enum RouteRecommendationType: String, CaseIterable {
    case safety = "Safety"
    case elevation = "Elevation"
    case health = "Health"
    case transit = "Transit"
    case weather = "Weather"
    case traffic = "Traffic"
    
    var icon: String {
        switch self {
        case .safety: return "🛡️"
        case .elevation: return "⛰️"
        case .health: return "🏥"
        case .transit: return "🚌"
        case .weather: return "🌤️"
        case .traffic: return "🚦"
        }
    }
}

enum RouteRecommendationPriority: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .low: return "#00E400"
        case .medium: return "#FFFF00"
        case .high: return "#FF7E00"
        case .critical: return "#FF0000"
        }
    }
}

struct WeightedScores {
    let safety: Double
    let elevation: Double
    let airQuality: Double
    let transit: Double
    let difficulty: Double
}

struct CombinedSafetyData {
    let incidents: [SafetyIncident]
    let infrastructureIssues: [InfrastructureIssue]
    let environmentalFactors: EnvironmentalFactors
    let elevationData: ElevationData?
    let airQualityData: AirQualityInfo?
    let transitData: TransitInfo?
    
    func getNearbyIncidents(location: CLLocationCoordinate2D, radius: Double) -> [SafetyIncident] {
        return incidents.filter { incident in
            let distance = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: incident.location.latitude, longitude: incident.location.longitude))
            return distance <= radius
        }
    }
    
    func getInfrastructureIssues(location: CLLocationCoordinate2D, radius: Double) -> [InfrastructureIssue] {
        return infrastructureIssues.filter { issue in
            let distance = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: issue.location.latitude, longitude: issue.location.longitude))
            return distance <= radius
        }
    }
}
