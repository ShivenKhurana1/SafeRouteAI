//
//  ExternalDataSourceManager.swift
//  SafeRouteAI
//
//  Manages integration of external data sources for enhanced path finding
//  Handles city services, crime data, weather, traffic, and more
//

import Foundation
import CoreLocation
import Combine

// MARK: - Data Source Protocols
protocol DataSource {
    var name: String { get }
    var priority: Int { get }
    var refreshInterval: TimeInterval { get }
    var isEnabled: Bool { get set }
    
    func fetchData(for location: CLLocationCoordinate2D, radius: Double) async throws -> SafetyData
    func isDataFresh(for location: CLLocationCoordinate2D) -> Bool
}

// MARK: - Safety Data Models
struct SafetyData: Codable {
    let source: String
    let timestamp: Date
    let location: CLLocationCoordinate2D
    let incidents: [SafetyIncident]
    let infrastructureIssues: [InfrastructureIssue]
    let environmentalFactors: EnvironmentalFactors
    let confidence: Double
}

struct SafetyIncident: Identifiable, Codable {
    let id = UUID()
    let type: IncidentType
    let severity: IncidentSeverity
    let location: CLLocationCoordinate2D
    let timestamp: Date
    let description: String
    let radius: Double // Impact radius in meters
    let weight: Double // Weight for safety scoring (0.0-1.0)
}

enum IncidentType: String, CaseIterable, Codable {
    case crime = "Crime"
    case trafficAccident = "Traffic Accident"
    case lightingIssue = "Lighting Issue"
    case infrastructureIssue = "Infrastructure Issue" // Renamed from infrastructureFailure
    case weatherHazard = "Weather Hazard"
    case publicDisturbance = "Public Disturbance"
    case emergency = "Emergency"
    
    var safetyWeight: Double {
        switch self {
        case .crime: return 0.9
        case .trafficAccident: return 0.7
        case .lightingIssue: return 0.6
        case .infrastructureIssue: return 0.8
        case .weatherHazard: return 0.5
        case .publicDisturbance: return 0.4
        case .emergency: return 1.0
        }
    }
}

enum IncidentSeverity: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var score: Double {
        switch self {
        case .low: return 0.25
        case .medium: return 0.5
        case .high: return 0.75
        case .critical: return 1.0
        }
    }
}

struct InfrastructureIssue: Identifiable, Codable {
    let id = UUID()
    let type: InfrastructureType
    let severity: IncidentSeverity
    let location: CLLocationCoordinate2D
    let timestamp: Date
    let description: String
    let estimatedResolutionDate: Date?
    let affectedArea: Double // Area affected in square meters
}

enum InfrastructureType: String, CaseIterable, Codable {
    case streetLight = "Street Light"
    case sidewalk = "Sidewalk"
    case roadSurface = "Road Surface"
    case crosswalk = "Crosswalk"
    case trafficSignal = "Traffic Signal"
    case bridge = "Bridge"
    case drainage = "Drainage"
    case construction = "Construction"
    
    var safetyImpact: Double {
        switch self {
        case .streetLight: return 0.6
        case .sidewalk: return 0.7
        case .roadSurface: return 0.5
        case .crosswalk: return 0.8
        case .trafficSignal: return 0.9
        case .bridge: return 0.4
        case .drainage: return 0.3
        case .construction: return 0.8
        }
    }
}

struct EnvironmentalFactors: Codable {
    let weatherCondition: WeatherCondition
    let visibility: Double // in meters
    let temperature: Double // in Celsius
    let windSpeed: Double // in km/h
    let precipitation: Double // 0.0-1.0 scale
    let timeOfDay: TimeOfDay
    let dayOfWeek: DayOfWeek
    let lightingLevel: Double // 0.0-1.0 scale
}

enum TimeOfDay: String, CaseIterable, Codable {
    case earlyMorning = "Early Morning" // 5:00-8:00
    case morningRush = "Morning Rush" // 8:00-10:00
    case midday = "Midday" // 10:00-15:00
    case afternoonRush = "Afternoon Rush" // 15:00-18:00
    case evening = "Evening" // 18:00-21:00
    case night = "Night" // 21:00-5:00
    
