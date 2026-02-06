//
//  TransitDataSource.swift
//  SafeRouteAI
//
//  GTFS Transit data for multi-modal route planning
//  Enables walking/biking + public transit combinations
//

import Foundation
import CoreLocation

class TransitDataSource: DataSource {
    let name = "Transit Data"
    let priority = 2 // High priority for multi-modal routing
    let refreshInterval: TimeInterval = 300 // 5 minutes (transit changes frequently)
    var isEnabled = true
    
    private var lastFetch: Date?
    private var cachedData: SafetyData?
    private let apiKey = "FREE" // GTFS feeds are typically free
    
    func fetchData(for location: CLLocationCoordinate2D, radius: Double = 1000.0) async throws -> SafetyData {
        print("🚌 [TransitDataSource] Starting data fetch for location: \(location)")
        
        // Fetch data from multiple sources
        async let staticTask = fetchStaticGTFSData(for: location, radius: radius)
        async let realtimeTask = fetchRealtimeGTFSData(for: location, radius: radius)
        async let transitlandTask = fetchTransitlandData(for: location, radius: radius)
        
        let (staticData, realtimeData, transitlandData) = try await (staticTask, realtimeTask, transitlandTask)
        
        print("🚌 [TransitDataSource] Got GTFS static: \(staticData.stops.count) stops, \(staticData.routes.count) routes")
        print("🚌 [TransitDataSource] Got GTFS realtime: \(realtimeData.vehiclePositions.count) vehicles, \(realtimeData.alerts.count) alerts")
        print("🚌 [TransitDataSource] Got Transitland: \(transitlandData.routes.count) routes")
        
        let transitInfo = try await createTransitInfo(
            staticData: staticData,
            realtimeData: realtimeData,
            transitlandData: transitlandData,
            location: location
        )
        
        print("🚌 [TransitDataSource] Created transit info: \(transitInfo.nearbyStops.count) nearby stops, service level: \(transitInfo.serviceLevel)")
        
        // Create incidents based on transit conditions
        let incidents = createTransitIncidents(from: transitInfo, location: location)
        
        // Create infrastructure issues for transit access
        let infrastructureIssues = createTransitInfrastructureIssues(from: transitInfo, location: location)
        
        // Environmental factors with transit consideration
        let environmentalFactors = EnvironmentalFactors(
            weatherCondition: .clear, // Will be updated by weather data source
            visibility: calculateVisibilityBasedOnTransit(transitInfo),
            temperature: 20.0,
            windSpeed: 10.0,
            precipitation: 0.0,
            timeOfDay: getCurrentTimeOfDay(),
            dayOfWeek: getCurrentDayOfWeek(),
            lightingLevel: calculateLightingLevel()
        )
        
        let safetyData = SafetyData(
            source: "Transit Data",
            timestamp: Date(),
            location: location,
            incidents: incidents,
            infrastructureIssues: infrastructureIssues,
            environmentalFactors: environmentalFactors,
            confidence: 0.90
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
    
    // MARK: - GTFS Static Data Fetching
    
    private func fetchStaticGTFSData(for location: CLLocationCoordinate2D, radius: Double) async throws -> GTFSStaticData {
        // Try to find local GTFS feeds first
        let nearbyAgencies = try await findNearbyTransitAgencies(location: location, radius: radius)
        
        var routes: [GTFSRoute] = []
        var stops: [GTFSStop] = []
        var schedules: [GFSSchedule] = []
        
        // Fetch data from each nearby agency
        for agency in nearbyAgencies.prefix(3) { // Limit to 3 agencies for performance
            do {
                let agencyData = try await fetchAgencyGTFSData(agency: agency, location: location, radius: radius)
                routes.append(contentsOf: agencyData.routes)
                stops.append(contentsOf: agencyData.stops)
                schedules.append(contentsOf: agencyData.schedules)
            } catch {
                print("Failed to fetch data for agency \(agency.name): \(error)")
                continue
            }
        }
        
        return GTFSStaticData(
            agencies: nearbyAgencies,
            routes: routes,
            stops: stops,
            schedules: schedules
        )
    }
    
    private func findNearbyTransitAgencies(location: CLLocationCoordinate2D, radius: Double) async throws -> [TransitAgency] {
        // Use Transitland API to find nearby transit agencies
        let bbox = calculateBoundingBox(center: location, radius: radius)
        let urlString = "https://transit.land/api/v2/rest/agencies?bbox=\(bbox)"
        
        guard let url = URL(string: urlString) else {
            throw TransitError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw TransitError.apiError
            }
            
            let decoder = JSONDecoder()
            let transitlandResponse = try decoder.decode(TransitlandAgenciesResponse.self, from: data)
            
            return transitlandResponse.agencies.map { TransitAgency(from: $0) }
        } catch {
            // Fallback to major US cities
            return getFallbackTransitAgencies(location: location)
        }
    }
    
    private func fetchAgencyGTFSData(agency: TransitAgency, location: CLLocationCoordinate2D, radius: Double) async throws -> AgencyGTFSData {
        // For demo purposes, return simulated data
        // In production, you would fetch actual GTFS feeds from agency URLs
        return AgencyGTFSData(
            routes: generateSampleRoutes(agency: agency, location: location),
            stops: generateSampleStops(agency: agency, location: location, count: 10),
            schedules: generateSampleSchedules(agency: agency, count: 20)
        )
    }
    
    // MARK: - GTFS Realtime Data Fetching
    
    private func fetchRealtimeGTFSData(for location: CLLocationCoordinate2D, radius: Double) async throws -> GTFSRealtimeData {
        // Fetch realtime vehicle positions and alerts
        async let vehiclePositions = fetchVehiclePositions(location: location, radius: radius)
        async let tripUpdates = fetchTripUpdates(location: location, radius: radius)
        async let alerts = fetchTransitAlerts(location: location, radius: radius)
        
        return GTFSRealtimeData(
            vehiclePositions: try await vehiclePositions,
            tripUpdates: try await tripUpdates,
            alerts: try await alerts
        )
    }
    
    private func fetchVehiclePositions(location: CLLocationCoordinate2D, radius: Double) async throws -> [VehiclePosition] {
        // Simulate vehicle positions for demo
        let count = Int.random(in: 5...15)
        return (0..<count).map { _ in
            VehiclePosition(
                id: UUID().uuidString,
                routeId: "route_\(Int.random(in: 1...5))",
                location: generateRandomLocation(near: location, radius: radius),
                bearing: Double.random(in: 0...360),
                timestamp: Date(),
                occupancy: Occupancy.allCases.randomElement() ?? .empty
            )
        }
    }
    
    private func fetchTripUpdates(location: CLLocationCoordinate2D, radius: Double) async throws -> [TripUpdate] {
        // Simulate trip updates for demo
        let count = Int.random(in: 3...10)
        return (0..<count).map { _ in
            TripUpdate(
                tripId: "trip_\(Int.random(in: 1...100))",
                routeId: "route_\(Int.random(in: 1...5))",
                delay: Int.random(in: -300...300), // -5 to +5 minutes
                timestamp: Date()
            )
        }
    }
    
    private func fetchTransitAlerts(location: CLLocationCoordinate2D, radius: Double) async throws -> [TransitAlert] {
        // Simulate transit alerts for demo
        let count = Int.random(in: 0...3)
        return (0..<count).map { _ in
            TransitAlert(
                id: UUID().uuidString,
                type: TransitAlertType.allCases.randomElement() ?? .serviceChange,
                severity: TransitAlertSeverity.allCases.randomElement() ?? .medium,
                title: ["Service Delay", "Route Change", "Station Closure", "Emergency"].randomElement() ?? "Service Alert",
                description: "Transit service alert in area",
                affectedRoutes: ["route_\(Int.random(in: 1...5))"],
                timestamp: Date()
            )
        }
    }
    
    // MARK: - Transitland API
    
    private func fetchTransitlandData(for location: CLLocationCoordinate2D, radius: Double) async throws -> TransitlandData {
        let bbox = calculateBoundingBox(center: location, radius: radius)
        let urlString = "https://transit.land/api/v2/rest/routes?bbox=\(bbox)"
        
        guard let url = URL(string: urlString) else {
            throw TransitError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw TransitError.apiError
            }
            
            let decoder = JSONDecoder()
            let transitlandResponse = try decoder.decode(TransitlandRoutesResponse.self, from: data)
            
            return TransitlandData(
                routes: transitlandResponse.routes.map { TransitlandRoute(from: $0) }
            )
        } catch {
            // Return empty data on error
            return TransitlandData(routes: [])
        }
    }
    
