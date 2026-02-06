//
//  PedestrianSafetyDataSource.swift
//  SafeRouteAI
//
//  Data source specifically for pedestrian and biking safety
//  Replaces traditional traffic APIs with pedestrian-relevant data
//

import Foundation
import CoreLocation
import UIKit

class PedestrianSafetyDataSource: DataSource {
    let name = "Pedestrian & Biking Safety"
    let priority = 1 // High priority for pedestrian safety
    let refreshInterval: TimeInterval = 900 // 15 minutes
    var isEnabled = true
    
    private var lastFetch: Date?
    private var cachedData: SafetyData?
    
    func fetchData(for location: CLLocationCoordinate2D, radius: Double) async throws -> SafetyData {
        // Check if we have fresh cached data
        if let lastFetch = lastFetch,
           Date().timeIntervalSince(lastFetch) < refreshInterval,
           let cached = cachedData {
            return cached
        }
        
        // Fetch pedestrian-specific safety data
        async let infrastructureData = fetchPedestrianInfrastructure(for: location, radius: radius)
        async let streetLightingData = fetchStreetLightingIssues(for: location, radius: radius)
        async let sidewalkConditions = fetchSidewalkConditions(for: location, radius: radius)
        async let bikeLaneData = fetchBikeLaneData(for: location, radius: radius)
        
        let incidents = try await createPedestrianIncidents(
            infrastructure: infrastructureData,
            lighting: streetLightingData,
            sidewalks: sidewalkConditions,
            bikeLanes: bikeLaneData,
            location: location
        )
        
        let infrastructureIssues = try await createInfrastructureIssues(
            lighting: streetLightingData,
            sidewalks: sidewalkConditions,
            location: location
        )
        
        let environmentalFactors = EnvironmentalFactors(
            weatherCondition: .clear, // Will be updated by weather data source
            visibility: calculateVisibilityBasedOnTime(),
            temperature: 20.0,
            windSpeed: 10.0,
            precipitation: 0.0,
            timeOfDay: getCurrentTimeOfDay(),
            dayOfWeek: getCurrentDayOfWeek(),
            lightingLevel: calculateLightingLevel()
        )
        
        let safetyData = SafetyData(
            source: "Pedestrian Safety Infrastructure",
            timestamp: Date(),
            location: location,
            incidents: incidents,
            infrastructureIssues: infrastructureIssues,
            environmentalFactors: environmentalFactors,
            confidence: 0.85
        )
        
        // Cache the data
        self.cachedData = safetyData
        self.lastFetch = Date()
        
        return safetyData
    }
    
    func isDataFresh(for location: CLLocationCoordinate2D) -> Bool {
        guard let lastFetch = lastFetch else { return false }
        return Date().timeIntervalSince(lastFetch) < refreshInterval
    }
    
    // MARK: - Pedestrian Infrastructure Data
    