    var safetyMultiplier: Double {
        switch self {
        case .earlyMorning: return 0.8
        case .morningRush: return 0.9
        case .midday: return 1.0
        case .afternoonRush: return 0.9
        case .evening: return 0.8
        case .night: return 0.6
        }
    }
}

enum DayOfWeek: String, CaseIterable, Codable {
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    case sunday = "Sunday"
    
    var activityLevel: Double {
        switch self {
        case .monday, .tuesday, .wednesday, .thursday: return 0.8
        case .friday: return 0.9
        case .saturday: return 0.7
        case .sunday: return 0.6
        }
    }
}

// MARK: - Data Cache
struct DataCache {
    private var cache: [String: CachedData] = [:]
    private let maxAge: TimeInterval = 300 // 5 minutes
    
    struct CachedData {
        let data: SafetyData
        let timestamp: Date
        let location: CLLocationCoordinate2D
        let radius: Double
    }
    
    mutating func store(_ data: SafetyData, for location: CLLocationCoordinate2D, radius: Double) {
        let key = cacheKey(for: location, radius: radius)
        cache[key] = CachedData(data: data, timestamp: Date(), location: location, radius: radius)
    }
    
    func retrieve(for location: CLLocationCoordinate2D, radius: Double) -> SafetyData? {
        let key = cacheKey(for: location, radius: radius)
        guard let cached = cache[key] else { return nil }
        
        // Check if data is still fresh
        if Date().timeIntervalSince(cached.timestamp) > maxAge {
            return nil
        }
        
        // Check if location is within cached radius
        let distance = CLLocation(latitude: location.latitude, longitude: location.longitude)
            .distance(from: CLLocation(latitude: cached.location.latitude, longitude: cached.location.longitude))
        
        if distance <= radius {
            return cached.data
        }
        
        return nil
    }
    
    private func cacheKey(for location: CLLocationCoordinate2D, radius: Double) -> String {
        let roundedLat = round(location.latitude * 1000) / 1000
        let roundedLon = round(location.longitude * 1000) / 1000
        let roundedRadius = round(radius / 100) * 100
        return "\(roundedLat),\(roundedLon),\(roundedRadius)"
    }
    
    mutating func clearExpiredData() {
        let now = Date()
        cache = cache.filter { _, cached in
            now.timeIntervalSince(cached.timestamp) <= maxAge
        }
    }
}

// MARK: - External Data Source Manager
class ExternalDataSourceManager: ObservableObject {
    @Published var isDataLoading = false
    @Published var lastUpdate: Date?
    @Published var dataSources: [DataSource] = []
    @Published var combinedSafetyData: SafetyData?
    
    private var cache = DataCache()
    private var cancellables = Set<AnyCancellable>()
    private let refreshTimer = Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
    
    init() {
        setupDataSources()
        startPeriodicRefresh()
    }
    
    private func setupDataSources() {
        dataSources = [
            PedestrianSafetyDataSource(), // Pedestrian and biking safety data
            ElevationDataSource(), // Elevation data for route optimization
            AirQualityDataSource(), // NEW: Air quality for health-focused routing
            TransitDataSource(), // GTFS transit data for multi-modal routing
            // CityServiceDataSource(), // Temporarily disabled
            SimpleFBICrimeDataSource(), // FBI Crime Data with BJS fallback
            BJSCrimeDataSource(), // NEW: BJS nationwide crime data as backup
            WeatherDataSource(), // Free Open-Meteo weather API (no API key)
            // Removed: FreeTrafficDataSource() - not relevant for walking/biking
        ].sorted { $0.priority > $1.priority }
    }
    
    // MARK: - Combined Data Access
    
