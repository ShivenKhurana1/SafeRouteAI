//
//  EnhancedTrafficDataSource.swift
//  SafeRouteAI
//
//  Enhanced traffic data using TomTom API with free tier
//  2,500 calls/day - completely free with API key
//

import Foundation
import CoreLocation

class EnhancedTrafficDataSource: DataSource {
    let name = "Enhanced Traffic Data"
    let priority = 1 // Lower priority for pedestrian safety
    let refreshInterval: TimeInterval = 600 // 10 minutes
    var isEnabled = true
    
    private var lastFetch: Date?
    private var cachedData: SafetyData?
    
    // TomTom API - FREE tier: 2,500 calls/day
    private let apiKey = "YOUR_TOMTOM_API_KEY" // Get free key from https://developer.tomtom.com/
    
    func fetchData(for location: CLLocationCoordinate2D, radius: Double) async throws -> SafetyData {
        // Check if we have fresh cached data
        if let lastFetch = lastFetch,
           Date().timeIntervalSince(lastFetch) < refreshInterval,
           let cached = cachedData {
            return cached
        }
        
        // Fetch traffic data from TomTom API
        let trafficData = try await fetchTomTomTrafficData(for: location, radius: radius)
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
            confidence: 0.90 // High confidence with TomTom
        )
        
        self.cachedData = safetyData
        self.lastFetch = Date()
        