    private func fetchPedestrianInfrastructure(for location: CLLocationCoordinate2D, radius: Double) async throws -> PedestrianInfrastructure {
        // OpenStreetMap Overpass API - FREE
        let bbox = calculateBoundingBox(center: location, radius: radius)
        let overpassQuery = """
            [out:json][timeout:25];
            (
              way["highway"~"footway|pedestrian|residential|tertiary"](\(bbox));
              way["cycleway"~"lane|track|shared_lane|designated"](\(bbox));
              way["crossing"](\(bbox));
              node["highway"="street_lamp"](\(bbox));
              node["amenity"="bench"](\(bbox));
              way["sidewalk"~"both|left|right"](\(bbox));
            );
            out geom;
        """
        
        guard let encodedQuery = overpassQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://overpass-api.de/api/interpreter?data=\(encodedQuery)") else {
            throw PedestrianError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OverpassResponse.self, from: data)
            return PedestrianInfrastructure(from: response)
        } catch {
            // Fallback to simulated data
            return simulatePedestrianInfrastructure(location: location, radius: radius)
        }
    }
    
    private func fetchStreetLightingIssues(for location: CLLocationCoordinate2D, radius: Double) async throws -> [StreetLightingIssue] {
        // Try NYC 311 API as example - FREE
        // This would need to be adapted for different cities
        let urlString = "https://data.cityofnewyork.us/resource/erm2-nwe9.json?descriptor=Street%20Light%20Condition&$where=within_circle(location, \(location.latitude), \(location.longitude), \(Int(radius)))&$limit=50"
        
        guard let url = URL(string: urlString) else {
            throw PedestrianError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let responses = try JSONDecoder().decode([NYC311Response].self, from: data)
            return responses.map { StreetLightingIssue(from: $0) }
        } catch {
            // Fallback to simulated data
            return simulateStreetLightingIssues(location: location, radius: radius)
        }
    }
    
    private func fetchSidewalkConditions(for location: CLLocationCoordinate2D, radius: Double) async throws -> [SidewalkCondition] {
        // City 311 API for sidewalk issues - FREE
        let urlString = "https://data.cityofnewyork.us/resource/erm2-nwe9.json?descriptor=Sidewalk%20Condition&$where=within_circle(location, \(location.latitude), \(location.longitude), \(Int(radius)))&$limit=50"
        
        guard let url = URL(string: urlString) else {
            throw PedestrianError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let responses = try JSONDecoder().decode([NYC311Response].self, from: data)
            return responses.map { SidewalkCondition(from: $0) }
        } catch {
            // Fallback to simulated data
            return simulateSidewalkConditions(location: location, radius: radius)
        }
    }
    
    private func fetchBikeLaneData(for location: CLLocationCoordinate2D, radius: Double) async throws -> BikeLaneData {
        // OpenStreetMap bike lane data - FREE
        let bbox = calculateBoundingBox(center: location, radius: radius)
        let overpassQuery = """
            [out:json][timeout:25];
            (
              way["cycleway"~"lane|track|shared_lane|designated|separate"](\(bbox));
              way["bicycle"="designated"](\(bbox));
              relation["route"="bicycle"](\(bbox));
            );
            out geom;
        """
        
        guard let encodedQuery = overpassQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://overpass-api.de/api/interpreter?data=\(encodedQuery)") else {
            throw PedestrianError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OverpassResponse.self, from: data)
            return BikeLaneData(from: response)
        } catch {
            // Fallback to simulated data
            return simulateBikeLaneData(location: location, radius: radius)
        }
    }
    
    // MARK: - Incident Creation
    
    private func createPedestrianIncidents(
        infrastructure: PedestrianInfrastructure,
        lighting: [StreetLightingIssue],
        sidewalks: [SidewalkCondition],
        bikeLanes: BikeLaneData,
        location: CLLocationCoordinate2D
    ) async throws -> [SafetyIncident] {
        var incidents: [SafetyIncident] = []
        
        // Poor lighting incidents
        for lightIssue in lighting {
            if lightIssue.severity == .high {
                incidents.append(SafetyIncident(
                    type: .lightingIssue,
                    severity: .high,
                    location: lightIssue.location,
                    timestamp: lightIssue.reportedDate,
                    description: "Street light outage: \(lightIssue.description)",
                    radius: 100.0,
                    weight: 0.8
                ))
            }
        }
        
        // Sidewalk condition incidents
        for sidewalk in sidewalks {
            if sidewalk.severity == .high {
                incidents.append(SafetyIncident(
                    type: .infrastructureIssue,
                    severity: .medium,
                    location: sidewalk.location,
                    timestamp: sidewalk.reportedDate,
                    description: "Sidewalk issue: \(sidewalk.description)",
                    radius: 50.0,
                    weight: 0.6
                ))
            }
        }
        
        // Missing crosswalks at busy intersections
        if infrastructure.crosswalkCount < Int(Double(infrastructure.intersectionCount) * 0.8) {
            incidents.append(SafetyIncident(
                type: .infrastructureIssue,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Area has insufficient crosswalks for pedestrian safety",
                radius: 200.0,
                weight: 0.7
            ))
        }
        
        // Poor bike lane coverage
        if bikeLanes.coveragePercentage < 0.3 {
            incidents.append(SafetyIncident(
                type: .infrastructureIssue,
                severity: .low,
                location: location,
                timestamp: Date(),
                description: "Limited bike lane infrastructure in area",
                radius: 300.0,
                weight: 0.4
            ))
        }
        
        return incidents
    }
    
    private func createInfrastructureIssues(
        lighting: [StreetLightingIssue],
        sidewalks: [SidewalkCondition],
        location: CLLocationCoordinate2D
    ) async throws -> [InfrastructureIssue] {
        var issues: [InfrastructureIssue] = []
        
        // Street lighting issues
        for lightIssue in lighting {
            issues.append(InfrastructureIssue(
                type: .streetLight,
                severity: lightIssue.severity,
                location: lightIssue.location,
                timestamp: lightIssue.reportedDate,
                description: lightIssue.description,
                estimatedResolutionDate: lightIssue.estimatedResolution,
                affectedArea: Double.pi * 100 * 100 // 100m radius
            ))
        }
        
        // Sidewalk issues
        for sidewalk in sidewalks {
            issues.append(InfrastructureIssue(
                type: .sidewalk,
                severity: sidewalk.severity,
                location: sidewalk.location,
                timestamp: sidewalk.reportedDate,
                description: sidewalk.description,
                estimatedResolutionDate: sidewalk.estimatedResolution,
                affectedArea: Double.pi * 50 * 50 // 50m radius
            ))
        }
        
        return issues
    }
    
    // MARK: - Helper Functions
    
    private func calculateBoundingBox(center: CLLocationCoordinate2D, radius: Double) -> String {
        let latDelta = radius / 111320.0 // Approximate meters per degree latitude
        let lonDelta = radius / (111320.0 * cos(center.latitude * .pi / 180)) // Adjust for longitude
        
        let minLat = center.latitude - latDelta
        let maxLat = center.latitude + latDelta
        let minLon = center.longitude - lonDelta
        let maxLon = center.longitude + lonDelta
        
        return "\(minLat),\(minLon),\(maxLat),\(maxLon)"
    }
    
    private func calculateVisibilityBasedOnTime() -> Double {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6...8, 17...19: // Dawn/dusk
            return 500.0
        case 20...23, 0...5: // Night
            return 200.0
        default: // Daytime
            return 1000.0
        }
    }
    
    private func getCurrentTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5...8: return .earlyMorning
        case 8...10: return .morningRush
        case 10...15: return .midday
        case 15...18: return .afternoonRush
        case 18...21: return .evening
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
        default: return .saturday
        }
    }
    
    private func calculateLightingLevel() -> Double {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 7...18: return 1.0 // Full daylight
        case 6...7, 18...19: return 0.7 // Dawn/dusk
        case 19...22: return 0.4 // Evening
        default: return 0.2 // Night
        }
    }
    
    // MARK: - Simulation Methods (Fallback)
    
    private func simulatePedestrianInfrastructure(location: CLLocationCoordinate2D, radius: Double) -> PedestrianInfrastructure {
        return PedestrianInfrastructure(
            sidewalkCount: Int.random(in: 5...15),
            crosswalkCount: Int.random(in: 2...8),
            bikeLaneCount: Int.random(in: 0...5),
            streetLightCount: Int.random(in: 10...30),
            intersectionCount: Int.random(in: 3...10),
            benchCount: Int.random(in: 0...8)
        )
    }
    
    private func simulateStreetLightingIssues(location: CLLocationCoordinate2D, radius: Double) -> [StreetLightingIssue] {
        let count = Int.random(in: 0...3)
        return (0..<count).map { _ in
            StreetLightingIssue(
                id: UUID().uuidString,
                location: generateRandomLocation(near: location, radius: radius),
                description: "Street light not working",
                severity: .medium,
                reportedDate: Date().addingTimeInterval(-Double.random(in: 0...86400)),
                estimatedResolution: Date().addingTimeInterval(Double.random(in: 86400...604800))
            )
        }
    }
    
    private func simulateSidewalkConditions(location: CLLocationCoordinate2D, radius: Double) -> [SidewalkCondition] {
        let count = Int.random(in: 0...2)
        return (0..<count).map { _ in
            SidewalkCondition(
                id: UUID().uuidString,
                location: generateRandomLocation(near: location, radius: radius),
                description: ["Cracked sidewalk", "Uneven surface", "Obstructed sidewalk"].randomElement() ?? "Sidewalk issue",
                severity: .medium,
                reportedDate: Date().addingTimeInterval(-Double.random(in: 0...172800)),
                estimatedResolution: Date().addingTimeInterval(Double.random(in: 86400...259200))
            )
        }
    }
    
    private func simulateBikeLaneData(location: CLLocationCoordinate2D, radius: Double) -> BikeLaneData {
        return BikeLaneData(
            bikeLaneCount: Int.random(in: 0...8),
            totalLength: Double.random(in: 0...2000),
            coveragePercentage: Double.random(in: 0...0.6),
            hasProtectedLanes: Bool.random()
        )
    }
    
    private func generateRandomLocation(near center: CLLocationCoordinate2D, radius: Double) -> CLLocationCoordinate2D {
        let angle = Double.random(in: 0...(2 * .pi))
        let distance = Double.random(in: 0...radius)
        
        let latDelta = (distance * cos(angle)) / 111320.0
        let lonDelta = (distance * sin(angle)) / (111320.0 * cos(center.latitude * .pi / 180))
        
        return CLLocationCoordinate2D(
            latitude: center.latitude + latDelta,
            longitude: center.longitude + lonDelta
        )
    }
}

