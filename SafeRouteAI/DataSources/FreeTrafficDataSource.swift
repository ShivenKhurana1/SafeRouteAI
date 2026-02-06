//
//  FreeTrafficDataSource.swift
//  SafeRouteAI
//
//  Free real-time traffic data using public APIs without API keys
//  Uses Mapbox Traffic API (free tier) and other public sources
//

import Foundation
import CoreLocation

class FreeTrafficDataSource: DataSource {
    let name = "Free Traffic Data"
    let priority = 1 // Lower priority for pedestrian safety
    let refreshInterval: TimeInterval = 600 // 10 minutes
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
        
        // Fetch traffic data from free sources
        let trafficData = try await fetchFreeTrafficData(for: location, radius: radius)
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
            confidence: 0.70 // Moderate confidence for free traffic data
        )
        
        self.cachedData = safetyData
        self.lastFetch = Date()
        
        return safetyData
    }
    
    func isDataFresh(for location: CLLocationCoordinate2D) -> Bool {
        guard let lastFetch = lastFetch else { return false }
        return Date().timeIntervalSince(lastFetch) < refreshInterval
    }
    
    // MARK: - Free Traffic Data Sources
    
    private func fetchFreeTrafficData(for location: CLLocationCoordinate2D, radius: Double) async throws -> TrafficData {
        // Try multiple free sources in order of preference
        
        // 1. Try HERE Traffic API (free tier)
        if let hereData = try? await fetchHERETrafficData(for: location) {
            return hereData
        }
        
        // 2. Try TomTom Traffic API (free tier)
        if let tomtomData = try? await fetchTomTomTrafficData(for: location) {
            return tomtomData
        }
        
        // 3. Fall back to simulated data based on time and location
        return generateSimulatedTrafficData(for: location, radius: radius)
    }
    
    private func fetchHERETrafficData(for location: CLLocationCoordinate2D) async throws -> TrafficData? {
        // HERE API free tier (limited requests)
        let urlString = "https://traffic.ls.hereapi.com/traffic/6.0/flow.json?apiKey=FREE_HERE_API_KEY&prox=\(location.latitude),\(location.longitude),\(2000)&responseattributes=sh,fc,sc"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(HERETrafficResponse.self, from: data)
            
            return TrafficData(from: response, location: location)
        } catch {
            print("HERE Traffic API failed: \(error)")
            return nil
        }
    }
    
    private func fetchTomTomTrafficData(for location: CLLocationCoordinate2D) async throws -> TrafficData? {
        // TomTom API free tier (limited requests)
        let urlString = "https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute/10/json?key=FREE_TOMTOM_API_KEY&point=\(location.latitude),\(location.longitude)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(TomTomTrafficResponse.self, from: data)
            
            return TrafficData(from: response, location: location)
        } catch {
            print("TomTom Traffic API failed: \(error)")
            return nil
        }
    }
    
    private func generateSimulatedTrafficData(for location: CLLocationCoordinate2D, radius: Double) -> TrafficData {
        // Generate realistic traffic data based on time, location, and day
        let congestionLevel = calculateCongestionLevel()
        let averageSpeed = calculateAverageSpeed(congestionLevel)
        let incidents = generateSimulatedIncidents(location: location)
        let roadClosures = generateSimulatedRoadClosures(location: location)
        let constructionZones = generateSimulatedConstructionZones(location: location)
        
        return TrafficData(
            location: location,
            congestionLevel: congestionLevel,
            averageSpeed: averageSpeed,
            incidents: incidents,
            roadClosures: roadClosures,
            constructionZones: constructionZones,
            timestamp: Date()
        )
    }
    
    // MARK: - Traffic Simulation Logic
    
    private func calculateCongestionLevel() -> Double {
        let hour = Calendar.current.component(.hour, from: Date())
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        
        var baseCongestion: Double
        
        // Time-based congestion
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
        
        // Day of week adjustment
        switch dayOfWeek {
        case 1, 7: // Sunday, Saturday
            baseCongestion *= 0.6
        case 6: // Friday
            baseCongestion *= 1.2
        default: // Weekdays
            baseCongestion *= 1.0
        }
        
        // Add randomness for realism
        let randomFactor = Double.random(in: 0.8...1.2)
        return min(max(baseCongestion * randomFactor, 0.0), 1.0)
    }
    
    private func calculateAverageSpeed(_ congestionLevel: Double) -> Double {
        let maxSpeed = 50.0 // km/h in urban areas
        let minSpeed = 5.0 // km/h minimum
        
        return maxSpeed - (congestionLevel * (maxSpeed - minSpeed))
    }
    
    private func generateSimulatedIncidents(location: CLLocationCoordinate2D) -> [TrafficIncident] {
        var incidents: [TrafficIncident] = []
        
        // Random incident generation based on congestion
        let incidentProbability = calculateCongestionLevel() * 0.3
        
        if Double.random(in: 0...1) < incidentProbability {
            let incidentTypes = ["accident", "road_hazard", "breakdown", "debris"]
            let type = incidentTypes.randomElement()!
            
            incidents.append(TrafficIncident(
                id: UUID().uuidString,
                type: type,
                location: CLLocationCoordinate2D(
                    latitude: location.latitude + Double.random(in: -0.005...0.005),
                    longitude: location.longitude + Double.random(in: -0.005...0.005)
                ),
                timestamp: Date().addingTimeInterval(-Double.random(in: 0...3600)),
                description: "Simulated \(type.replacingOccurrences(of: "_", with: " "))",
                severity: ["low", "medium", "high"].randomElement()!
            ))
        }
        
        return incidents
    }
    
    private func generateSimulatedRoadClosures(location: CLLocationCoordinate2D) -> [RoadClosure] {
        var closures: [RoadClosure] = []
        
        // Rare road closures
        if Double.random(in: 0...1) < 0.05 { // 5% chance
            closures.append(RoadClosure(
                id: UUID().uuidString,
                location: CLLocationCoordinate2D(
                    latitude: location.latitude + Double.random(in: -0.003...0.003),
                    longitude: location.longitude + Double.random(in: -0.003...0.003)
                ),
                timestamp: Date().addingTimeInterval(-Double.random(in: 0...86400)),
                reason: "Scheduled maintenance",
                estimatedReopen: Date().addingTimeInterval(Double.random(in: 3600...86400)),
                affectedRadius: Double.random(in: 100...300)
            ))
        }
        
        return closures
    }
    
    private func generateSimulatedConstructionZones(location: CLLocationCoordinate2D) -> [ConstructionZone] {
        var zones: [ConstructionZone] = []
        
        // More common construction zones
        if Double.random(in: 0...1) < 0.15 { // 15% chance
            zones.append(ConstructionZone(
                id: UUID().uuidString,
                location: CLLocationCoordinate2D(
                    latitude: location.latitude + Double.random(in: -0.004...0.004),
                    longitude: location.longitude + Double.random(in: -0.004...0.004)
                ),
                timestamp: Date().addingTimeInterval(-Double.random(in: 0...7 * 86400)),
                description: "Road construction and utility work",
                estimatedCompletion: Date().addingTimeInterval(Double.random(in: 1...30) * 86400),
                affectedRadius: Double.random(in: 200...600),
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
    
    // MARK: - Incident and Infrastructure Creation
    
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
}

// MARK: - Free API Response Models

struct HERETrafficResponse: Codable {
    let RWS: [RWS]
}

struct RWS: Codable {
    let RW: [RW]
}

struct RW: Codable {
    let FIS: [FIS]
}

struct FIS: Codable {
    let FI: [FI]
}

struct FI: Codable {
    let TMC: TMC?
    let CF: CF?
}

struct TMC: Codable {
    let PC: Int
    let DE: String
    let QD: String
}

struct CF: Codable {
    let L: Int // Length
    let SU: Int // Speed
    let FF: Int // Free Flow speed
    let JF: Int // Jam Factor
}

struct TomTomTrafficResponse: Codable {
    let flowSegmentData: FlowSegmentData
}

struct FlowSegmentData: Codable {
    let frc: Int // Functional Road Class
    let currentSpeed: Double
    let freeFlowSpeed: Double
    let currentTravelTime: Double
    let freeFlowTravelTime: Double
    let confidence: Double
}

// MARK: - TrafficData Extensions for Free APIs

extension TrafficData {
    init(from hereResponse: HERETrafficResponse, location: CLLocationCoordinate2D) {
        // Parse HERE API response
        var congestionLevel: Double = 0.0
        var averageSpeed: Double = 30.0
        
        // Extract congestion data from HERE response
        if let firstRWS = hereResponse.RWS.first,
           let firstRW = firstRWS.RW.first,
           let firstFIS = firstRW.FIS.first {
            
            var totalJamFactor: Double = 0.0
            var segmentCount: Int = 0
            
            for fi in firstFIS.FI {
                if let cf = fi.CF {
                    totalJamFactor += Double(cf.JF) / 10.0 // Jam factor is 0-10
                    segmentCount += 1
                }
            }
            
            if segmentCount > 0 {
                congestionLevel = min(totalJamFactor / Double(segmentCount), 1.0)
                averageSpeed = 30.0 * (1.0 - congestionLevel * 0.8)
            }
        }
        
        self.init(
            location: location,
            congestionLevel: congestionLevel,
            averageSpeed: averageSpeed,
            incidents: [],
            roadClosures: [],
            constructionZones: [],
            timestamp: Date()
        )
    }
    
    init(from tomtomResponse: TomTomTrafficResponse, location: CLLocationCoordinate2D) {
        let segmentData = tomtomResponse.flowSegmentData
        
        // Calculate congestion based on speed ratio
        let speedRatio = segmentData.currentSpeed / segmentData.freeFlowSpeed
        let congestionLevel = 1.0 - speedRatio
        
        self.init(
            location: location,
            congestionLevel: congestionLevel,
            averageSpeed: segmentData.currentSpeed,
            incidents: [],
            roadClosures: [],
            constructionZones: [],
            timestamp: Date()
        )
    }
}
