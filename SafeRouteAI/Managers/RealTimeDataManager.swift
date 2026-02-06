//
//  RealTimeDataManager.swift
//  SafeRouteAI
//
//  Manages real-time data sources with continuous updates
//  Provides live safety information for route planning
//

import Foundation
import CoreLocation
import Combine
import UserNotifications

class RealTimeDataManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRealTimeEnabled = true
    @Published var lastUpdateTime: Date?
    @Published var updateInterval: TimeInterval = 300 // 5 minutes
    @Published var activeDataSources: [String] = []
    @Published var realTimeAlerts: [RealTimeAlert] = []
    
    // MARK: - Data Sources
    private let weatherDataSource = WeatherDataSource()
    private let trafficDataSource = FreeTrafficDataSource()
    private let crimeDataSource = FreeCrimeDataSource()
    // private let cityServiceDataSource = CityServiceDataSource() // Temporarily disabled
    
    // MARK: - Real-time Data Storage
    @Published var currentWeatherData: WeatherData?
    @Published var currentTrafficData: TrafficData?
    @Published var currentCrimeData: SafetyData?
    @Published var currentCityServiceData: SafetyData?
    
    // MARK: - Location Tracking
    private var currentLocation: CLLocationCoordinate2D?
    private var locationUpdateRadius: Double = 500.0 // 500m
    
    // MARK: - Timers and Publishers
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Notification Manager
    private let notificationManager = RealTimeNotificationManager()
    
    init() {
        setupRealTimeUpdates()
        requestNotificationPermissions()
    }
    
    deinit {
        stopRealTimeUpdates()
    }
    
    // MARK: - Real-Time Update Management
    
    func startRealTimeUpdates(for location: CLLocationCoordinate2D) {
        currentLocation = location
        isRealTimeEnabled = true
        
        print("🔄 Starting real-time data updates for location: \(location)")
        
        // Immediate update
        Task {
            await performRealTimeUpdate()
        }
        
        // Start periodic updates
        startPeriodicUpdates()
        
        // Start location-based updates
        startLocationBasedUpdates()
    }
    
    func stopRealTimeUpdates() {
        isRealTimeEnabled = false
        updateTimer?.invalidate()
        updateTimer = nil
        
        print("⏹️ Stopped real-time data updates")
    }
    
    private func setupRealTimeUpdates() {
        // Configure update intervals based on data source needs
        updateInterval = 300 // 5 minutes default
        
        // Start with enabled sources
        activeDataSources = ["Weather Data", "Free Traffic Data", "Free Crime Data"]
    }
    
    private func startPeriodicUpdates() {
        updateTimer?.invalidate()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performRealTimeUpdate()
            }
        }
        
        print("⏰ Started periodic updates every \(Int(updateInterval)) seconds")
    }
    
    private func startLocationBasedUpdates() {
        // Could integrate with LocationManager for automatic location updates
        // For now, manual updates when user changes location
    }
    
    // MARK: - Real-Time Data Fetching
    
    private func performRealTimeUpdate() async {
        guard let location = currentLocation, isRealTimeEnabled else { return }
        
        print("🔄 Performing real-time update at \(Date())")
        
        let startTime = Date()
        var updateCount = 0
        var errors: [String] = []
        
        // Update Weather Data (every 15 minutes)
        if shouldUpdateWeatherData() {
            do {
                let weatherSafetyData = try await weatherDataSource.fetchData(for: location, radius: 1000.0)
                
                // Extract weather data from safety data
                if let weatherData = extractWeatherData(from: weatherSafetyData) {
                    currentWeatherData = weatherData
                    updateCount += 1
                    
                    // Check for weather alerts
                    checkForWeatherAlerts(weatherData)
                }
                
                activeDataSources.append("Weather Data")
            } catch {
                errors.append("Weather: \(error.localizedDescription)")
                activeDataSources.removeAll { $0 == "Weather Data" }
            }
        }
        
        // Update Traffic Data (every 10 minutes)
        if shouldUpdateTrafficData() {
            do {
                let trafficSafetyData = try await trafficDataSource.fetchData(for: location, radius: 500.0)
                
                // Extract traffic data from safety data
                if let trafficData = extractTrafficData(from: trafficSafetyData) {
                    currentTrafficData = trafficData
                    updateCount += 1
                    
                    // Check for traffic alerts
                    checkForTrafficAlerts(trafficData)
                }
                
                activeDataSources.append("Free Traffic Data")
            } catch {
                errors.append("Traffic: \(error.localizedDescription)")
                activeDataSources.removeAll { $0 == "Free Traffic Data" }
            }
        }
        
        // Update Crime Data (every 30 minutes)
        if shouldUpdateCrimeData() {
            do {
                let crimeSafetyData = try await crimeDataSource.fetchData(for: location, radius: 800.0)
                
                // Extract crime data from safety data
                if let crimeData = extractCrimeData(from: crimeSafetyData) {
                    currentCrimeData = crimeData
                    updateCount += 1
                    
                    // Check for crime alerts
                    checkForCrimeAlerts(crimeData)
                }
                
                activeDataSources.append("Free Crime Data")
            } catch {
                errors.append("Crime: \(error.localizedDescription)")
                activeDataSources.removeAll { $0 == "Free Crime Data" }
            }
        }
        
        // Update City Services (every hour) - Temporarily disabled
        if shouldUpdateCityServiceData() {
            // City Service data temporarily disabled
            print("⚠️ City Services data source temporarily disabled")
        }
        
        // Update metadata
        lastUpdateTime = Date()
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ Real-time update completed in \(String(format: "%.2f", duration))s")
        print("   📊 Updated \(updateCount) data sources")
        print("   🔄 Active sources: \(activeDataSources.count)")
        
        if !errors.isEmpty {
            print("   ⚠️ Errors: \(errors.joined(separator: ", "))")
        }
        
        // Send notification for critical updates
        await sendCriticalUpdateNotifications()
    }
    
    // MARK: - Update Timing Logic
    
    private func shouldUpdateWeatherData() -> Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
        return timeSinceUpdate >= 900 // 15 minutes
    }
    
    private func shouldUpdateTrafficData() -> Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
        return timeSinceUpdate >= 600 // 10 minutes
    }
    
    private func shouldUpdateCrimeData() -> Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
        return timeSinceUpdate >= 1800 // 30 minutes
    }
    
    private func shouldUpdateCityServiceData() -> Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
        return timeSinceUpdate >= 3600 // 1 hour
    }
    
    // MARK: - Data Extraction Helpers
    
    private func extractWeatherData(from safetyData: SafetyData) -> WeatherData? {
        // Create WeatherData from safety data environmental factors
        let environmentalFactors = safetyData.environmentalFactors
        
        return WeatherData(
            temperature: environmentalFactors.temperature,
            feelsLike: environmentalFactors.temperature, // Open-Meteo doesn't provide feels-like
            humidity: 0.5, // Default value
            pressure: 1013.25, // Standard atmospheric pressure
            visibility: environmentalFactors.visibility,
            windSpeed: environmentalFactors.windSpeed,
            windDirection: 0.0, // Not available in safety data
            precipitation: environmentalFactors.precipitation,
            condition: environmentalFactors.weatherCondition,
            description: environmentalFactors.weatherCondition.rawValue,
            timestamp: Date()
        )
    }
    
    private func extractTrafficData(from safetyData: SafetyData) -> TrafficData? {
        guard let location = currentLocation else { return nil }
        
        // Create TrafficData from safety data incidents
        let trafficIncidents = safetyData.incidents.filter { $0.type == .trafficAccident }
        
        // Calculate congestion level based on incidents
        let congestionLevel = min(Double(trafficIncidents.count) * 0.2, 1.0)
        let averageSpeed = 30.0 * (1.0 - congestionLevel)
        
        // Extract infrastructure issues as road closures/construction
        let roadClosures = safetyData.infrastructureIssues.filter { $0.type == .roadSurface }
        let constructionZones = safetyData.infrastructureIssues.filter { $0.type == .construction }
        
        return TrafficData(
            location: location,
            congestionLevel: congestionLevel,
            averageSpeed: averageSpeed,
            incidents: trafficIncidents.map { incident in
                TrafficIncident(
                    id: UUID().uuidString,
                    type: "traffic_incident",
                    location: incident.location,
                    timestamp: incident.timestamp,
                    description: incident.description,
                    severity: incident.severity.rawValue
                )
            },
            roadClosures: roadClosures.map { issue in
                RoadClosure(
                    id: UUID().uuidString,
                    location: issue.location,
                    timestamp: issue.timestamp,
                    reason: issue.description,
                    estimatedReopen: issue.estimatedResolutionDate,
                    affectedRadius: sqrt(issue.affectedArea / Double.pi)
                )
            },
            constructionZones: constructionZones.map { issue in
                ConstructionZone(
                    id: UUID().uuidString,
                    location: issue.location,
                    timestamp: issue.timestamp,
                    description: issue.description,
                    estimatedCompletion: issue.estimatedResolutionDate,
                    affectedRadius: sqrt(issue.affectedArea / Double.pi),
                    hasDetour: true
                )
            },
            timestamp: Date()
        )
    }
    
    private func extractCrimeData(from safetyData: SafetyData) -> SafetyData? {
        guard let location = currentLocation else { return nil }
        
        // Create CrimeData from safety data incidents
        let crimeIncidents = safetyData.incidents.filter { $0.type == .crime }
        
        return SafetyData(
            source: "Real-time Crime Data",
            timestamp: Date(),
            location: location,
            incidents: crimeIncidents,
            infrastructureIssues: [],
            environmentalFactors: EnvironmentalFactors(
                weatherCondition: .clear,
                visibility: 1000.0,
                temperature: 20.0,
                windSpeed: 10.0,
                precipitation: 0.0,
                timeOfDay: .midday,
                dayOfWeek: .monday,
                lightingLevel: 0.8
            ),
            confidence: 0.8
        )
    }
    
    // MARK: - Alert Detection
    
    private func checkForWeatherAlerts(_ weatherData: WeatherData) {
        var alerts: [RealTimeAlert] = []
        
        // Check for severe weather
        if weatherData.precipitation > 0.7 {
            alerts.append(RealTimeAlert(
                type: .weather,
                severity: .high,
                title: "Heavy Precipitation Alert",
                message: "Heavy rain/snow detected. Exercise caution.",
                timestamp: Date(),
                location: currentLocation
            ))
        }
        
        if weatherData.visibility < 200 {
            alerts.append(RealTimeAlert(
                type: .weather,
                severity: .critical,
                title: "Poor Visibility Alert",
                message: "Very poor visibility conditions detected.",
                timestamp: Date(),
                location: currentLocation
            ))
        }
        
        if weatherData.windSpeed > 50 {
            alerts.append(RealTimeAlert(
                type: .weather,
                severity: .medium,
                title: "Strong Wind Alert",
                message: "Strong winds detected. Secure loose items.",
                timestamp: Date(),
                location: currentLocation
            ))
        }
        
        realTimeAlerts.append(contentsOf: alerts)
    }
    
    private func checkForTrafficAlerts(_ trafficData: TrafficData) {
        var alerts: [RealTimeAlert] = []
        
        // Check for severe congestion
        if trafficData.congestionLevel > 0.8 {
            alerts.append(RealTimeAlert(
                type: .incident,
                severity: .high,
                title: "Heavy Traffic Alert",
                message: "Severe traffic congestion detected.",
                timestamp: Date(),
                location: currentLocation
            ))
        }
        
        // Check for traffic incidents
        for incident in trafficData.incidents {
            if incident.severity.lowercased() == "high" {
                alerts.append(RealTimeAlert(
                    type: .incident,
                    severity: .medium,
                    title: "Traffic Incident Alert",
                    message: incident.description,
                    timestamp: Date(),
                    location: currentLocation
                ))
            }
        }
        
        // Check for road closures
        if !trafficData.roadClosures.isEmpty {
            alerts.append(RealTimeAlert(
                type: .incident,
                severity: .medium,
                title: "Road Closure Alert",
                message: "\(trafficData.roadClosures.count) road closures detected.",
                timestamp: Date(),
                location: currentLocation
            ))
        }
        
        realTimeAlerts.append(contentsOf: alerts)
    }
    
    private func checkForCrimeAlerts(_ crimeData: SafetyData) {
        var alerts: [RealTimeAlert] = []
        
        // Check for high-severity crimes
        let highSeverityCrimes = crimeData.incidents.filter { $0.severity == .high || $0.severity == .critical }
        
        if highSeverityCrimes.count > 2 {
            alerts.append(RealTimeAlert(
                type: .incident,
                severity: .high,
                title: "High Crime Activity Alert",
                message: "\(highSeverityCrimes.count) serious crimes reported in area.",
                timestamp: Date(),
                location: currentLocation
            ))
        }
        
        // Check for recent crimes
        let recentCrimes = crimeData.incidents.filter { 
            Date().timeIntervalSince($0.timestamp) < 3600 // Last hour
        }
        
        if recentCrimes.count > 3 {
            alerts.append(RealTimeAlert(
                type: .incident,
                severity: .medium,
                title: "Recent Crime Activity",
                message: "\(recentCrimes.count) crimes reported in last hour.",
                timestamp: Date(),
                location: currentLocation
            ))
        }
        
        realTimeAlerts.append(contentsOf: alerts)
    }
    
    // MARK: - Notification Management
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            } else {
                print("❌ Notification permissions denied")
            }
        }
    }
    
    private func sendCriticalUpdateNotifications() async {
        let criticalAlerts = realTimeAlerts.filter { $0.severity == .critical }
        
        for alert in criticalAlerts {
            await notificationManager.sendCriticalAlert(alert)
        }
        
        // Clear old alerts
        let cutoffTime = Date().addingTimeInterval(-3600) // 1 hour ago
        realTimeAlerts.removeAll { $0.timestamp < cutoffTime }
    }
    
    // MARK: - Public Interface
    
    func updateLocation(_ newLocation: CLLocationCoordinate2D) {
        // Check if location changed significantly
        if let currentLoc = currentLocation {
            let distance = CLLocation(latitude: currentLoc.latitude, longitude: currentLoc.longitude)
                .distance(from: CLLocation(latitude: newLocation.latitude, longitude: newLocation.longitude))
            
            if distance > locationUpdateRadius {
                currentLocation = newLocation
                print("📍 Location updated significantly, triggering immediate data refresh")
                
                Task {
                    await performRealTimeUpdate()
                }
            }
        } else {
            currentLocation = newLocation
            startRealTimeUpdates(for: newLocation)
        }
    }
    
    func getRealTimeSafetyScore() -> Double {
        var totalScore: Double = 0.0
        var weightSum: Double = 0.0
        
        // Weather contribution (20%)
        if let weather = currentWeatherData {
            let weatherRisk = calculateWeatherRisk(weather)
            totalScore += weatherRisk * 0.2
            weightSum += 0.2
        }
        
        // Traffic contribution (15%)
        if let traffic = currentTrafficData {
            let trafficRisk = traffic.congestionLevel
            totalScore += trafficRisk * 0.15
            weightSum += 0.15
        }
        
        // Crime contribution (35%)
        if let crime = currentCrimeData {
            let crimeRisk = calculateCrimeRisk(crime)
            totalScore += crimeRisk * 0.35
            weightSum += 0.35
        }
        
        // City services contribution (10%)
        if let cityService = currentCityServiceData {
            let serviceRisk = calculateServiceRisk(cityService)
            totalScore += serviceRisk * 0.10
            weightSum += 0.10
        }
        
        return weightSum > 0 ? totalScore / weightSum : 0.5
    }
    
    private func calculateWeatherRisk(_ weather: WeatherData) -> Double {
        var risk: Double = 0.0
        
        if weather.precipitation > 0.5 { risk += 0.3 }
        if weather.visibility < 500 { risk += 0.4 }
        if weather.windSpeed > 40 { risk += 0.2 }
        if weather.temperature < 0 || weather.temperature > 35 { risk += 0.1 }
        
        return min(risk, 1.0)
    }
    
    private func calculateCrimeRisk(_ crime: SafetyData) -> Double {
        let recentCrimes = crime.incidents.filter { 
            Date().timeIntervalSince($0.timestamp) < 86400 // Last 24 hours
        }
        
        let highSeverityCrimes = recentCrimes.filter { 
            $0.severity == .high || $0.severity == .critical
        }
        
        return min(Double(recentCrimes.count) * 0.1 + Double(highSeverityCrimes.count) * 0.2, 1.0)
    }
    
    private func calculateServiceRisk(_ serviceData: SafetyData) -> Double {
        let criticalIssues = serviceData.infrastructureIssues.filter { 
            $0.severity == .critical || $0.severity == .high
        }
        
        return min(Double(criticalIssues.count) * 0.15, 1.0)
    }
    
    // MARK: - Configuration
    
    func setUpdateInterval(_ interval: TimeInterval) {
        updateInterval = interval
        if isRealTimeEnabled {
            startPeriodicUpdates()
        }
    }
    
    func toggleDataSource(_ sourceName: String, enabled: Bool) {
        if enabled {
            if !activeDataSources.contains(sourceName) {
                activeDataSources.append(sourceName)
            }
        } else {
            activeDataSources.removeAll { $0 == sourceName }
        }
    }
}