        return safetyData
    }
    
    func isDataFresh(for location: CLLocationCoordinate2D) -> Bool {
        guard let lastFetch = lastFetch else { return false }
        return Date().timeIntervalSince(lastFetch) < refreshInterval
    }
    
    // MARK: - TomTom API Integration
    
    private func fetchTomTomTrafficData(for location: CLLocationCoordinate2D, radius: Double) async throws -> EnhancedTrafficData {
        // TomTom Traffic Flow API - FREE tier: 2,500 calls/day
        let flowUrlString = "https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute/10/json?key=\(apiKey)&point=\(location.latitude),\(location.longitude)"
        
        guard let flowUrl = URL(string: flowUrlString) else {
            throw TrafficError.invalidURL
        }
        
        let (flowData, flowResponse) = try await URLSession.shared.data(from: flowUrl)
        
        guard let flowHttpResponse = flowResponse as? HTTPURLResponse,
              flowHttpResponse.statusCode == 200 else {
            throw TrafficError.apiError
        }
        
        let flowDecoder = JSONDecoder()
        let flowResponseData = try flowDecoder.decode(TomTomFlowResponse.self, from: flowData)
        
        // TomTom Traffic Incidents API - FREE tier: 2,500 calls/day
        let incidentsUrlString = "https://api.tomtom.com/traffic/services/4/incidentDetails/absolute/10/json?key=\(apiKey)&boundingBox=\(location.latitude - 0.05),\(location.longitude - 0.05),\(location.latitude + 0.05),\(location.longitude + 0.05)&fields={incidents{type{id,description,severity,iconCategory{shape,fillColor,icon}},geometry{type,coordinates},startTime,endTime,from,to,length,delay,impacting,acquiring,roadNumbers{from,to},magnitudeOfDelay}}"
        
        guard let incidentsUrl = URL(string: incidentsUrlString) else {
            throw TrafficError.invalidURL
        }
        
        let (incidentsData, incidentsResponse) = try await URLSession.shared.data(from: incidentsUrl)
        
        guard let incidentsHttpResponse = incidentsResponse as? HTTPURLResponse,
              incidentsHttpResponse.statusCode == 200 else {
            throw TrafficError.apiError
        }
        
        let incidentsDecoder = JSONDecoder()
        let incidentsResponseData = try incidentsDecoder.decode(TomTomIncidentsResponse.self, from: incidentsData)
        
        return EnhancedTrafficData(
            location: location,
            flowData: flowResponseData.flowSegmentData,
            incidents: incidentsResponseData.incidents,
            timestamp: Date()
        )
    }
    
    // MARK: - Traffic Incident Creation
    
    private func createTrafficIncidents(from trafficData: EnhancedTrafficData, location: CLLocationCoordinate2D) -> [SafetyIncident] {
        var incidents: [SafetyIncident] = []
        
        // Create incidents based on traffic flow
        let congestionLevel = 1.0 - (trafficData.flowData.currentSpeed / trafficData.flowData.freeFlowSpeed)
        
        if congestionLevel > 0.8 {
            incidents.append(SafetyIncident(
                type: .trafficAccident,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Heavy traffic congestion detected",
                radius: 300.0,
                weight: 0.6
            ))
        }
        
        // Add specific traffic incidents
        for incident in trafficData.incidents {
            let severity: IncidentSeverity
            let impactRadius: Double
            
            switch incident.iconCategory {
            case "accident", "crash":
                severity = .high
                impactRadius = 400.0
            case "roadwork", "construction":
                severity = .medium
                impactRadius = 250.0
            case "hazard", "debris":
                severity = .medium
                impactRadius = 200.0
            case "closure", "blocked":
                severity = .high
                impactRadius = 500.0
            default:
                severity = .medium
                impactRadius = 300.0
            }
            
            let incidentLocation = CLLocationCoordinate2D(
                latitude: incident.geometry.coordinates[1],
                longitude: incident.geometry.coordinates[0]
            )
            
            incidents.append(SafetyIncident(
                type: .trafficAccident,
                severity: severity,
                location: incidentLocation,
                timestamp: Date(timeIntervalSince1970: incident.startTime),
                description: incident.description,
                radius: impactRadius,
                weight: 0.7
            ))
        }
        
        return incidents
    }
    
    private func createTrafficInfrastructureIssues(from trafficData: EnhancedTrafficData, location: CLLocationCoordinate2D) -> [InfrastructureIssue] {
        var issues: [InfrastructureIssue] = []
        
        // Add infrastructure issues from traffic incidents
        for incident in trafficData.incidents {
            if incident.iconCategory == "roadwork" || incident.iconCategory == "construction" {
                let issueLocation = CLLocationCoordinate2D(
                    latitude: incident.geometry.coordinates[1],
                    longitude: incident.geometry.coordinates[0]
                )
                
                let affectedArea = Double.pi * incident.length * incident.length
                
                issues.append(InfrastructureIssue(
                    type: .construction,
                    severity: .medium,
                    location: issueLocation,
                    timestamp: Date(timeIntervalSince1970: incident.startTime),
                    description: incident.description,
                    estimatedResolutionDate: Date(timeIntervalSince1970: incident.endTime),
                    affectedArea: affectedArea
                ))
            }
            
            if incident.iconCategory == "closure" || incident.iconCategory == "blocked" {
                let issueLocation = CLLocationCoordinate2D(
                    latitude: incident.geometry.coordinates[1],
                    longitude: incident.geometry.coordinates[0]
                )
                
                let affectedArea = Double.pi * incident.length * incident.length
                
                issues.append(InfrastructureIssue(
                    type: .roadSurface,
                    severity: .high,
                    location: issueLocation,
                    timestamp: Date(timeIntervalSince1970: incident.startTime),
                    description: "Road closure: \(incident.description)",
                    estimatedResolutionDate: Date(timeIntervalSince1970: incident.endTime),
                    affectedArea: affectedArea
                ))
            }
        }
        
        return issues
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

// MARK: - TomTom Data Models

struct TomTomFlowResponse: Codable {
    let flowSegmentData: TomTomFlowSegmentData
}

struct TomTomFlowSegmentData: Codable {
    let frc: Int // Functional Road Class
    let currentSpeed: Double
    let freeFlowSpeed: Double
    let currentTravelTime: Double
    let freeFlowTravelTime: Double
    let confidence: Double
    let roadClosure: Bool?
    let coordinates: String?
}

struct TomTomIncidentsResponse: Codable {
    let incidents: [TomTomIncident]
}

struct TomTomIncident: Codable {
    let id: String
    let type: String
    let geometry: TomTomGeometry
    let properties: TomTomProperties
    let iconCategory: String
    let description: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let from: String
    let to: String
    let length: Double
    let delay: Double
    let impacting: Bool
    let acquiring: Bool
    let roadNumbers: TomTomRoadNumbers
    let magnitudeOfDelay: Int
    
    private enum CodingKeys: String, CodingKey {
        case id, type, geometry, properties, iconCategory, description, startTime, endTime, from, to, length, delay, impacting, acquiring, roadNumbers, magnitudeOfDelay
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.geometry = try container.decode(TomTomGeometry.self, forKey: .geometry)
        self.properties = try container.decode(TomTomProperties.self, forKey: .properties)
        
        // Icon category might be nested in properties
        if let iconCat = try? container.decode(String.self, forKey: .iconCategory) {
            self.iconCategory = iconCat
        } else {
            self.iconCategory = properties.iconCategory ?? "unknown"
        }
        
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? properties.description ?? "Traffic incident"
        self.startTime = try container.decodeIfPresent(TimeInterval.self, forKey: .startTime) ?? properties.startTime ?? Date().timeIntervalSince1970
        self.endTime = try container.decodeIfPresent(TimeInterval.self, forKey: .endTime) ?? properties.endTime ?? Date().timeIntervalSince1970 + 3600
        self.from = try container.decodeIfPresent(String.self, forKey: .from) ?? properties.from ?? ""
        self.to = try container.decodeIfPresent(String.self, forKey: .to) ?? properties.to ?? ""
        self.length = try container.decodeIfPresent(Double.self, forKey: .length) ?? properties.length ?? 100.0
        self.delay = try container.decodeIfPresent(Double.self, forKey: .delay) ?? properties.delay ?? 0.0
        self.impacting = try container.decodeIfPresent(Bool.self, forKey: .impacting) ?? properties.impacting ?? true
        self.acquiring = try container.decodeIfPresent(Bool.self, forKey: .acquiring) ?? properties.acquiring ?? false
        self.roadNumbers = try container.decodeIfPresent(TomTomRoadNumbers.self, forKey: .roadNumbers) ?? properties.roadNumbers ?? TomTomRoadNumbers()
        self.magnitudeOfDelay = try container.decodeIfPresent(Int.self, forKey: .magnitudeOfDelay) ?? properties.magnitudeOfDelay ?? 0
    }
}

struct TomTomGeometry: Codable {
    let type: String
    let coordinates: [Double]
}

struct TomTomProperties: Codable {
    let id: String?
    let iconCategory: String?
    let description: String?
    let startTime: TimeInterval?
    let endTime: TimeInterval?
    let from: String?
    let to: String?
    let length: Double?
    let delay: Double?
    let impacting: Bool?
    let acquiring: Bool?
    let roadNumbers: TomTomRoadNumbers?
    let magnitudeOfDelay: Int?
}

struct TomTomRoadNumbers: Codable {
    let from: String?
    let to: String?
    
    init(from: String = "", to: String = "") {
        self.from = from
        self.to = to
    }
}

// MARK: - Enhanced Traffic Data Model

struct EnhancedTrafficData {
    let location: CLLocationCoordinate2D
    let flowData: TomTomFlowSegmentData
    let incidents: [TomTomIncident]
    let timestamp: Date
    
    init(location: CLLocationCoordinate2D, flowData: TomTomFlowSegmentData, incidents: [TomTomIncident], timestamp: Date) {
        self.location = location
        self.flowData = flowData
        self.incidents = incidents
        self.timestamp = timestamp
    }
    
    var congestionLevel: Double {
        guard flowData.freeFlowSpeed > 0 else { return 0.0 }
        return 1.0 - (flowData.currentSpeed / flowData.freeFlowSpeed)
    }
    
    var averageSpeed: Double {
        return flowData.currentSpeed
    }
    
    var hasRoadClosure: Bool {
        return flowData.roadClosure ?? false
    }
}

enum TrafficError: Error {
    case invalidURL
    case apiError
    case decodingError
    case noData
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid traffic API URL"
        case .apiError:
            return "Traffic API request failed"
        case .decodingError:
            return "Failed to decode traffic data"
        case .noData:
            return "No traffic data available"
        }
    }
}
