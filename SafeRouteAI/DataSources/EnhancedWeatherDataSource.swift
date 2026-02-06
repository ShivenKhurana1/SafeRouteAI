//
//  EnhancedWeatherDataSource.swift
//  SafeRouteAI
//
//  Enhanced weather data using OpenWeatherMap API with free tier
//  1,000 calls/day - completely free with API key
//

import Foundation
import CoreLocation

class EnhancedWeatherDataSource: DataSource {
    let name = "Enhanced Weather Data"
    let priority = 2 // Medium priority
    let refreshInterval: TimeInterval = 900 // 15 minutes
    var isEnabled = true
    
    private var lastFetch: Date?
    private var cachedData: SafetyData?
    
    // OpenWeatherMap API - FREE tier: 1,000 calls/day
    private let apiKey = "YOUR_OPENWEATHERMAP_API_KEY" // Get free key from https://openweathermap.org/api
    
    func fetchData(for location: CLLocationCoordinate2D, radius: Double) async throws -> SafetyData {
        // Check if we have fresh cached data
        if let lastFetch = lastFetch,
           Date().timeIntervalSince(lastFetch) < refreshInterval,
           let cached = cachedData {
            return cached
        }
        
        // Fetch weather data from OpenWeatherMap API
        let weatherData = try await fetchOpenWeatherMapData(for: location)
        let incidents = createWeatherIncidents(from: weatherData, location: location)
        let infrastructureIssues = createWeatherInfrastructureIssues(from: weatherData, location: location)
        
        let environmentalFactors = EnvironmentalFactors(
            weatherCondition: weatherData.condition,
            visibility: weatherData.visibility,
            temperature: weatherData.temperature,
            windSpeed: weatherData.windSpeed,
            precipitation: weatherData.precipitation,
            timeOfDay: getCurrentTimeOfDay(),
            dayOfWeek: getCurrentDayOfWeek(),
            lightingLevel: calculateLightingLevelForEnhanced(weather: weatherData, timeOfDay: getCurrentTimeOfDay())
        )
        
        let safetyData = SafetyData(
            source: name,
            timestamp: Date(),
            location: location,
            incidents: incidents,
            infrastructureIssues: infrastructureIssues,
            environmentalFactors: environmentalFactors,
            confidence: 0.95 // High confidence with OpenWeatherMap
        )
        
        self.cachedData = safetyData
        self.lastFetch = Date()
        
        return safetyData
    }
    
    func isDataFresh(for location: CLLocationCoordinate2D) -> Bool {
        guard let lastFetch = lastFetch else { return false }
        return Date().timeIntervalSince(lastFetch) < refreshInterval
    }
    
    // MARK: - OpenWeatherMap API Integration
    
    private func fetchOpenWeatherMapData(for location: CLLocationCoordinate2D) async throws -> EnhancedWeatherData {
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(location.latitude)&lon=\(location.longitude)&appid=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.apiError
        }
        
        let decoder = JSONDecoder()
        let weatherResponse = try decoder.decode(EnhancedOpenWeatherResponse.self, from: data)
        
