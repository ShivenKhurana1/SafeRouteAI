//
//  AirQualityDataSource.swift
//  SafeRouteAI
//
//  Air quality data for health-focused routing
//  Critical for users with respiratory conditions and health-conscious routing
//

import Foundation
import CoreLocation

class AirQualityDataSource: DataSource {
    let name = "Air Quality Data"
    let priority = 2 // High priority for health routing
    let refreshInterval: TimeInterval = 1800 // 30 minutes (air quality changes slowly)
    var isEnabled = true
    
    private var lastFetch: Date?
    private var cachedData: SafetyData?
    private let apiKey = "YOUR_OPENWEATHERMAP_API_KEY" // Free tier: 1,000 calls/day
    
    func fetchData(for location: CLLocationCoordinate2D, radius: Double = 1000.0) async throws -> SafetyData {
        print("🌬️ [AirQualityDataSource] Starting data fetch for location: \(location)")
        
        // Fetch data from both APIs
        async let openWeatherTask = fetchOpenWeatherAirQuality(for: location)
        async let epaTask = fetchEPAAirQuality(for: location)
        
        let (openWeatherData, epaData) = try await (openWeatherTask, epaTask)
        
        print("🌬️ [AirQualityDataSource] Got OpenWeather data: AQI \(openWeatherData.aqi)")
        print("🌬️ [AirQualityDataSource] Got EPA data: AQI \(epaData.aqi)")
        
        // Process and combine data
        let airQualityInfo = try await createAirQualityInfo(
            openWeather: openWeatherData,
            epa: epaData,
            location: location
        )
        
        print("🌬️ [AirQualityDataSource] Combined AQI: \(airQualityInfo.combinedAQI)")
        
        // Generate safety incidents based on air quality
        let incidents = createAirQualityIncidents(from: airQualityInfo, location: location)
        let infrastructureIssues = createAirQualityInfrastructureIssues(from: airQualityInfo, location: location)
        
        print("🌬️ [AirQualityDataSource] Generated \(incidents.count) incidents, \(infrastructureIssues.count) issues")
        
        // Create infrastructure issues (air quality affects outdoor spaces)
        let environmentalFactors = EnvironmentalFactors(
            weatherCondition: .clear, // Will be updated by weather data source
            visibility: calculateVisibilityBasedOnAirQuality(airQualityInfo),
            temperature: 20.0,
            windSpeed: calculateWindSpeedImpact(airQualityInfo),
            precipitation: 0.0,
            timeOfDay: getCurrentTimeOfDay(),
            dayOfWeek: getCurrentDayOfWeek(),
            lightingLevel: calculateLightingLevel()
        )
        
        let safetyData = SafetyData(
            source: "Air Quality Data",
            timestamp: Date(),
            location: location,
            incidents: incidents,
            infrastructureIssues: infrastructureIssues,
            environmentalFactors: environmentalFactors,
            confidence: 0.88
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
    
    // MARK: - OpenWeatherMap Air Quality API
    
    private func fetchOpenWeatherAirQuality(for location: CLLocationCoordinate2D) async throws -> OpenWeatherAirQualityData {
        // OpenWeatherMap Air Pollution API - FREE tier: 1,000 calls/day
        let urlString = "https://api.openweathermap.org/data/2.5/air_pollution?lat=\(location.latitude)&lon=\(location.longitude)&appid=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw AirQualityError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw AirQualityError.apiError
            }
            
            let decoder = JSONDecoder()
            let openWeatherResponse = try decoder.decode(OpenWeatherAirQualityResponse.self, from: data)
            
            return OpenWeatherAirQualityData(
                location: location,
                aqi: openWeatherResponse.list.first?.main.aqi ?? 1,
                pollutants: openWeatherResponse.list.first?.components ?? PollutantComponents(),
                timestamp: Date()
            )
        } catch {
            // Fallback to simulated data
            return simulateOpenWeatherAirQuality(location: location)
        }
    }
    
    // MARK: - EPA Air Quality API
    