// MARK: - Real-Time Alert Models

struct RealTimeAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let severity: AlertSeverity
    let title: String
    let message: String
    let timestamp: Date
    let location: CLLocationCoordinate2D?
    
    init(type: AlertType, severity: AlertSeverity, title: String, message: String, timestamp: Date, location: CLLocationCoordinate2D? = nil) {
        self.type = type
        self.severity = severity
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.location = location
    }
}

// MARK: - Real-Time Notification Manager

class RealTimeNotificationManager {
    
    func sendCriticalAlert(_ alert: RealTimeAlert) async {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.message
        content.sound = .default
        content.categoryIdentifier = "CRITICAL_ALERT"
        content.userInfo = [
            "alertType": alert.type.rawValue,
            "severity": alert.severity.rawValue,
            "timestamp": alert.timestamp.timeIntervalSince1970
        ]
        
        // Add location if available
        if let location = alert.location {
            content.userInfo["latitude"] = location.latitude
            content.userInfo["longitude"] = location.longitude
        }
        
        let request = UNNotificationRequest(
            identifier: "critical_alert_\(alert.id)",
            content: content,
            trigger: nil // Immediate delivery
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📱 Sent critical alert: \(alert.title)")
        } catch {
            print("❌ Failed to send notification: \(error)")
        }
    }
}
