//
//  TrafficDataSource.swift
//  SafeRouteAI
//
//  Integrates traffic data for real-time route optimization and safety analysis
//  Provides traffic flow, congestion, and incident data for pedestrian safety
//

import Foundation
import CoreLocation

class TrafficDataSource: DataSource {
    let name = "Traffic Data"
    let priority = 1 // Lower priority for pedestrian safety
    let refreshInterval: TimeInterval = 600 // 10 minutes
    var isEnabled = true
    
    private var lastFetch: Date?
    private var cachedData: SafetyData?
    private let apiKey = "FREE_TOMTOM_API_KEY" // TomTom Free Tier: 2,500 calls/day
    
    func fetchData(for location: CLLocationCoordinate2D, radius: Double) async throws -> SafetyData {
        // Check if we have fresh cached data
        if let lastFetch = lastFetch,
           Date().timeIntervalSince(lastFetch) < refreshInterval,
           let cached = cachedData {
            return cached
        }
        
        // Fetch traffic data from TomTom API (Free Tier: 2,500 calls/day)
        let trafficData = try await fetchTrafficData(for: location, radius: radius)
        let incidents = createTrafficIncidents(from: trafficData, location: location)
        let infrastructureIssues = createTrafficInfrastructureIssues(from: trafficData, location: location)
        
        let environmentalFactors = EnvironmentalFactors(
            weatherCondition: .clear,
            visibility: 1000.0,
            temperature: 20.0,
            windSpeed: 10.0,
            precipitation: 0.0,
            timeOfDay: getCurrentTimeOfDay(),
            dayOfWeek: getCurrentDayOfWeek(),
            lightingLevel: calculateLightingLevel()
        )
        
        let safetyData = SafetyData(
            source: name,
            timestamp: Date(),
            location: location,
            incidents: incidents,
            infrastructureIssues: infrastructureIssues,
            environmentalFactors: environmentalFactors,
            confidence: 0.75 // Moderate confidence in traffic data for pedestrian safety
        )
        
        self.cachedData = safetyData
        self.lastFetch = Date()
        
        return safetyData
    }
    
    func isDataFresh(for location: CLLocationCoordinate2D) -> Bool {
        guard let lastFetch = lastFetch else { return false }
        return Date().timeIntervalSince(lastFetch) < refreshInterval
    }
    
    // MARK: - Traffic API Integration
    
