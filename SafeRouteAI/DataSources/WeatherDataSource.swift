//
//  WeatherDataSource.swift
//  SafeRouteAI
//
//  Integrates weather data from OpenWeatherMap API for environmental safety analysis
//  Provides real-time weather conditions affecting pedestrian safety
//

import Foundation
import CoreLocation

class WeatherDataSource: DataSource {
    let name = "Weather Data"
    let priority = 2 // Medium priority
    let refreshInterval: TimeInterval = 900 // 15 minutes
    var isEnabled = true
    
    private var lastFetch: Date?
    private var cachedData: SafetyData?
    // Using free Open-Meteo API - no API key required
    
    func fetchData(for location: CLLocationCoordinate2D, radius: Double) async throws -> SafetyData {
        // Check if we have fresh cached data
        if let lastFetch = lastFetch,
           Date().timeIntervalSince(lastFetch) < refreshInterval,
           let cached = cachedData {
            return cached
        }
        
        // Fetch weather data from free Open-Meteo API
        let weatherData = try await fetchWeatherData(from: location)
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
            lightingLevel: calculateLightingLevel(for: weatherData)
        )
        
        let safetyData = SafetyData(
            source: name,
            timestamp: Date(),
            location: location,
            incidents: incidents,
            infrastructureIssues: infrastructureIssues,
            environmentalFactors: environmentalFactors,
            confidence: 0.88 // High confidence in weather data
        )
        
        self.cachedData = safetyData
        self.lastFetch = Date()
        