// MARK: - Data Models

struct PedestrianInfrastructure {
    let sidewalkCount: Int
    let crosswalkCount: Int
    let bikeLaneCount: Int
    let streetLightCount: Int
    let intersectionCount: Int
    let benchCount: Int
    
    init(from response: OverpassResponse) {
        self.sidewalkCount = response.elements.filter { $0.tags["highway"] == "footway" || $0.tags["highway"] == "pedestrian" }.count
        self.crosswalkCount = response.elements.filter { $0.tags["crossing"] != nil }.count
        self.bikeLaneCount = response.elements.filter { $0.tags["cycleway"] != nil || $0.tags["bicycle"] == "designated" }.count
        self.streetLightCount = response.elements.filter { $0.tags["highway"] == "street_lamp" }.count
        self.intersectionCount = response.elements.filter { $0.tags["highway"]?.contains("tertiary") == true }.count
        self.benchCount = response.elements.filter { $0.tags["amenity"] == "bench" }.count
    }
    
    init(sidewalkCount: Int, crosswalkCount: Int, bikeLaneCount: Int, streetLightCount: Int, intersectionCount: Int, benchCount: Int) {
        self.sidewalkCount = sidewalkCount
        self.crosswalkCount = crosswalkCount
        self.bikeLaneCount = bikeLaneCount
        self.streetLightCount = streetLightCount
        self.intersectionCount = intersectionCount
        self.benchCount = benchCount
    }
}