    private func fetchTrafficData(for location: CLLocationCoordinate2D, radius: Double) async throws -> TrafficData {
        // TomTom Traffic Flow API - FREE tier: 2,500 calls/day
        let urlString = "https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute/10/json?key=\(apiKey)&point=\(location.latitude),\(location.longitude)"
        
        guard let url = URL(string: urlString) else {
            throw TrafficError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw TrafficError.apiError
            }
            
            let decoder = JSONDecoder()
            let tomtomResponse = try decoder.decode(TomTomFlowResponse.self, from: data)
            
            return TrafficData(
                location: location,
                congestionLevel: calculateCongestionLevel(from: tomtomResponse.flowSegmentData),
                averageSpeed: tomtomResponse.flowSegmentData.currentSpeed,
                incidents: [], // Would need separate API call for incidents
                roadClosures: [],
                constructionZones: [],
                timestamp: Date()
            )
        } catch {
            // Fallback to simulated data if API fails
            return TrafficData(
                location: location,
                congestionLevel: simulateCongestionLevel(),
                averageSpeed: simulateAverageSpeed(),
                incidents: simulateTrafficIncidents(),
                roadClosures: simulateRoadClosures(),
                constructionZones: simulateConstructionZones(),
                timestamp: Date()
            )
        }
    }
    
    private func createTrafficIncidents(from trafficData: TrafficData, location: CLLocationCoordinate2D) -> [SafetyIncident] {
        var incidents: [SafetyIncident] = []
        
        // Create incidents based on traffic conditions
        if trafficData.congestionLevel > 0.8 {
            incidents.append(SafetyIncident(
                type: .trafficAccident,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Heavy traffic congestion - increased risk",
                radius: 300.0,
                weight: 0.6
            ))
        }
        
        // Add traffic incidents
        for incident in trafficData.incidents {
            let severity: IncidentSeverity
            let impactRadius: Double
            
            switch incident.type.lowercased() {
            case "accident":
                severity = .high
                impactRadius = 400.0
            case "road_hazard":
                severity = .medium
                impactRadius = 200.0
            case "breakdown":
                severity = .low
                impactRadius = 150.0
            default:
                severity = .medium
                impactRadius = 250.0
            }
            
            incidents.append(SafetyIncident(
                type: .trafficAccident,
                severity: severity,
                location: incident.location,
                timestamp: incident.timestamp,
                description: incident.description,
                radius: impactRadius,
                weight: 0.7
            ))
        }
        
        return incidents
    }
    
    private func createTrafficInfrastructureIssues(from trafficData: TrafficData, location: CLLocationCoordinate2D) -> [InfrastructureIssue] {
        var issues: [InfrastructureIssue] = []
        
        // Add road closures
        for closure in trafficData.roadClosures {
            issues.append(InfrastructureIssue(
                type: .roadSurface,
                severity: .high,
                location: closure.location,
                timestamp: closure.timestamp,
                description: "Road closure: \(closure.reason)",
                estimatedResolutionDate: closure.estimatedReopen,
                affectedArea: Double.pi * closure.affectedRadius * closure.affectedRadius
            ))
        }
        
        // Add construction zones
        for construction in trafficData.constructionZones {
            issues.append(InfrastructureIssue(
                type: .construction,
                severity: .medium,
                location: construction.location,
                timestamp: construction.timestamp,
                description: "Construction zone: \(construction.description)",
                estimatedResolutionDate: construction.estimatedCompletion,
                affectedArea: Double.pi * construction.affectedRadius * construction.affectedRadius
            ))
        }
        
        return issues
    }
    
    // MARK: - TomTom API Models
    
    struct TomTomFlowResponse: Codable {
        let flowSegmentData: TomTomFlowSegmentData
    }
    
    struct TomTomFlowSegmentData: Codable {
        let currentSpeed: Double
        let freeFlowSpeed: Double
        let currentTravelTime: Double
        let freeFlowTravelTime: Double
        let confidence: Double
        let roadClosure: Bool
    }
    
    // MARK: - Helper Functions
    
    private func calculateCongestionLevel(from flowData: TomTomFlowSegmentData) -> Double {
        let speedRatio = flowData.currentSpeed / flowData.freeFlowSpeed
        return 1.0 - speedRatio // Higher congestion when speed is lower
    }
    
    // MARK: - Traffic Simulation (Fallback) Methods (for demo purposes)
    
    private func simulateCongestionLevel() -> Double {
        let hour = Calendar.current.component(.hour, from: Date())
        let baseCongestion: Double
        
        switch hour {
        case 7...9, 16...18: // Rush hours
            baseCongestion = 0.8
        case 10...15: // Midday
            baseCongestion = 0.4
        case 19...21: // Evening
            baseCongestion = 0.3
        default: // Night
            baseCongestion = 0.1
        }
        
        // Add randomness
        return min(max(baseCongestion + Double.random(in: -0.2...0.2), 0.0), 1.0)
    }
    
    private func simulateAverageSpeed() -> Double {
        let congestionLevel = simulateCongestionLevel()
        let maxSpeed = 50.0 // km/h in urban areas
        return maxSpeed * (1.0 - congestionLevel * 0.8)
    }
    
    private func simulateTrafficIncidents() -> [TrafficIncident] {
        var incidents: [TrafficIncident] = []
        
        // Randomly generate incidents
        if Double.random(in: 0...1) < 0.3 { // 30% chance of incidents
            let incidentTypes = ["accident", "road_hazard", "breakdown", "debris"]
            let type = incidentTypes.randomElement()!
            
            incidents.append(TrafficIncident(
                id: UUID().uuidString,
                type: type,
                location: CLLocationCoordinate2D(
                    latitude: 38.9072 + Double.random(in: -0.01...0.01),
                    longitude: -77.0369 + Double.random(in: -0.01...0.01)
                ),
                timestamp: Date().addingTimeInterval(-Double.random(in: 0...3600)),
                description: "Simulated \(type.replacingOccurrences(of: "_", with: " "))",
                severity: ["low", "medium", "high"].randomElement()!
            ))
        }
        
        return incidents
    }
    
    private func simulateRoadClosures() -> [RoadClosure] {
        var closures: [RoadClosure] = []
        
        if Double.random(in: 0...1) < 0.1 { // 10% chance of road closure
            closures.append(RoadClosure(
                id: UUID().uuidString,
                location: CLLocationCoordinate2D(
                    latitude: 38.9072 + Double.random(in: -0.01...0.01),
                    longitude: -77.0369 + Double.random(in: -0.01...0.01)
                ),
                timestamp: Date().addingTimeInterval(-Double.random(in: 0...86400)),
                reason: "Scheduled maintenance",
                estimatedReopen: Date().addingTimeInterval(Double.random(in: 3600...86400)),
                affectedRadius: Double.random(in: 100...500)
            ))
        }
        
        return closures
    }
    
    private func simulateConstructionZones() -> [ConstructionZone] {
        var zones: [ConstructionZone] = []
        
        if Double.random(in: 0...1) < 0.2 { // 20% chance of construction
            zones.append(ConstructionZone(
                id: UUID().uuidString,
                location: CLLocationCoordinate2D(
                    latitude: 38.9072 + Double.random(in: -0.01...0.01),
                    longitude: -77.0369 + Double.random(in: -0.01...0.01)
                ),
                timestamp: Date().addingTimeInterval(-Double.random(in: 0...7 * 86400)),
                description: "Road construction and utility work",
                estimatedCompletion: Date().addingTimeInterval(Double.random(in: 1...30) * 86400),
                affectedRadius: Double.random(in: 200...800),
                hasDetour: true
            ))
        }
        
        return zones
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<8: return .earlyMorning
        case 8..<10: return .morningRush
        case 10..<15: return .midday
        case 15..<18: return .afternoonRush
        case 18..<21: return .evening
        default: return .night
        }
    }
    
    private func getCurrentDayOfWeek() -> DayOfWeek {
        let weekday = Calendar.current.component(.weekday, from: Date())
        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .monday
        }
    }
    
    private func calculateLightingLevel() -> Double {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6...18: return 1.0 // Daylight
        case 19...20, 5...6: return 0.7 // Twilight
        case 21...22, 4...5: return 0.4 // Evening
        default: return 0.2 // Night
        }
    }
}