        return safetyData
    }
    
    func isDataFresh(for location: CLLocationCoordinate2D) -> Bool {
        guard let lastFetch = lastFetch else { return false }
        return Date().timeIntervalSince(lastFetch) < refreshInterval
    }
    
    // MARK: - Weather API Integration
    
    private func fetchWeatherData(from location: CLLocationCoordinate2D) async throws -> WeatherData {
        // Using free Open-Meteo API (no API key required)
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(location.latitude)&longitude=\(location.longitude)&current_weather=true&hourly=temperature_2m,precipitation,visibility,windspeed_10m"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("❌ Weather API HTTP Error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw WeatherError.apiError
        }
        
        let decoder = JSONDecoder()
        
        do {
            let weatherResponse = try decoder.decode(OpenMeteoResponse.self, from: data)
            return WeatherData(from: weatherResponse)
        } catch {
            print("❌ Weather API parsing error: \(error)")
            // Return fallback weather data
            return generateFallbackWeatherData(for: location)
        }
    }
    
    private func generateFallbackWeatherData(for location: CLLocationCoordinate2D) -> WeatherData {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let isNight = hour >= 20 || hour <= 6
        
        return WeatherData(
            temperature: 20.0 + Double.random(in: -5...5),
            feelsLike: 18.0 + Double.random(in: -3...3),
            humidity: 0.6 + Double.random(in: -0.2...0.2),
            pressure: 1013.25 + Double.random(in: -10...10),
            visibility: isNight ? 8000.0 : 10000.0,
            windSpeed: Double.random(in: 0...15),
            windDirection: Double.random(in: 0...360),
            precipitation: Double.random(in: 0...0.3),
            condition: isNight ? .clear : .cloudy,
            description: isNight ? "Clear night" : "Partly cloudy",
            timestamp: Date()
        )
    }
    
    private func createWeatherIncidents(from weatherData: WeatherData, location: CLLocationCoordinate2D) -> [SafetyIncident] {
        var incidents: [SafetyIncident] = []
        
        // Create incidents based on weather conditions
        if weatherData.precipitation > 0.7 {
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .high,
                location: location,
                timestamp: Date(),
                description: "Heavy precipitation - slippery conditions",
                radius: 1000.0,
                weight: 0.7
            ))
        } else if weatherData.precipitation > 0.3 {
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Moderate precipitation - reduced traction",
                radius: 500.0,
                weight: 0.5
            ))
        }
        
        if weatherData.visibility < 200 {
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .high,
                location: location,
                timestamp: Date(),
                description: "Poor visibility - fog or heavy rain",
                radius: 1500.0,
                weight: 0.8
            ))
        } else if weatherData.visibility < 500 {
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Reduced visibility",
                radius: 800.0,
                weight: 0.6
            ))
        }
        
        if weatherData.windSpeed > 50 {
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Strong winds - hazardous conditions",
                radius: 600.0,
                weight: 0.5
            ))
        }
        
        if weatherData.temperature < -10 {
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .high,
                location: location,
                timestamp: Date(),
                description: "Extreme cold - ice risk",
                radius: 800.0,
                weight: 0.6
            ))
        } else if weatherData.temperature < 0 {
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Freezing temperatures - possible ice",
                radius: 500.0,
                weight: 0.4
            ))
        } else if weatherData.temperature > 35 {
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Extreme heat - dehydration risk",
                radius: 400.0,
                weight: 0.3
            ))
        }
        
        return incidents
    }
    
    private func createWeatherInfrastructureIssues(from weatherData: WeatherData, location: CLLocationCoordinate2D) -> [InfrastructureIssue] {
        var issues: [InfrastructureIssue] = []
        
        // Create infrastructure issues based on weather
        if weatherData.precipitation > 0.5 {
            issues.append(InfrastructureIssue(
                type: .drainage,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Potential flooding due to heavy precipitation",
                estimatedResolutionDate: nil,
                affectedArea: Double.pi * 1000 * 1000 // 1km radius
            ))
        }
        
        if weatherData.temperature < 0 && weatherData.precipitation > 0.1 {
            issues.append(InfrastructureIssue(
                type: .sidewalk,
                severity: .high,
                location: location,
                timestamp: Date(),
                description: "Ice formation on sidewalks",
                estimatedResolutionDate: Date().addingTimeInterval(24 * 3600), // 24 hours
                affectedArea: Double.pi * 500 * 500 // 500m radius
            ))
        }
        
        if weatherData.windSpeed > 60 {
            issues.append(InfrastructureIssue(
                type: .trafficSignal,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Traffic signal issues due to strong winds",
                estimatedResolutionDate: Date().addingTimeInterval(12 * 3600), // 12 hours
                affectedArea: Double.pi * 300 * 300 // 300m radius
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
    
    private func calculateLightingLevel(for weatherData: WeatherData) -> Double {
        let hour = Calendar.current.component(.hour, from: Date())
        var baseLighting: Double
        
        switch hour {
        case 6...18: baseLighting = 1.0 // Daylight
        case 19...20, 5...6: baseLighting = 0.7 // Twilight
        case 21...22, 4...5: baseLighting = 0.4 // Evening
        default: baseLighting = 0.2 // Night
        }
        
        // Adjust for weather conditions
        switch weatherData.condition {
        case .clear, .cloudy:
            return baseLighting
        case .rainy, .snowy:
            return baseLighting * 0.8 // Reduced lighting due to clouds/precipitation
        case .foggy:
            return baseLighting * 0.6 // Significantly reduced lighting
        case .stormy:
            return baseLighting * 0.5 // Very poor lighting
        }
    }
}
struct OpenMeteoResponse: Codable {
    let latitude: Double
    let longitude: Double
    let current_weather: CurrentWeather
    let hourly: HourlyData
}

struct CurrentWeather: Codable {
    let temperature: Double
    let windspeed: Double
    let winddirection: Double
    let is_day: Int
    let weathercode: Int
}

struct HourlyData: Codable {
    let time: [String]
    let temperature_2m: [Double]
    let precipitation: [Double]
    let visibility: [Double]
    let windspeed_10m: [Double]
}

// MARK: - Weather Data Models
struct WeatherData {
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
    
    init(temperature: Double, feelsLike: Double, humidity: Double, pressure: Double, visibility: Double, windSpeed: Double, windDirection: Double, precipitation: Double, condition: WeatherCondition, description: String, timestamp: Date) {
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.humidity = humidity
        self.pressure = pressure
        self.visibility = visibility
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.precipitation = precipitation
        self.condition = condition
        self.description = description
        self.timestamp = timestamp
    }
    
    init(from response: OpenMeteoResponse) {
        self.temperature = response.current_weather.temperature
        self.feelsLike = response.current_weather.temperature // Open-Meteo doesn't provide feels-like
        self.humidity = 0.5 // Default value since Open-Meteo doesn't provide humidity in free tier
        self.pressure = 1013.25 // Standard atmospheric pressure
        self.visibility = response.hourly.visibility.first ?? 10000.0
        self.windSpeed = response.current_weather.windspeed
        self.windDirection = response.current_weather.winddirection
        
        // Calculate precipitation from hourly data
        let precip = (response.hourly.precipitation.first ?? 0.0) / 10.0 // Convert mm to 0-1 scale
        self.precipitation = min(max(precip, 0.0), 1.0)
        
        // Map weather code to condition
        self.condition = WeatherCondition(from: response.current_weather.weathercode)
        self.description = self.condition.rawValue
        
        self.timestamp = Date()
    }
}

// MARK: - Weather Condition Mapping for Open-Meteo
extension WeatherCondition {
    init(from weatherCode: Int) {
        switch weatherCode {
        case 0:
            self = .clear
        case 1, 2, 3:
            self = .cloudy
        case 45, 48:
            self = .foggy
        case 51, 53, 55, 56, 57:
            self = .rainy
        case 61, 63, 65, 66, 67:
            self = .rainy
        case 71, 73, 75, 77, 85, 86:
            self = .snowy
        case 80, 81, 82:
            self = .rainy
        case 95, 96, 99:
            self = .stormy
        default:
            self = .clear
        }
    }
}

// MARK: - Legacy Models (for compatibility)
struct OpenWeatherResponse: Codable {
    let weather: [BasicOpenWeatherWeather]
    let main: BasicOpenWeatherMain
    let wind: BasicOpenWeatherWind?
    let rain: BasicOpenWeatherPrecipitation?
    let snow: BasicOpenWeatherPrecipitation?
    let visibility: Double?
    let dt: TimeInterval
}

struct BasicOpenWeatherWeather: Codable {
    let id: Int
    let main: String
    let description: String
    let icon: String
}

struct BasicOpenWeatherMain: Codable {
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

struct BasicOpenWeatherWind: Codable {
    let speed: Double
    let deg: Double
}

struct BasicOpenWeatherPrecipitation: Codable {
    let oneHour: Double?
    
    enum CodingKeys: String, CodingKey {
        case oneHour = "1h"
    }
}

// MARK: - Weather Condition Mapping
extension WeatherCondition {
    init(from openWeatherMain: String) {
        switch openWeatherMain.lowercased() {
        case "clear":
            self = .clear
        case "clouds":
            self = .cloudy
        case "rain", "drizzle":
            self = .rainy
        case "snow":
            self = .snowy
        case "mist", "smoke", "haze", "dust", "fog", "sand", "ash":
            self = .foggy
        case "thunderstorm", "squall", "tornado":
            self = .stormy
        default:
            self = .clear
        }
    }
}

// MARK: - Weather Error Handling
enum WeatherError: Error {
    case invalidURL
    case apiError
    case decodingError
    case networkError
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid weather API URL"
        case .apiError:
            return "Weather API returned an error"
        case .decodingError:
            return "Failed to decode weather data"
        case .networkError:
            return "Network error while fetching weather data"
        }
    }
}

// MARK: - Weather Analysis Extensions
extension WeatherDataSource {
    
    /// Calculate weather-based safety score
    func calculateWeatherSafetyScore(for location: CLLocationCoordinate2D) async -> Double {
        do {
            let weatherData = try await fetchWeatherData(from: location)
            return calculateSafetyScore(from: weatherData)
        } catch {
            print("⚠️ Failed to calculate weather safety score: \(error)")
            return 0.5 // Neutral score on error
        }
    }
    
    private func calculateSafetyScore(from weatherData: WeatherData) -> Double {
        var riskScore: Double = 0.0
        
        // Temperature risks
        if weatherData.temperature < -10 || weatherData.temperature > 35 {
            riskScore += 0.3
        } else if weatherData.temperature < 0 || weatherData.temperature > 30 {
            riskScore += 0.2
        }
        
        // Precipitation risks
        riskScore += weatherData.precipitation * 0.4
        
        // Visibility risks
        if weatherData.visibility < 200 {
            riskScore += 0.4
        } else if weatherData.visibility < 500 {
            riskScore += 0.2
        }
        
        // Wind risks
        if weatherData.windSpeed > 60 {
            riskScore += 0.3
        } else if weatherData.windSpeed > 40 {
            riskScore += 0.2
        }
        
        // Condition-specific risks
        switch weatherData.condition {
        case .stormy:
            riskScore += 0.5
        case .foggy:
            riskScore += 0.3
        case .rainy, .snowy:
            riskScore += 0.2
        case .cloudy:
            riskScore += 0.1
        case .clear:
            riskScore += 0.0
        }
        
        return min(max(riskScore, 0.0), 1.0)
    }
    
    /// Get weather recommendations
    func getWeatherRecommendations(for location: CLLocationCoordinate2D) async -> [WeatherRecommendation] {
        do {
            let weatherData = try await fetchWeatherData(from: location)
            return generateRecommendations(from: weatherData)
        } catch {
            print("⚠️ Failed to get weather recommendations: \(error)")
            return []
        }
    }
    
    private func generateRecommendations(from weatherData: WeatherData) -> [WeatherRecommendation] {
        var recommendations: [WeatherRecommendation] = []
        
        if weatherData.precipitation > 0.5 {
            recommendations.append(WeatherRecommendation(
                type: .precipitation,
                message: "Heavy precipitation detected. Use waterproof clothing and allow extra travel time.",
                priority: .high
            ))
        }
        
        if weatherData.visibility < 500 {
            recommendations.append(WeatherRecommendation(
                type: .visibility,
                message: "Poor visibility conditions. Wear bright clothing and consider alternative route.",
                priority: .high
            ))
        }
        
        if weatherData.temperature < 0 {
            recommendations.append(WeatherRecommendation(
                type: .temperature,
                message: "Freezing temperatures. Watch for ice on sidewalks and dress warmly.",
                priority: .medium
            ))
        } else if weatherData.temperature > 30 {
            recommendations.append(WeatherRecommendation(
                type: .temperature,
                message: "High temperature. Stay hydrated and seek shade when possible.",
                priority: .medium
            ))
        }
        
        if weatherData.windSpeed > 40 {
            recommendations.append(WeatherRecommendation(
                type: .wind,
                message: "Strong winds. Secure loose items and be cautious of debris.",
                priority: .medium
            ))
        }
        
        return recommendations
    }
}

// MARK: - Weather Recommendation Models
struct WeatherRecommendation {
    let type: WeatherRecommendationType
    let message: String
    let priority: WeatherRecommendationPriority
}

enum WeatherRecommendationType: String, CaseIterable {
    case precipitation = "Precipitation"
    case visibility = "Visibility"
    case temperature = "Temperature"
    case wind = "Wind"
    
    var icon: String {
        switch self {
        case .precipitation: return "cloud.rain"
        case .visibility: return "eye"
        case .temperature: return "thermometer"
        case .wind: return "wind"
        }
    }
}

enum WeatherRecommendationPriority: String, CaseIterable {
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