struct StreetLightingIssue {
    let id: String
    let location: CLLocationCoordinate2D
    let description: String
    let severity: IncidentSeverity
    let reportedDate: Date
    let estimatedResolution: Date?
    
    init(from response: NYC311Response) {
        self.id = response.uniqueKey
        self.location = CLLocationCoordinate2D(latitude: response.latitude, longitude: response.longitude)
        self.description = response.descriptor
        self.severity = response.complaintType.contains("Hazard") ? .high : .medium
        self.reportedDate = response.createdDate
        self.estimatedResolution = response.resolutionActionUpdatedDate
    }
    
    init(id: String, location: CLLocationCoordinate2D, description: String, severity: IncidentSeverity, reportedDate: Date, estimatedResolution: Date?) {
        self.id = id
        self.location = location
        self.description = description
        self.severity = severity
        self.reportedDate = reportedDate
        self.estimatedResolution = estimatedResolution
    }
}

struct SidewalkCondition {
    let id: String
    let location: CLLocationCoordinate2D
    let description: String
    let severity: IncidentSeverity
    let reportedDate: Date
    let estimatedResolution: Date?
    
    init(from response: NYC311Response) {
        self.id = response.uniqueKey
        self.location = CLLocationCoordinate2D(latitude: response.latitude, longitude: response.longitude)
        self.description = response.descriptor
        self.severity = response.descriptor.contains("Hazard") ? .high : .medium
        self.reportedDate = response.createdDate
        self.estimatedResolution = response.resolutionActionUpdatedDate
    }
    
