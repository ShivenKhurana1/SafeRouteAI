//
//  APIKeys.swift
//  SafeRouteAI
//
//  Configuration for free API services
//

import Foundation

/// Configuration for free API services used in SafeRouteAI
struct APIKeys {
    
    // MARK: - Traffic Data APIs
    
    /// TomTom Traffic API (Free Tier: 2,500 calls/day)
    /// Get your free key at: https://developer.tomtom.com/
    static let tomTomAPIKey = "YOUR_TOMTOM_API_KEY"
    
    // MARK: - Alternative Traffic APIs
    
    /// Mapbox Traffic API (Free Tier: 50,000 requests/month)
    /// Get your free key at: https://mapbox.com/
    static let mapboxAPIKey = "YOUR_MAPBOX_API_KEY"
    
    /// HERE Traffic API (Free Tier: 250,000 transactions/month)
    /// Get your free key at: https://developer.here.com/
    static let hereAPIKey = "YOUR_HERE_API_KEY"
    
    // MARK: - Crime Data APIs
    
    /// CrimeReports.com API (Free Tier: 1,000 calls/day)
    /// Get your free key at: https://crimereports.com/api
    static let crimeReportsAPIKey = "YOUR_CRIMEREPORTS_API_KEY"
    
    // MARK: - Weather Data APIs
    
    /// Open-Meteo API (Completely FREE - no key needed)
    /// Documentation: https://open-meteo.com/
    static let openMeteoBaseURL = "https://api.open-meteo.com/v1/forecast"
    
    /// OpenWeatherMap API (Free Tier: 1,000 calls/day)
    /// Get your free key at: https://openweathermap.org/api
    static let openWeatherMapAPIKey = "YOUR_OPENWEATHERMAP_API_KEY"
    
    // MARK: - FBI Crime Data (Completely FREE - no key needed)
    
    /// FBI Crime Data API (Completely FREE)
    /// Documentation: https://www.fbi.gov/how-we-can-help-you/more-fbi-services-and-information/ways-to-report-a-crime/crime-data-api
    static let fbiBaseURL = "https://api.fbi.gov/v1/crime"
    
    // MARK: - Data.gov APIs (Completely FREE - no key needed)
    
    /// Data.gov Crime Statistics (Completely FREE)
    /// Documentation: https://catalog.data.gov/dataset
    static let dataGovBaseURL = "https://catalog.data.gov/api/3"
}

// MARK: - API Configuration

struct APIConfiguration {
    
    /// Current active traffic API provider
    static var trafficProvider: TrafficProvider = .tomTom
    
    /// Current active weather API provider
    static var weatherProvider: WeatherProvider = .openMeteo
    
    /// Current active crime data provider
    static var crimeDataProvider: CrimeDataProvider = .crimeReports
}

// MARK: - Provider Enums

enum TrafficProvider {
    case tomTom
    case mapbox
    case here
    case simulated
    
    var baseURL: String {
        switch self {
        case .tomTom:
            return "https://api.tomtom.com/traffic/services/4"
        case .mapbox:
            return "https://api.mapbox.com/directions/v5"
        case .here:
            return "https://traffic.ls.hereapi.com/6.0"
        case .simulated:
            return ""
        }
    }
    
    var apiKey: String {
        switch self {
        case .tomTom:
            return APIKeys.tomTomAPIKey
        case .mapbox:
            return APIKeys.mapboxAPIKey
        case .here:
            return APIKeys.hereAPIKey
        case .simulated:
            return ""
        }
    }
    
    var freeTierLimit: String {
        switch self {
        case .tomTom:
            return "2,500 calls/day"
        case .mapbox:
            return "50,000 requests/month"
        case .here:
            return "250,000 transactions/month"
        case .simulated:
            return "Unlimited (Demo)"
        }
    }
}

enum WeatherProvider {
    case openMeteo
    case openWeatherMap
    case simulated
    
    var baseURL: String {
        switch self {
        case .openMeteo:
            return APIKeys.openMeteoBaseURL
        case .openWeatherMap:
            return "https://api.openweathermap.org/data/2.5"
        case .simulated:
            return ""
        }
    }
    
    var apiKey: String {
        switch self {
        case .openMeteo:
            return "" // No API key needed
        case .openWeatherMap:
            return APIKeys.openWeatherMapAPIKey
        case .simulated:
            return ""
        }
    }
    
    var freeTierLimit: String {
        switch self {
        case .openMeteo:
            return "Unlimited (FREE)"
        case .openWeatherMap:
            return "1,000 calls/day"
        case .simulated:
            return "Unlimited (Demo)"
        }
    }
}

enum CrimeDataProvider {
    case crimeReports
    case fbi
    case dataGov
    case simulated
    
    var baseURL: String {
        switch self {
        case .crimeReports:
            return "https://api.crimereports.com/v1"
        case .fbi:
            return APIKeys.fbiBaseURL
        case .dataGov:
            return APIKeys.dataGovBaseURL
        case .simulated:
            return ""
        }
    }
    
    var apiKey: String {
        switch self {
        case .crimeReports:
            return APIKeys.crimeReportsAPIKey
        case .fbi, .dataGov, .simulated:
            return "" // No API key needed
        }
    }
    
    var freeTierLimit: String {
        switch self {
        case .crimeReports:
            return "1,000 calls/day"
        case .fbi, .dataGov:
            return "Unlimited (FREE)"
        case .simulated:
            return "Unlimited (Demo)"
        }
    }
}

// MARK: - API Status

struct APIStatus {
    let provider: String
    let isConfigured: Bool
    let freeTierLimit: String
    let documentationURL: String
}

extension APIConfiguration {
    
    static func getAPIStatus() -> [APIStatus] {
        return [
            APIStatus(
                provider: "TomTom Traffic",
                isConfigured: APIKeys.tomTomAPIKey != "YOUR_TOMTOM_API_KEY",
                freeTierLimit: trafficProvider.freeTierLimit,
                documentationURL: "https://developer.tomtom.com/traffic-api"
            ),
            APIStatus(
                provider: "Open-Meteo Weather",
                isConfigured: true, // No API key needed
                freeTierLimit: "Unlimited (FREE)",
                documentationURL: "https://open-meteo.com/"
            ),
            APIStatus(
                provider: "CrimeReports.com",
                isConfigured: APIKeys.crimeReportsAPIKey != "YOUR_CRIMEREPORTS_API_KEY",
                freeTierLimit: crimeDataProvider.freeTierLimit,
                documentationURL: "https://crimereports.com/api"
            ),
            APIStatus(
                provider: "FBI Crime Data",
                isConfigured: true, // No API key needed
                freeTierLimit: "Unlimited (FREE)",
                documentationURL: "https://www.fbi.gov/how-we-can-help-you/more-fbi-services-and-information/ways-to-report-a-crime/crime-data-api"
            )
        ]
    }
}