// MARK: - Traffic Data Models
struct TrafficData {
    let location: CLLocationCoordinate2D
    let congestionLevel: Double // 0.0-1.0 scale
    let averageSpeed: Double // km/h
    let incidents: [TrafficIncident]
    let roadClosures: [RoadClosure]
    let constructionZones: [ConstructionZone]
    let timestamp: Date
}

struct TrafficIncident: Codable {
    let id: String
    let type: String
    let location: CLLocationCoordinate2D
    let timestamp: Date
    let description: String
    let severity: String
    
    init(id: String, type: String, location: CLLocationCoordinate2D, timestamp: Date, description: String, severity: String) {
        self.id = id
        self.type = type
        self.location = location
        self.timestamp = timestamp
        self.description = description
        self.severity = severity
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, location, timestamp, description, severity
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.description = try container.decode(String.self, forKey: .description)
        self.severity = try container.decode(String.self, forKey: .severity)
        
        // Decode location
        let locationString = try container.decode(String.self, forKey: .location)
        let components = locationString.components(separatedBy: ",")
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.location], debugDescription: "Invalid location format"))
            }
        self.location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode("\(location.latitude),\(location.longitude)", forKey: .location)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(description, forKey: .description)
        try container.encode(severity, forKey: .severity)
    }
}

struct RoadClosure: Codable {
    let id: String
    let location: CLLocationCoordinate2D
    let timestamp: Date
    let reason: String
    let estimatedReopen: Date?
    let affectedRadius: Double
    
    init(id: String, location: CLLocationCoordinate2D, timestamp: Date, reason: String, estimatedReopen: Date?, affectedRadius: Double) {
        self.id = id
        self.location = location
        self.timestamp = timestamp
        self.reason = reason
        self.estimatedReopen = estimatedReopen
        self.affectedRadius = affectedRadius
    }
    
    enum CodingKeys: String, CodingKey {
        case id, location, timestamp, reason, estimatedReopen, affectedRadius
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.reason = try container.decode(String.self, forKey: .reason)
        self.estimatedReopen = try container.decodeIfPresent(Date.self, forKey: .estimatedReopen)
        self.affectedRadius = try container.decode(Double.self, forKey: .affectedRadius)
        
        // Decode location
        let locationString = try container.decode(String.self, forKey: .location)
        let components = locationString.components(separatedBy: ",")
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.location], debugDescription: "Invalid location format"))
            }
        self.location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode("\(location.latitude),\(location.longitude)", forKey: .location)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(reason, forKey: .reason)
        try container.encodeIfPresent(estimatedReopen, forKey: .estimatedReopen)
        try container.encode(affectedRadius, forKey: .affectedRadius)
    }
}

struct ConstructionZone: Codable {
    let id: String
    let location: CLLocationCoordinate2D
    let timestamp: Date
    let description: String
    let estimatedCompletion: Date?
    let affectedRadius: Double
    let hasDetour: Bool
    
    init(id: String, location: CLLocationCoordinate2D, timestamp: Date, description: String, estimatedCompletion: Date?, affectedRadius: Double, hasDetour: Bool) {
        self.id = id
        self.location = location
        self.timestamp = timestamp
        self.description = description
        self.estimatedCompletion = estimatedCompletion
        self.affectedRadius = affectedRadius
        self.hasDetour = hasDetour
    }
    