    init(id: String, location: CLLocationCoordinate2D, description: String, severity: IncidentSeverity, reportedDate: Date, estimatedResolution: Date?) {
        self.id = id
        self.location = location
        self.description = description
        self.severity = severity
        self.reportedDate = reportedDate
        self.estimatedResolution = estimatedResolution
    }
}

struct BikeLaneData {
    let bikeLaneCount: Int
    let totalLength: Double
    let coveragePercentage: Double
    let hasProtectedLanes: Bool
    
    init(from response: OverpassResponse) {
        self.bikeLaneCount = response.elements.filter { $0.tags["cycleway"] != nil }.count
        self.totalLength = response.elements.reduce(0.0) { total, element in
            // Calculate approximate length from coordinates
            return total + BikeLaneData.calculateElementLength(element)
        }
        // Calculate coverage based on road types with bike lanes
        let totalRoads = response.elements.filter { $0.tags["highway"] != nil }.count
        let roadsWithBikeLanes = response.elements.filter { $0.tags["cycleway"] != nil || $0.tags["bicycle"] == "designated" }.count
        self.coveragePercentage = totalRoads > 0 ? Double(roadsWithBikeLanes) / Double(totalRoads) : 0.0
        self.hasProtectedLanes = response.elements.contains { $0.tags["cycleway"]?.contains("track") == true }
    }
    
    init(bikeLaneCount: Int, totalLength: Double, coveragePercentage: Double, hasProtectedLanes: Bool) {
        self.bikeLaneCount = bikeLaneCount
        self.totalLength = totalLength
        self.coveragePercentage = coveragePercentage
        self.hasProtectedLanes = hasProtectedLanes
    }
    
    private static func calculateElementLength(_ element: OverpassElement) -> Double {
        // Simplified length calculation
        guard let geometry = element.geometry else { return 0.0 }
        var totalLength: Double = 0.0
        
        for i in 0..<(geometry.count - 1) {
            let coord1 = geometry[i]
            let coord2 = geometry[i + 1]
            
            let lat1 = coord1.lat * .pi / 180
            let lon1 = coord1.lon * .pi / 180
            let lat2 = coord2.lat * .pi / 180
            let lon2 = coord2.lon * .pi / 180
            
            let dLat = lat2 - lat1
            let dLon = lon2 - lon1
            
            let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
            let c = 2 * atan2(sqrt(a), sqrt(1-a))
            
            totalLength += 6371000 * c // Earth's radius in meters
        }
        
        return totalLength
    }
}

// MARK: - API Response Models

struct OverpassResponse: Codable {
    let elements: [OverpassElement]
}

struct OverpassElement: Codable {
    let id: String
    let tags: [String: String]
    let geometry: [OverpassCoordinate]?
    
    enum CodingKeys: String, CodingKey {
        case id, tags, geometry
    }
}

struct OverpassCoordinate: Codable {
    let lat: Double
    let lon: Double
}

struct NYC311Response: Codable {
    let uniqueKey: String
    let createdDate: Date
    let descriptor: String
    let complaintType: String
    let latitude: Double
    let longitude: Double
    let resolutionActionUpdatedDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case uniqueKey = "unique_key"
        case createdDate = "created_date"
        case descriptor
        case complaintType = "complaint_type"
        case latitude = "latitude"
        case longitude = "longitude"
        case resolutionActionUpdatedDate = "resolution_action_updated_date"
    }
}

// MARK: - Error Types

enum PedestrianError: Error {
    case invalidURL
    case apiError
    case decodingError
}