        return EnhancedWeatherData(from: weatherResponse)
    }
    
    // MARK: - Weather Incident Creation
    
    private func createWeatherIncidents(from weatherData: EnhancedWeatherData, location: CLLocationCoordinate2D) -> [SafetyIncident] {
        var incidents: [SafetyIncident] = []
        
        // Create incidents based on weather conditions
        if weatherData.precipitation > 0.7 {
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Heavy precipitation - slippery conditions",
                radius: 500.0,
                weight: 0.6
            ))
        }
        
        if weatherData.visibility < 200 {
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .high,
                location: location,
                timestamp: Date(),
                description: "Very poor visibility conditions",
                radius: 1000.0,
                weight: 0.8
            ))
        }
        
        if weatherData.windSpeed > 50 {
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Strong winds - hazardous conditions",
                radius: 300.0,
                weight: 0.5
            ))
        }
        
        if weatherData.temperature < -10 || weatherData.temperature > 35 {
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Extreme temperature conditions",
                radius: 400.0,
                weight: 0.4
            ))
        }
        
        return incidents
    }
    
    private func createWeatherInfrastructureIssues(from weatherData: EnhancedWeatherData, location: CLLocationCoordinate2D) -> [InfrastructureIssue] {
        var issues: [InfrastructureIssue] = []
        
        // Weather-related infrastructure issues
        if weatherData.precipitation > 0.8 {
            issues.append(InfrastructureIssue(
                type: .roadSurface,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Flooding risk due to heavy precipitation",
                estimatedResolutionDate: Date().addingTimeInterval(3600),
                affectedArea: Double.pi * 600 * 600
            ))
        }
        
        if weatherData.windSpeed > 70 {
            issues.append(InfrastructureIssue(
                type: .streetLight,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Potential streetlight outages due to strong winds",
                estimatedResolutionDate: Date().addingTimeInterval(7200),
                affectedArea: Double.pi * 400 * 400
            ))
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
    
    private func calculateLightingLevel(weather: WeatherData, timeOfDay: TimeOfDay) -> Double {
        let baseLighting: Double
        
        switch timeOfDay {
        case .earlyMorning, .evening:
            baseLighting = 0.5
        case .morningRush, .midday, .afternoonRush:
            baseLighting = 1.0
        case .night:
            baseLighting = 0.2
        }
        
        // Adjust based on weather conditions
        switch weather.condition {
        case .clear:
            return baseLighting
        case .cloudy:
            return baseLighting * 0.9
        case .rainy, .snowy:
            return baseLighting * 0.7
        case .foggy:
            return baseLighting * 0.5
        case .stormy:
            return baseLighting * 0.3
        }
    }
}

// MARK: - OpenWeatherMap Data Models

struct EnhancedOpenWeatherResponse: Codable {
    let weather: [OpenWeatherWeather]
    let main: OpenWeatherMain
    let wind: OpenWeatherWind?
    let rain: OpenWeatherPrecipitation?
    let snow: OpenWeatherPrecipitation?
    let visibility: Double?
    let dt: TimeInterval
}

struct OpenWeatherWeather: Codable {
    let id: Int
    let main: String
    let description: String
    let icon: String
}

struct OpenWeatherMain: Codable {
    let temp: Double
    let feelsLike: Double
    let tempMin: Double
    let tempMax: Double
    let pressure: Double
    let humidity: Int
    
    enum CodingKeys: String, CodingKey {
        case temp
        case feelsLike = "feels_like"
        case tempMin = "temp_min"
        case tempMax = "temp_max"
        case pressure
        case humidity
    }
}

struct OpenWeatherWind: Codable {
    let speed: Double
    let deg: Double
}

struct OpenWeatherPrecipitation: Codable {
    let oneHour: Double?
    
    enum CodingKeys: String, CodingKey {
        case oneHour = "1h"
    }
}

// MARK: - Weather Data Model

struct EnhancedWeatherData {
    let temperature: Double // Celsius
    let feelsLike: Double // Celsius
    let humidity: Double // Percentage
    let pressure: Double // hPa
    let visibility: Double // Meters
    let windSpeed: Double // km/h
    let windDirection: Double // Degrees
    let precipitation: Double // 0.0-1.0 scale
    let condition: WeatherCondition
    let description: String
    let timestamp: Date
    
    init(from response: EnhancedOpenWeatherResponse) {
        self.temperature = response.main.temp
        self.feelsLike = response.main.feelsLike
        self.humidity = Double(response.main.humidity) / 100.0
        self.pressure = response.main.pressure
        self.visibility = response.visibility ?? 10000.0
        self.windSpeed = (response.wind?.speed ?? 0.0) * 3.6 // Convert m/s to km/h
        self.windDirection = response.wind?.deg ?? 0.0
        
        // Calculate precipitation from rain/snow
        var precip = 0.0
        if let rain = response.rain?.oneHour {
            precip = min(rain / 10.0, 1.0) // Convert mm to 0-1 scale
        } else if let snow = response.snow?.oneHour {
            precip = min(snow / 10.0, 1.0) // Convert mm to 0-1 scale
        }
        self.precipitation = precip
        
        // Map weather condition
        if let weather = response.weather.first {
            self.condition = WeatherCondition(from: weather.main)
            self.description = weather.description
        } else {
            self.condition = .clear
            self.description = "Clear"
        }
        
        self.timestamp = Date()
    }
}

extension EnhancedWeatherDataSource {
    private func calculateLightingLevelForEnhanced(weather: EnhancedWeatherData, timeOfDay: TimeOfDay) -> Double {
        let baseLighting: Double
        
        switch timeOfDay {
        case .earlyMorning, .night:
            baseLighting = 0.1
        case .morningRush, .evening:
            baseLighting = 0.6
        case .midday:
            baseLighting = 1.0
        case .afternoonRush:
            baseLighting = 0.8
        }
        
        // Adjust for weather conditions
        switch weather.condition {
        case .clear:
            return baseLighting
        case .cloudy:
            return baseLighting * 0.8
        case .rainy:
            return baseLighting * 0.6
        case .snowy:
            return baseLighting * 0.7
        case .foggy:
            return baseLighting * 0.5
        case .stormy:
            return baseLighting * 0.3
        }
    }
}