    enum CodingKeys: String, CodingKey {
        case id, location, timestamp, description, estimatedCompletion, affectedRadius, hasDetour
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.description = try container.decode(String.self, forKey: .description)
        self.estimatedCompletion = try container.decodeIfPresent(Date.self, forKey: .estimatedCompletion)
        self.affectedRadius = try container.decode(Double.self, forKey: .affectedRadius)
        self.hasDetour = try container.decode(Bool.self, forKey: .hasDetour)
        
        // Decode location
        let locationString = try container.decode(String.self, forKey: .location)
        let components = locationString.components(separatedBy: ",")
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.location], debugDescription: "Invalid location format"))
            }
        self.location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode("\(location.latitude),\(location.longitude)", forKey: .location)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(estimatedCompletion, forKey: .estimatedCompletion)
        try container.encode(affectedRadius, forKey: .affectedRadius)
        try container.encode(hasDetour, forKey: .hasDetour)
    }
}

// MARK: - Traffic Analysis Extensions
extension TrafficDataSource {
    
    /// Calculate traffic-based safety score
    func calculateTrafficSafetyScore(for location: CLLocationCoordinate2D, radius: Double = 300.0) async -> Double {
        do {
            let trafficData = try await fetchTrafficData(for: location, radius: radius)
            return calculateSafetyScore(from: trafficData)
        } catch {
            print("⚠️ Failed to calculate traffic safety score: \(error)")
            return 0.5 // Neutral score on error
        }
    }
    
    private func calculateSafetyScore(from trafficData: TrafficData) -> Double {
        var riskScore: Double = 0.0
        
        // Congestion risks
        riskScore += trafficData.congestionLevel * 0.3
        
        // Speed risks (lower speeds in congested areas can be safer for pedestrians)
        if trafficData.averageSpeed < 10 {
            riskScore += 0.1
        } else if trafficData.averageSpeed > 40 {
            riskScore += 0.4
        } else {
            riskScore += 0.2
        }
        
        // Incident risks
        riskScore += Double(trafficData.incidents.count) * 0.2
        
        // Road closure risks
        riskScore += Double(trafficData.roadClosures.count) * 0.3
        
        // Construction zone risks
        riskScore += Double(trafficData.constructionZones.count) * 0.25
        
        return min(max(riskScore, 0.0), 1.0)
    }
    
    /// Get traffic recommendations
    func getTrafficRecommendations(for location: CLLocationCoordinate2D, radius: Double = 300.0) async -> [TrafficRecommendation] {
        do {
            let trafficData = try await fetchTrafficData(for: location, radius: radius)
            return generateRecommendations(from: trafficData)
        } catch {
            print("⚠️ Failed to get traffic recommendations: \(error)")
            return []
        }
    }
    
    private func generateRecommendations(from trafficData: TrafficData) -> [TrafficRecommendation] {
        var recommendations: [TrafficRecommendation] = []
        
        if trafficData.congestionLevel > 0.7 {
            recommendations.append(TrafficRecommendation(
                type: .congestion,
                message: "Heavy traffic detected. Allow extra time and be cautious at crossings.",
                priority: .high
            ))
        }
        
        if !trafficData.incidents.isEmpty {
            recommendations.append(TrafficRecommendation(
                type: .incident,
                message: "Traffic incidents reported. Consider alternative routes if possible.",
                priority: .medium
            ))
        }
        
        if !trafficData.roadClosures.isEmpty {
            recommendations.append(TrafficRecommendation(
                type: .closure,
                message: "Road closures detected. Follow detour signs and allow extra time.",
                priority: .high
            ))
        }
        
        if !trafficData.constructionZones.isEmpty {
            recommendations.append(TrafficRecommendation(
                type: .construction,
                message: "Construction zones ahead. Follow posted signs and be aware of workers.",
                priority: .medium
            ))
        }
        
        if trafficData.averageSpeed > 40 {
            recommendations.append(TrafficRecommendation(
                type: .speed,
                message: "High traffic speeds in area. Use designated crosswalks and wait for clear signals.",
                priority: .medium
            ))
        }
        
        return recommendations
    }
}

// MARK: - Traffic Recommendation Models
struct TrafficRecommendation {
    let type: TrafficRecommendationType
    let message: String
    let priority: RecommendationPriority
}

enum TrafficRecommendationType: String, CaseIterable {
    case congestion = "Congestion"
    case incident = "Incident"
    case closure = "Road Closure"
    case construction = "Construction"
    case speed = "High Speed"
    
    var icon: String {
        switch self {
        case .congestion: return "car.fill"
        case .incident: return "exclamationmark.triangle.fill"
        case .closure: return "road.lane.closed"
        case .construction: return "cone.fill"
        case .speed: return "speedometer"
        }
    }
}

enum RecommendationPriority: String, CaseIterable {
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