    // MARK: - Data Processing
    
    private func createTransitInfo(
        staticData: GTFSStaticData,
        realtimeData: GTFSRealtimeData,
        transitlandData: TransitlandData,
        location: CLLocationCoordinate2D
    ) async throws -> TransitInfo {
        // Combine all data sources
        let nearbyStops = findNearbyStops(stops: staticData.stops, location: location, radius: 500)
        let activeRoutes = findActiveRoutes(routes: staticData.routes, nearbyStops: nearbyStops)
        let serviceLevel = calculateServiceLevel(
            routes: activeRoutes,
            realtime: realtimeData,
            alerts: realtimeData.alerts
        )
        
        return TransitInfo(
            location: location,
            agencies: staticData.agencies,
            nearbyStops: nearbyStops,
            activeRoutes: activeRoutes,
            vehiclePositions: realtimeData.vehiclePositions,
            tripUpdates: realtimeData.tripUpdates,
            alerts: realtimeData.alerts,
            serviceLevel: serviceLevel,
            timestamp: Date()
        )
    }
    
    private func createTransitIncidents(from transitInfo: TransitInfo, location: CLLocationCoordinate2D) -> [SafetyIncident] {
        var incidents: [SafetyIncident] = []
        
        // Service alerts as incidents
        for alert in transitInfo.alerts {
            let severity: IncidentSeverity
            switch alert.severity {
            case .low: severity = .low
            case .medium: severity = .medium
            case .high: severity = .high
            case .critical: severity = .critical
            }
            
            incidents.append(SafetyIncident(
                type: .emergency,
                severity: severity,
                location: location,
                timestamp: alert.timestamp,
                description: "Transit Alert: \(alert.title)",
                radius: 500.0,
                weight: 0.7
            ))
        }
        
        // Poor service level incidents
        if transitInfo.serviceLevel < 0.3 {
            incidents.append(SafetyIncident(
                type: .infrastructureIssue,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Limited transit service in area",
                radius: 800.0,
                weight: 0.5
            ))
        }
        
        return incidents
    }
    