    func getCombinedSafetyData(for location: CLLocationCoordinate2D, radius: Double) async throws -> CombinedSafetyData {
        var allIncidents: [SafetyIncident] = []
        var allInfrastructureIssues: [InfrastructureIssue] = []
        var environmentalFactors = EnvironmentalFactors(
            weatherCondition: .clear,
            visibility: 1000.0,
            temperature: 20.0,
            windSpeed: 10.0,
            precipitation: 0.0,
            timeOfDay: .midday,
            dayOfWeek: .monday,
            lightingLevel: 1.0
        )
        var elevationData: ElevationData?
        var airQualityData: AirQualityInfo?
        var transitData: TransitInfo?
        
        // Collect data from all sources
        print("🔄 [ExternalDataManager] Fetching data from \(dataSources.count) data sources...")
        
        for dataSource in dataSources {
            if dataSource.isEnabled {
                print("📡 [ExternalDataManager] Fetching from \(dataSource.name)...")
                do {
                    let safetyData = try await dataSource.fetchData(for: location, radius: radius)
                    
                    // Log what we got
                    let incidentCount = safetyData.incidents.count
                    let issueCount = safetyData.infrastructureIssues.count
                    
                    print("✅ [\(dataSource.name)] Got \(incidentCount) incidents, \(issueCount) issues")
                    
                    // Special logging for new data sources
                    if let airQuality = safetyData as? AirQualityInfo {
                        print("🌬️ [AirQuality] AQI: \(airQuality.combinedAQI), Category: \(airQuality.category)")
                    }
                    
                    if let transit = safetyData as? TransitInfo {
                        print("🚌 [Transit] \(transit.nearbyStops.count) stops, Service Level: \(transit.serviceLevel)")
                    }
                    
                    allIncidents.append(contentsOf: safetyData.incidents)
                    allInfrastructureIssues.append(contentsOf: safetyData.infrastructureIssues)
                    
                    // Use the most recent environmental factors
                    environmentalFactors = safetyData.environmentalFactors
                    
                    // Store specific data types
                    if let elevation = safetyData as? ElevationData {
                        elevationData = elevation
                        print("⛰️ [Elevation] Max: \(elevation.maxElevation)m, Range: \(elevation.elevationRange)m")
                    } else if let airQuality = safetyData as? AirQualityInfo {
                        airQualityData = airQuality
                    } else if let transit = safetyData as? TransitInfo {
                        transitData = transit
                    }
                } catch {
                    print("❌ [ExternalDataManager] Failed to fetch data from \(dataSource.name): \(error)")
                    continue
                }
            } else {
                print("⏸️ [ExternalDataManager] \(dataSource.name) is disabled")
            }
        }
        
        print("📊 [ExternalDataManager] Total: \(allIncidents.count) incidents, \(allInfrastructureIssues.count) issues")
        
        return CombinedSafetyData(
            incidents: allIncidents,
            infrastructureIssues: allInfrastructureIssues,
            environmentalFactors: environmentalFactors,
            elevationData: elevationData,
            airQualityData: airQualityData,
            transitData: transitData
        )
    }
    