    private func fetchEPAAirQuality(for location: CLLocationCoordinate2D) async throws -> EPAAirQualityData {
        // EPA AirNow API - FREE tier: 500 calls/hour
        let urlString = "https://www.airnowapi.org/aq/observation/zipCode/current/?format=application/json&zipCode=10001&distance=25&API_KEY=YOUR_EPA_API_KEY"
        
        guard let url = URL(string: urlString) else {
            throw AirQualityError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw AirQualityError.apiError
            }
            
            let decoder = JSONDecoder()
            let epaResponse = try decoder.decode([EPAAirQualityResponse].self, from: data)
            
            guard let epaData = epaResponse.first else {
                throw AirQualityError.noData
            }
            
            return EPAAirQualityData(
                location: location,
                aqi: epaData.aqi,
                category: epaData.airQualityCategory,
                parameter: epaData.parameter,
                timestamp: Date()
            )
        } catch {
            // Fallback to simulated data
            return simulateEPAAirQuality(location: location)
        }
    }
    
    // MARK: - Data Processing
    
    private func createAirQualityInfo(
        openWeather: OpenWeatherAirQualityData,
        epa: EPAAirQualityData,
        location: CLLocationCoordinate2D
    ) async throws -> AirQualityInfo {
        // Combine data from both sources
        let combinedAQI = calculateCombinedAQI(openWeather: openWeather, epa: epa)
        let healthRisk = calculateHealthRisk(combinedAQI: combinedAQI, pollutants: openWeather.pollutants)
        let recommendations = generateHealthRecommendations(aqi: combinedAQI, healthRisk: healthRisk)
        
        return AirQualityInfo(
            location: location,
            openWeatherAQI: openWeather.aqi,
            epaAQI: epa.aqi,
            combinedAQI: combinedAQI,
            category: AirQualityCategory.fromAQI(combinedAQI),
            pollutants: openWeather.pollutants,
            healthRisk: healthRisk,
            recommendations: recommendations,
            timestamp: Date()
        )
    }
    
    private func createAirQualityIncidents(from airQualityInfo: AirQualityInfo, location: CLLocationCoordinate2D) -> [SafetyIncident] {
        var incidents: [SafetyIncident] = []
        
        // Poor air quality incidents
        if airQualityInfo.combinedAQI > 100 { // Unhealthy for sensitive groups
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Poor air quality - caution for sensitive groups",
                radius: 1000.0,
                weight: 0.6
            ))
        }
        
        if airQualityInfo.combinedAQI > 150 { // Unhealthy
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .high,
                location: location,
                timestamp: Date(),
                description: "Unhealthy air quality - avoid prolonged outdoor activity",
                radius: 1500.0,
                weight: 0.8
            ))
        }
        
        if airQualityInfo.combinedAQI > 200 { // Very unhealthy
            incidents.append(SafetyIncident(
                type: .emergency,
                severity: .high,
                location: location,
                timestamp: Date(),
                description: "Very unhealthy air quality - avoid outdoor activity",
                radius: 2000.0,
                weight: 0.9
            ))
        }
        
        // High pollutant incidents
        if airQualityInfo.pollutants.pm2_5 > 35.0 {
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "High PM2.5 levels - respiratory health concern",
                radius: 800.0,
                weight: 0.7
            ))
        }
        
        if airQualityInfo.pollutants.o3 > 70.0 {
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "High ozone levels - respiratory irritant",
                radius: 800.0,
                weight: 0.7
            ))
        }
        
        return incidents
    }
    
    private func createAirQualityInfrastructureIssues(from airQualityInfo: AirQualityInfo, location: CLLocationCoordinate2D) -> [InfrastructureIssue] {
        var issues: [InfrastructureIssue] = []
        
        // Poor air quality affects outdoor spaces
        if airQualityInfo.combinedAQI > 100 {
            issues.append(InfrastructureIssue(
                type: .crosswalk, // Outdoor walking areas
                severity: .low,
                location: location,
                timestamp: Date(),
                description: "Reduced air quality affecting outdoor areas",
                estimatedResolutionDate: nil, // Natural condition
                affectedArea: Double.pi * 1000 * 1000 // 1km radius
            ))
        }
        
        return issues
    }
    
    // MARK: - Helper Functions
    
    private func calculateCombinedAQI(openWeather: OpenWeatherAirQualityData, epa: EPAAirQualityData) -> Int {
        // Weighted average - prioritize EPA for US locations
        let openWeatherWeight = 0.3
        let epaWeight = 0.7
        
        return Int((Double(openWeather.aqi) * openWeatherWeight) + (Double(epa.aqi) * epaWeight))
    }
    
    private func calculateHealthRisk(combinedAQI: Int, pollutants: PollutantComponents) -> HealthRisk {
        if combinedAQI <= 50 {
            return .low
        } else if combinedAQI <= 100 {
            return .moderate
        } else if combinedAQI <= 150 {
            return .high
        } else if combinedAQI <= 200 {
            return .veryHigh
        } else {
            return .extreme
        }
    }
    
    private func generateHealthRecommendations(aqi: Int, healthRisk: HealthRisk) -> [HealthRecommendation] {
        var recommendations: [HealthRecommendation] = []
        
        switch healthRisk {
        case .low:
            recommendations.append(HealthRecommendation(
                category: "General",
                message: "Air quality is good for outdoor activities",
                priority: .low
            ))
            
        case .moderate:
            recommendations.append(HealthRecommendation(
                category: "Sensitive Groups",
                message: "Unusually sensitive people should consider reducing prolonged outdoor exertion",
                priority: .medium
            ))
            
        case .high:
            recommendations.append(HealthRecommendation(
                category: "Sensitive Groups",
                message: "Children, elderly, and people with respiratory conditions should avoid prolonged outdoor exertion",
                priority: .high
            ))
            recommendations.append(HealthRecommendation(
                category: "General",
                message: "Consider reducing prolonged outdoor exertion",
                priority: .medium
            ))
            
        case .veryHigh:
            recommendations.append(HealthRecommendation(
                category: "Everyone",
                message: "Avoid prolonged outdoor exertion",
                priority: .high
            ))
            recommendations.append(HealthRecommendation(
                category: "Sensitive Groups",
                message: "Children, elderly, and people with respiratory conditions should remain indoors",
                priority: .critical
            ))
            
        case .extreme:
            recommendations.append(HealthRecommendation(
                category: "Everyone",
                message: "Avoid all outdoor exertion",
                priority: .critical
            ))
            recommendations.append(HealthRecommendation(
                category: "Sensitive Groups",
                message: "Remain indoors and keep windows closed",
                priority: .critical
            ))
        }
        
        return recommendations
    }
    
    private func calculateVisibilityBasedOnAirQuality(_ airQualityInfo: AirQualityInfo) -> Double {
        // Air pollution reduces visibility
        let baseVisibility = 1000.0
        let aqi = airQualityInfo.combinedAQI
        
        if aqi <= 50 {
            return baseVisibility
        } else if aqi <= 100 {
            return baseVisibility * 0.8
        } else if aqi <= 150 {
            return baseVisibility * 0.6
        } else if aqi <= 200 {
            return baseVisibility * 0.4
        } else {
            return baseVisibility * 0.2
        }
    }
    
    private func calculateWindSpeedImpact(_ airQualityInfo: AirQualityInfo) -> Double {
        // Wind helps disperse pollutants, but high winds can stir up particulates
        let baseWindSpeed = 10.0
        let aqi = airQualityInfo.combinedAQI
        
        if aqi <= 100 {
            return baseWindSpeed
        } else {
            // High pollution areas often have stagnant air
            return baseWindSpeed * 0.7
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
    
    private func simulateOpenWeatherAirQuality(location: CLLocationCoordinate2D) -> OpenWeatherAirQualityData {
        let aqi = Int.random(in: 1...100)
        return OpenWeatherAirQualityData(
            location: location,
            aqi: aqi,
            pollutants: PollutantComponents(
                co: Double.random(in: 0...1000),
                no: Double.random(in: 0...200),
                no2: Double.random(in: 0...200),
                o3: Double.random(in: 0...200),
                so2: Double.random(in: 0...100),
                pm2_5: Double.random(in: 0...100),
                pm10: Double.random(in: 0...100),
                nh3: Double.random(in: 0...100)
            ),
            timestamp: Date()
        )
    }
    
    private func simulateEPAAirQuality(location: CLLocationCoordinate2D) -> EPAAirQualityData {
        let aqi = Int.random(in: 1...150)
        return EPAAirQualityData(
            location: location,
            aqi: aqi,
            category: AirQualityCategory.fromAQI(aqi),
            parameter: "PM2.5",
            timestamp: Date()
        )
    }
}

// MARK: - Data Models

struct AirQualityInfo {
    let location: CLLocationCoordinate2D
    let openWeatherAQI: Int
    let epaAQI: Int
    let combinedAQI: Int
    let category: AirQualityCategory
    let pollutants: PollutantComponents
    let healthRisk: HealthRisk
    let recommendations: [HealthRecommendation]
    let timestamp: Date
}

struct OpenWeatherAirQualityData {
    let location: CLLocationCoordinate2D
    let aqi: Int
    let pollutants: PollutantComponents
    let timestamp: Date
}

struct EPAAirQualityData {
    let location: CLLocationCoordinate2D
    let aqi: Int
    let category: AirQualityCategory
    let parameter: String
    let timestamp: Date
}

struct PollutantComponents: Codable {
    let co: Double
    let no: Double
    let no2: Double
    let o3: Double
    let so2: Double
    let pm2_5: Double
    let pm10: Double
    let nh3: Double
    
    init(co: Double = 0, no: Double = 0, no2: Double = 0, o3: Double = 0, so2: Double = 0, pm2_5: Double = 0, pm10: Double = 0, nh3: Double = 0) {
        self.co = co
        self.no = no
        self.no2 = no2
        self.o3 = o3
        self.so2 = so2
        self.pm2_5 = pm2_5
        self.pm10 = pm10
        self.nh3 = nh3
    }
}

struct HealthRecommendation {
    let category: String
    let message: String
    let priority: AirQualityRecommendationPriority
}

enum HealthRisk: String, CaseIterable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case veryHigh = "Very High"
    case extreme = "Extreme"
}