    private func createTransitInfrastructureIssues(from transitInfo: TransitInfo, location: CLLocationCoordinate2D) -> [InfrastructureIssue] {
        var issues: [InfrastructureIssue] = []
        
        // Create issues for transit stops (as access points)
        for stop in transitInfo.nearbyStops {
            issues.append(InfrastructureIssue(
                type: .crosswalk, // Transit stops are access points
                severity: .low,
                location: stop.location,
                timestamp: Date(),
                description: "Transit stop: \(stop.name)",
                estimatedResolutionDate: nil, // Permanent infrastructure
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
    
    private func findNearbyStops(stops: [GTFSStop], location: CLLocationCoordinate2D, radius: Double) -> [GTFSStop] {
        return stops.filter { stop in
            let distance = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: stop.location.latitude, longitude: stop.location.longitude))
            return distance <= radius
        }
    }
    
    private func findActiveRoutes(routes: [GTFSRoute], nearbyStops: [GTFSStop]) -> [GTFSRoute] {
        let nearbyStopIds = Set(nearbyStops.map { $0.id })
        return routes.filter { route in
            !Set(route.stopIds).intersection(nearbyStopIds).isEmpty
        }
    }
    
    private func calculateServiceLevel(routes: [GTFSRoute], realtime: GTFSRealtimeData, alerts: [TransitAlert]) -> Double {
        var serviceScore = Double(routes.count) * 0.2 // Base score from route count
        
        // Add realtime vehicle positions
        serviceScore += Double(realtime.vehiclePositions.count) * 0.1
        
        // Subtract for alerts
        serviceScore -= Double(alerts.count) * 0.1
        
        // Normalize to 0-1 scale
        return min(max(serviceScore / 2.0, 0.0), 1.0)
    }
    
    private func calculateVisibilityBasedOnTransit(_ transitInfo: TransitInfo) -> Double {
        // Transit areas typically have good lighting
        if transitInfo.serviceLevel > 0.5 {
            return 1200.0
        } else {
            return 800.0
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
    
    // MARK: - Fallback Data Generation
    
    private func getFallbackTransitAgencies(location: CLLocationCoordinate2D) -> [TransitAgency] {
        // Major US cities transit agencies
        let majorAgencies = [
            ("NYC", "MTA", 40.7128, -74.0060),
            ("Chicago", "CTA", 41.8781, -87.6298),
            ("LA", "LACMTA", 34.0522, -118.2437),
            ("SF", "BART", 37.7749, -122.4194),
            ("Boston", "MBTA", 42.3601, -71.0589)
        ]
        
        return majorAgencies.compactMap { city, name, lat, lon in
            let distance = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: lat, longitude: lon))
            if distance < 50000 { // Within 50km
                return TransitAgency(id: name.lowercased(), name: name, url: "", timezone: "America/New_York")
            }
            return nil
        }
    }
    
    private func generateSampleRoutes(agency: TransitAgency, location: CLLocationCoordinate2D) -> [GTFSRoute] {
        let routeTypes = [1, 2, 3, 4, 5, 6, 7] // GTFS route types
        let colors = ["Blue", "Red", "Green", "Yellow", "Orange", "Purple", "Brown"]
        
        return (0..<5).map { index in
            GTFSRoute(
                id: "\(agency.id)_route_\(index)",
                agencyId: agency.id,
                shortName: "\(index + 1)",
                longName: "\(colors[index % colors.count]) Line",
                type: routeTypes[index % routeTypes.count],
                color: colors[index % colors.count],
                stopIds: []
            )
        }
    }
    
    private func generateSampleStops(agency: TransitAgency, location: CLLocationCoordinate2D, count: Int) -> [GTFSStop] {
        return (0..<count).map { index in
            GTFSStop(
                id: "\(agency.id)_stop_\(index)",
                name: "Stop \(index + 1)",
                location: generateRandomLocation(near: location, radius: 1000),
                code: "\(index + 1)"
            )
        }
    }
    
    private func generateSampleSchedules(agency: TransitAgency, count: Int) -> [GFSSchedule] {
        return (0..<count).map { index in
            GFSSchedule(
                tripId: "\(agency.id)_trip_\(index)",
                routeId: "\(agency.id)_route_\(index % 5)",
                stopId: "\(agency.id)_stop_\(index % 10)",
                arrivalTime: Date().addingTimeInterval(Double.random(in: 0...3600)),
                departureTime: Date().addingTimeInterval(Double.random(in: 0...3600))
            )
        }
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

struct TransitInfo {
    let location: CLLocationCoordinate2D
    let agencies: [TransitAgency]
    let nearbyStops: [GTFSStop]
    let activeRoutes: [GTFSRoute]
    let vehiclePositions: [VehiclePosition]
    let tripUpdates: [TripUpdate]
    let alerts: [TransitAlert]
    let serviceLevel: Double
    let timestamp: Date
}

struct TransitAgency {
    let id: String
    let name: String
    let url: String
    let timezone: String
    
    init(id: String, name: String, url: String, timezone: String) {
        self.id = id
        self.name = name
        self.url = url
        self.timezone = timezone
    }
    
    init(from transitlandAgency: TransitlandAgencyResponse) {
        self.id = transitlandAgency.onestopId ?? ""
        self.name = transitlandAgency.name
        self.url = transitlandAgency.website ?? ""
        self.timezone = transitlandAgency.timezone ?? "UTC"
    }
}

struct GTFSStaticData {
    let agencies: [TransitAgency]
    let routes: [GTFSRoute]
    let stops: [GTFSStop]
    let schedules: [GFSSchedule]
}

struct AgencyGTFSData {
    let routes: [GTFSRoute]
    let stops: [GTFSStop]
    let schedules: [GFSSchedule]
}

struct GTFSRoute {
    let id: String
    let agencyId: String
    let shortName: String
    let longName: String
    let type: Int
    let color: String
    let stopIds: [String]
}

struct GTFSStop {
    let id: String
    let name: String
    let location: CLLocationCoordinate2D
    let code: String
}

struct GFSSchedule {
    let tripId: String
    let routeId: String
    let stopId: String
    let arrivalTime: Date
    let departureTime: Date
}

struct GTFSRealtimeData {
    let vehiclePositions: [VehiclePosition]
    let tripUpdates: [TripUpdate]
    let alerts: [TransitAlert]
}

struct VehiclePosition {
    let id: String
    let routeId: String
    let location: CLLocationCoordinate2D
    let bearing: Double
    let timestamp: Date
    let occupancy: Occupancy
}

enum Occupancy: String, CaseIterable, Codable {
    case empty = "EMPTY"
    case manySeatsAvailable = "MANY_SEATS_AVAILABLE"
    case fewSeatsAvailable = "FEW_SEATS_AVAILABLE"
    case standingRoomOnly = "STANDING_ROOM_ONLY"
    case crushedStandingRoomOnly = "CRUSHED_STANDING_ROOM_ONLY"
    case full = "FULL"
}

struct TripUpdate {
    let tripId: String
    let routeId: String
    let delay: Int // Seconds
    let timestamp: Date
}

struct TransitAlert {
    let id: String
    let type: TransitAlertType
    let severity: TransitAlertSeverity
    let title: String
    let description: String
    let affectedRoutes: [String]
    let timestamp: Date
}

enum TransitAlertType: String, CaseIterable, Codable {
    case serviceChange = "SERVICE_CHANGE"
    case delay = "DELAY"
    case cancellation = "CANCELLATION"
    case emergency = "EMERGENCY"
    case maintenance = "MAINTENANCE"
}

enum TransitAlertSeverity: String, CaseIterable, Codable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case critical = "CRITICAL"
}

struct TransitlandData {
    let routes: [TransitlandRoute]
}

struct TransitlandRoute {
    let id: String
    let name: String
    let type: String
    let agencyId: String
    
    init(from transitlandRoute: TransitlandRouteResponse) {
        self.id = transitlandRoute.onestopId ?? ""
        self.name = transitlandRoute.name
        self.type = transitlandRoute.routeType ?? ""
        self.agencyId = transitlandRoute.operatedBy ?? ""
    }
}

// MARK: - API Response Models

struct TransitlandAgenciesResponse: Codable {
    let agencies: [TransitlandAgencyResponse]
}

struct TransitlandAgencyResponse: Codable {
    let onestopId: String?
    let name: String
    let website: String?
    let timezone: String?
}

struct TransitlandRoutesResponse: Codable {
    let routes: [TransitlandRouteResponse]
}

struct TransitlandRouteResponse: Codable {
    let onestopId: String?
    let name: String
    let routeType: String?
    let operatedBy: String?
}

// MARK: - Error Types

enum TransitError: Error {
    case invalidURL
    case apiError
    case decodingError
}