    private func startPeriodicRefresh() {
        refreshTimer
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.refreshAllDataSources()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func getSafetyData(for location: CLLocationCoordinate2D, radius: Double = 500.0) async -> SafetyData? {
        // Check cache first
        if let cachedData = cache.retrieve(for: location, radius: radius) {
            return cachedData
        }
        
        // Fetch fresh data
        isDataLoading = true
        defer { isDataLoading = false }
        
        var allIncidents: [SafetyIncident] = []
        var allInfrastructureIssues: [InfrastructureIssue] = []
        var environmentalFactors = EnvironmentalFactors(
            weatherCondition: .clear,
            visibility: 1000.0,
            temperature: 20.0,
            windSpeed: 10.0,
            precipitation: 0.0,
            timeOfDay: .midday,
            dayOfWeek: .monday,
            lightingLevel: 1.0
        )
        
        var totalConfidence: Double = 0.0
        var activeSources: Int = 0
        
        // Fetch data from all enabled sources
        for source in dataSources where source.isEnabled {
            do {
                let data = try await source.fetchData(for: location, radius: radius)
                allIncidents.append(contentsOf: data.incidents)
                allInfrastructureIssues.append(contentsOf: data.infrastructureIssues)
                
                // Use the most recent environmental factors
                if data.timestamp > (combinedSafetyData?.timestamp ?? Date.distantPast) {
                    environmentalFactors = data.environmentalFactors
                }
                
                totalConfidence += data.confidence
                activeSources += 1
            } catch {
                print("⚠️ Failed to fetch data from \(source.name): \(error)")
            }
        }
        
        // Combine and cache the data
        let combinedData = SafetyData(
            source: "Combined",
            timestamp: Date(),
            location: location,
            incidents: allIncidents,
            infrastructureIssues: allInfrastructureIssues,
            environmentalFactors: environmentalFactors,
            confidence: activeSources > 0 ? totalConfidence / Double(activeSources) : 0.0
        )
        
        cache.store(combinedData, for: location, radius: radius)
        combinedSafetyData = combinedData
        lastUpdate = Date()
        
        return combinedData
    }
    
    func refreshAllDataSources() async {
        cache.clearExpiredData()
        
        if let currentLocation = combinedSafetyData?.location {
            await getSafetyData(for: currentLocation)
        }
    }
    
    func enableDataSource(_ sourceName: String, enabled: Bool) {
        if let index = dataSources.firstIndex(where: { $0.name == sourceName }) {
            dataSources[index].isEnabled = enabled
        }
    }
    
    // MARK: - Data Analysis Methods
    
    func calculateSafetyScore(for location: CLLocationCoordinate2D, radius: Double = 100.0) async -> Double {
        guard let safetyData = await getSafetyData(for: location, radius: radius) else {
            return 0.5 // Neutral score if no data available
        }
        
        var riskScore: Double = 0.0
        
        // Calculate incident risk
        for incident in safetyData.incidents {
            let distance = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: incident.location.latitude, longitude: incident.location.longitude))
            
            if distance <= incident.radius {
                let proximityFactor = 1.0 - (distance / incident.radius)
                let incidentRisk = incident.type.safetyWeight * incident.severity.score * proximityFactor
                riskScore += incidentRisk
            }
        }
        
        // Calculate infrastructure risk
        for issue in safetyData.infrastructureIssues {
            let distance = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: issue.location.latitude, longitude: issue.location.longitude))
            
            let impactRadius = sqrt(issue.affectedArea / Double.pi)
            if distance <= impactRadius {
                let proximityFactor = 1.0 - (distance / impactRadius)
                let infrastructureRisk = issue.type.safetyImpact * issue.severity.score * proximityFactor
                riskScore += infrastructureRisk
            }
        }
        
        // Apply environmental factors
        let environmentalMultiplier = safetyData.environmentalFactors.lightingLevel *
                                  safetyData.environmentalFactors.timeOfDay.safetyMultiplier *
                                  safetyData.environmentalFactors.dayOfWeek.activityLevel
        
        riskScore *= environmentalMultiplier
        
        // Normalize to 0.0-1.0 scale (higher = riskier)
        let normalizedScore = min(max(riskScore, 0.0), 1.0)
        
        return normalizedScore
    }
    
    func getNearbyIncidents(for location: CLLocationCoordinate2D, radius: Double = 500.0) async -> [SafetyIncident] {
        guard let safetyData = await getSafetyData(for: location, radius: radius) else {
            return []
        }
        
        return safetyData.incidents.sorted { incident1, incident2 in
            let distance1 = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: incident1.location.latitude, longitude: incident1.location.longitude))
            let distance2 = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: incident2.location.latitude, longitude: incident2.location.longitude))
            return distance1 < distance2
        }
    }
    
    func getInfrastructureIssues(for location: CLLocationCoordinate2D, radius: Double = 500.0) async -> [InfrastructureIssue] {
        guard let safetyData = await getSafetyData(for: location, radius: radius) else {
            return []
        }
        
        return safetyData.infrastructureIssues.sorted { issue1, issue2 in
            let distance1 = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: issue1.location.latitude, longitude: issue1.location.longitude))
            let distance2 = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: issue2.location.latitude, longitude: issue2.location.longitude))
            return distance1 < distance2
        }
    }
}