enum AirQualityCategory: String, CaseIterable {
    case good = "Good"
    case moderate = "Moderate"
    case unhealthyForSensitiveGroups = "Unhealthy for Sensitive Groups"
    case unhealthy = "Unhealthy"
    case veryUnhealthy = "Very Unhealthy"
    case hazardous = "Hazardous"
    
    static func fromAQI(_ aqi: Int) -> AirQualityCategory {
        switch aqi {
        case 0...50: return .good
        case 51...100: return .moderate
        case 101...150: return .unhealthyForSensitiveGroups
        case 151...200: return .unhealthy
        case 201...300: return .veryUnhealthy
        default: return .hazardous
        }
    }
    
    var color: String {
        switch self {
        case .good: return "#00E400"
        case .moderate: return "#FFFF00"
        case .unhealthyForSensitiveGroups: return "#FF7E00"
        case .unhealthy: return "#FF0000"
        case .veryUnhealthy: return "#8F3F97"
        case .hazardous: return "#7E0023"
        }
    }
}

enum AirQualityRecommendationPriority: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

// MARK: - API Response Models

struct OpenWeatherAirQualityResponse: Codable {
    let coord: [Double]
    let list: [OpenWeatherAirQualityDataPoint]
}

struct OpenWeatherAirQualityDataPoint: Codable {
    let main: OpenWeatherMainData
    let components: PollutantComponents
    let dt: TimeInterval
}

struct OpenWeatherMainData: Codable {
    let aqi: Int
}

struct EPAAirQualityResponse: Codable {
    let dateObserved: String
    let hourObserved: Int
    let localTimeZone: String
    let reportingArea: String
    let stateCode: String
    let latitude: Double
    let longitude: Double
    let parameterName: String
    let aqi: Int
    let category: String // Changed from enum to string
    
    enum CodingKeys: String, CodingKey {
        case dateObserved = "DateObserved"
        case hourObserved = "HourObserved"
        case localTimeZone = "LocalTimeZone"
        case reportingArea = "ReportingArea"
        case stateCode = "StateCode"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case parameterName = "ParameterName"
        case aqi = "AQI"
        case category = "Category"
    }
    
    var parameter: String {
        return parameterName
    }
    
    var airQualityCategory: AirQualityCategory {
        return AirQualityCategory.fromAQI(aqi)
    }
}

// MARK: - Error Types

enum AirQualityError: Error {
    case invalidURL
    case apiError
    case decodingError
    case noData
}
