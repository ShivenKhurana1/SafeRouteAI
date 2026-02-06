//
//  EnhancedCrimeDataSource.swift
//  SafeRouteAI
//
//  Enhanced crime data using CrimeReports.com API with free tier
//  1,000 calls/day - completely free with API key
//

import Foundation
import CoreLocation

class EnhancedCrimeDataSource: DataSource {
    let name = "Enhanced Crime Data"
    let priority = 4 // High priority for safety
    let refreshInterval: TimeInterval = 1800 // 30 minutes
    var isEnabled = true
    
    private var lastFetch: Date?
    private var cachedData: SafetyData?
    
    // CrimeReports.com API - FREE tier: 1,000 calls/day
    private let apiKey = "YOUR_CRIMEREPORTS_API_KEY" // Get free key from https://www.crimereports.com/
    
    func fetchData(for location: CLLocationCoordinate2D, radius: Double) async throws -> SafetyData {
        // Check if we have fresh cached data
        if let lastFetch = lastFetch,
           Date().timeIntervalSince(lastFetch) < refreshInterval,
           let cached = cachedData {
            return cached
        }
        
        // Fetch crime data from CrimeReports API
        let crimeResponse = try await fetchEnhancedCrimeReportsData(for: location, radius: radius)
        let incidents = createCrimeIncidents(from: crimeResponse, location: location)
        let infrastructureIssues: [InfrastructureIssue] = []
        
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
            confidence: 0.92 // High confidence with CrimeReports
        )
        
        self.cachedData = safetyData
        self.lastFetch = Date()
        
        return safetyData
    }
    
    func isDataFresh(for location: CLLocationCoordinate2D) -> Bool {
        guard let lastFetch = lastFetch else { return false }
        return Date().timeIntervalSince(lastFetch) < refreshInterval
    }
    
    // MARK: - CrimeReports API Integration
    
    private func fetchEnhancedCrimeReportsData(for location: CLLocationCoordinate2D, radius: Double) async throws -> EnhancedCrimeReportsResponse {
        // CrimeReports.com API - FREE tier: 1,000 calls/day
        let urlString = "https://api.crimereports.com/v1/incidents?lat=\(location.latitude)&lon=\(location.longitude)&radius=\(radius)&limit=50&api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw CrimeError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CrimeError.apiError
        }
        
        let decoder = JSONDecoder()
        let crimeResponse = try decoder.decode(EnhancedCrimeReportsResponse.self, from: data)
        
        return crimeResponse
    }
    
    // MARK: - Crime Incident Creation
    
    private func createCrimeIncidents(from crimeData: EnhancedCrimeReportsResponse, location: CLLocationCoordinate2D) -> [SafetyIncident] {
        var incidents: [SafetyIncident] = []
        
        for crimeIncident in crimeData.incidents {
            let incidentType: IncidentType = .crime
            let severity: IncidentSeverity = mapSeverity(crimeIncident.type)
            
            let incidentLocation = CLLocationCoordinate2D(
                latitude: crimeIncident.latitude,
                longitude: crimeIncident.longitude
            )
            
            let impactRadius = calculateImpactRadius(crimeIncident.type)
            let weight = calculateWeight(crimeIncident.type)
            
            incidents.append(SafetyIncident(
                type: incidentType,
                severity: severity,
                location: incidentLocation,
                timestamp: crimeIncident.date,
                description: crimeIncident.description,
                radius: impactRadius,
                weight: weight
            ))
        }
        
        return incidents
    }
    
    private func mapSeverity(_ crimeType: String) -> IncidentSeverity {
        switch crimeType.lowercased() {
        case "homicide", "murder", "manslaughter":
            return .critical
        case "assault", "robbery", "rape", "sexual_assault":
            return .high
        case "burglary", "arson", "weapon_law_violation":
            return .medium
        case "theft", "larceny", "vandalism", "fraud":
            return .low
        case "drug_offense", "dui", "public_disorder":
            return .low
        default:
            return .medium
        }
    }
    
    private func calculateImpactRadius(_ crimeType: String) -> Double {
        switch crimeType.lowercased() {
        case "homicide", "murder", "assault", "robbery", "rape":
            return 400.0
        case "burglary", "arson", "weapon_law_violation":
            return 300.0
        case "theft", "larceny", "vandalism", "fraud":
            return 200.0
        case "drug_offense", "dui", "public_disorder":
            return 150.0
        default:
            return 250.0
        }
    }
    
    private func calculateWeight(_ crimeType: String) -> Double {
        switch crimeType.lowercased() {
        case "homicide", "murder", "assault", "robbery", "rape":
            return 0.9
        case "burglary", "arson", "weapon_law_violation":
            return 0.7
        case "theft", "larceny", "vandalism", "fraud":
            return 0.5
        case "drug_offense", "dui", "public_disorder":
            return 0.4
        default:
            return 0.6
        }
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

// MARK: - CrimeReports Data Models

struct EnhancedCrimeReportsResponse: Codable {
    let incidents: [EnhancedCrimeReportsIncident]
    let total: Int
    let page: Int
    let pageSize: Int
}

struct EnhancedCrimeReportsIncident: Codable {
    let id: String
    let type: String
    let description: String
    let date: Date
    let latitude: Double
    let longitude: Double
    let location: String?
    let agency: String?
    let severity: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, type, description, date, latitude, longitude, location, agency, severity
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.description = try container.decode(String.self, forKey: .description)
        self.latitude = try container.decode(Double.self, forKey: .latitude)
        self.longitude = try container.decode(Double.self, forKey: .longitude)
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.agency = try container.decodeIfPresent(String.self, forKey: .agency)
        self.severity = try container.decodeIfPresent(String.self, forKey: .severity)
        
        // Handle date parsing
        if let dateString = try? container.decode(String.self, forKey: .date) {
            let formatter = ISO8601DateFormatter()
            self.date = formatter.date(from: dateString) ?? Date()
        } else {
            self.date = Date()
        }
    }
}

struct EnhancedCrimeReportsData {
    let location: CLLocationCoordinate2D
    let incidents: [EnhancedCrimeReportsIncident]
    let timestamp: Date
    
    var recentIncidents: [EnhancedCrimeReportsIncident] {
        let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 3600)
        return incidents.filter { $0.date >= twentyFourHoursAgo }
    }
    
    var highSeverityIncidents: [EnhancedCrimeReportsIncident] {
        return incidents.filter { incident in
            ["homicide", "murder", "assault", "robbery", "rape", "arson"].contains(incident.type.lowercased())
        }
    }
    
    var incidentCountByType: [String: Int] {
        return incidents.reduce(into: [:]) { counts, incident in
            counts[incident.type, default: 0] += 1
        }
    }
}

enum CrimeError: Error {
    case invalidURL
    case apiError
    case decodingError
    case noData
    case rateLimitExceeded
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid crime API URL"
        case .apiError:
            return "Crime API request failed"
        case .decodingError:
            return "Failed to decode crime data"
        case .noData:
            return "No crime data available"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        }
    }
}
