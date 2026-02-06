//
//  ElevationDataSource.swift
//  SafeRouteAI
//
//  Elevation data for route optimization and difficulty scoring
//  Critical for pedestrian and cyclist route planning
//

import Foundation
import CoreLocation

class ElevationDataSource: DataSource {
    let name = "Elevation Data"
    let priority = 2 // High priority for route optimization
    let refreshInterval: TimeInterval = 3600 // 1 hour (elevation doesn't change)
    var isEnabled = true
    
    private var lastFetch: Date?
    private var cachedData: SafetyData?
    private let apiKey = "FREE" // Open Elevation API is free
    
    func fetchData(for location: CLLocationCoordinate2D, radius: Double = 1000.0) async throws -> SafetyData {
        print("⛰️ [ElevationDataSource] Starting data fetch for location: \(location)")
        
        // Generate elevation grid for the area
        let elevationData = try await fetchElevationData(for: location, radius: radius)
        
        print("⛰️ [ElevationDataSource] Generated elevation data: \(elevationData.samplePoints.count) points")
        print("⛰️ [ElevationDataSource] Max elevation: \(elevationData.maxElevation)m")
        print("⛰️ [ElevationDataSource] Min elevation: \(elevationData.minElevation)m")
        print("⛰️ [ElevationDataSource] Created elevation data: max \(elevationData.maxElevation)m, range \(elevationData.elevationRange)m")
        
        // Generate incidents based on elevation hazards
        let incidents = createElevationIncidents(from: elevationData, location: location)
        let infrastructureIssues = createElevationInfrastructureIssues(from: elevationData, location: location)
        
        print("⛰️ [ElevationDataSource] Generated \(incidents.count) incidents, \(infrastructureIssues.count) issues")
        
        // Environmental factors with elevation consideration
        let environmentalFactors = EnvironmentalFactors(
            weatherCondition: .clear, // Will be updated by weather data source
            visibility: calculateVisibilityBasedOnElevation(elevationData),
            temperature: 20.0,
            windSpeed: calculateWindSpeedBasedOnElevation(elevationData),
            precipitation: 0.0,
            timeOfDay: getCurrentTimeOfDay(),
            dayOfWeek: getCurrentDayOfWeek(),
            lightingLevel: calculateLightingLevel()
        )
        
        let safetyData = SafetyData(
            source: "Elevation Data",
            timestamp: Date(),
            location: location,
            incidents: incidents,
            infrastructureIssues: infrastructureIssues,
            environmentalFactors: environmentalFactors,
            confidence: 0.95
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
    
    // MARK: - Elevation Data Fetching
    
    private func fetchElevationData(for location: CLLocationCoordinate2D, radius: Double) async throws -> ElevationData {
        // Generate sample points along potential routes
        let samplePoints = generateSamplePoints(center: location, radius: radius, count: 20)
        
        // Use Open Elevation API (FREE - 1000 requests/day)
        let locations = samplePoints.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
        let urlString = "https://api.open-elevation.com/api/v1/lookup?locations=\(locations)"
        
        guard let url = URL(string: urlString) else {
            throw ElevationError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ElevationError.apiError
            }
            
            let decoder = JSONDecoder()
            let elevationResponse = try decoder.decode(OpenElevationResponse.self, from: data)
            
            return ElevationData(
                location: location,
                samplePoints: samplePoints,
                elevations: elevationResponse.results.map { $0.elevation },
                timestamp: Date()
            )
        } catch {
            // Fallback to USGS API (FREE - unlimited)
            return try await fetchUSGSElevationData(for: location, radius: radius)
        }
    }
    
    private func fetchUSGSElevationData(for location: CLLocationCoordinate2D, radius: Double) async throws -> ElevationData {
        let samplePoints = generateSamplePoints(center: location, radius: radius, count: 20)
        var elevations: [Double] = []
        
        for point in samplePoints {
            let urlString = "https://nationalmap.gov/epqs/pq.php?x=\(point.longitude)&y=\(point.latitude)&units=Meters&output=json"
            
            guard let url = URL(string: urlString) else {
                throw ElevationError.invalidURL
            }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoder = JSONDecoder()
                let usgsResponse = try decoder.decode(USGSResponse.self, from: data)
                
                if let elevation = usgsResponse.elevationQuery?.elevation {
                    elevations.append(elevation)
                } else {
                    elevations.append(0.0) // Fallback
                }
            } catch {
                elevations.append(0.0) // Fallback
            }
        }
        
        return ElevationData(
            location: location,
            samplePoints: samplePoints,
            elevations: elevations,
            timestamp: Date()
        )
    }
    
    // MARK: - Incident Creation
    
    private func createElevationIncidents(from elevationData: ElevationData, location: CLLocationCoordinate2D) -> [SafetyIncident] {
        var incidents: [SafetyIncident] = []
        
        // Calculate elevation changes
        let elevationChanges = calculateElevationChanges(elevationData.elevations)
        let maxElevationChange = elevationChanges.max() ?? 0
        let averageElevation = elevationData.elevations.reduce(0, +) / Double(elevationData.elevations.count)
        
        // Steep grade incidents for cyclists
        if maxElevationChange > 50.0 { // More than 50m elevation change
            incidents.append(SafetyIncident(
                type: .infrastructureIssue,
                severity: .medium,
                location: location,
                timestamp: Date(),
                description: "Steep elevation changes in area - challenging for cyclists",
                radius: 300.0,
                weight: 0.6
            ))
        }
        
        // Very steep areas for walkers
        if maxElevationChange > 100.0 { // More than 100m elevation change
            incidents.append(SafetyIncident(
                type: .infrastructureIssue,
                severity: .high,
                location: location,
                timestamp: Date(),
                description: "Very steep terrain - challenging for pedestrians",
                radius: 400.0,
                weight: 0.8
            ))
        }
        
        // High altitude considerations
        if averageElevation > 1500.0 { // Above 1500m
            incidents.append(SafetyIncident(
                type: .weatherHazard,
                severity: .low,
                location: location,
                timestamp: Date(),
                description: "High elevation area - consider weather conditions",
                radius: 500.0,
                weight: 0.4
            ))
        }
        
        return incidents
    }
    
    private func createElevationInfrastructureIssues(from elevationData: ElevationData, location: CLLocationCoordinate2D) -> [InfrastructureIssue] {
        var issues: [InfrastructureIssue] = []
        
        // Calculate steep grades
        let steepGrades = identifySteepGrades(elevationData)
        
        for grade in steepGrades {
            issues.append(InfrastructureIssue(
                type: .roadSurface,
                severity: grade.percentage > 15.0 ? .high : .medium,
                location: grade.location,
                timestamp: Date(),
                description: "Steep grade (\(String(format: "%.1f", grade.percentage))%) - challenging terrain",
                estimatedResolutionDate: nil, // Permanent terrain feature
                affectedArea: Double.pi * 100 * 100 // 100m radius
            ))
        }
        
        return issues
    }
    
    // MARK: - Helper Functions
    
    private func generateSamplePoints(center: CLLocationCoordinate2D, radius: Double, count: Int) -> [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = []
        
        // Generate points in a grid pattern
        let gridSize = Int(sqrt(Double(count)))
        let stepSize = (radius * 2) / Double(gridSize)
        
        for i in 0..<gridSize {
            for j in 0..<gridSize {
                let lat = center.latitude - radius + (Double(i) * stepSize)
                let lon = center.longitude - radius + (Double(j) * stepSize)
                
                points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
        }
        
        return points
    }
    
    private func calculateElevationChanges(_ elevations: [Double]) -> [Double] {
        var changes: [Double] = []
        
        for i in 1..<elevations.count {
            changes.append(abs(elevations[i] - elevations[i-1]))
        }
        
        return changes
    }
    
    private func identifySteepGrades(_ elevationData: ElevationData) -> [SteepGrade] {
        var steepGrades: [SteepGrade] = []
        
        for i in 1..<elevationData.elevations.count {
            let elevationChange = abs(elevationData.elevations[i] - elevationData.elevations[i-1])
            let distance = calculateDistance(elevationData.samplePoints[i-1], elevationData.samplePoints[i])
            let grade = (elevationChange / distance) * 100 // Percentage
            
            if grade > 8.0 { // More than 8% grade is considered steep
                steepGrades.append(SteepGrade(
                    location: elevationData.samplePoints[i],
                    percentage: grade,
                    elevationChange: elevationChange
                ))
            }
        }
        
        return steepGrades
    }
    
    private func calculateDistance(_ point1: CLLocationCoordinate2D, _ point2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: point1.latitude, longitude: point1.longitude)
        let location2 = CLLocation(latitude: point2.latitude, longitude: point2.longitude)
        return location1.distance(from: location2)
    }
    
    private func calculateVisibilityBasedOnElevation(_ elevationData: ElevationData) -> Double {
        let averageElevation = elevationData.elevations.reduce(0, +) / Double(elevationData.elevations.count)
        
        // Higher elevation = better visibility (usually)
        if averageElevation > 1000.0 {
            return 1500.0
        } else if averageElevation > 500.0 {
            return 1000.0
        } else {
            return 800.0
        }
    }
    
    private func calculateWindSpeedBasedOnElevation(_ elevationData: ElevationData) -> Double {
        let averageElevation = elevationData.elevations.reduce(0, +) / Double(elevationData.elevations.count)
        
        // Higher elevation = more wind (generally)
        let baseWindSpeed = 10.0
        let elevationFactor = min(averageElevation / 1000.0, 2.0) // Max 2x wind speed
        
        return baseWindSpeed * (1.0 + elevationFactor * 0.5)
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
}

// MARK: - Data Models

struct ElevationData {
    let location: CLLocationCoordinate2D
    let samplePoints: [CLLocationCoordinate2D]
    let elevations: [Double]
    let timestamp: Date
    
    var averageElevation: Double {
        return elevations.reduce(0, +) / Double(elevations.count)
    }
    
    var maxElevation: Double {
        return elevations.max() ?? 0
    }
    
    var minElevation: Double {
        return elevations.min() ?? 0
    }
    
    var elevationRange: Double {
        return maxElevation - minElevation
    }
    
    var maxElevationChange: Double {
        var maxChange: Double = 0
        for i in 1..<elevations.count {
            let change = abs(elevations[i] - elevations[i-1])
            maxChange = max(maxChange, change)
        }
        return maxChange
    }
}

struct SteepGrade {
    let location: CLLocationCoordinate2D
    let percentage: Double
    let elevationChange: Double
}

// MARK: - API Response Models

struct OpenElevationResponse: Codable {
    let results: [OpenElevationResult]
}

struct OpenElevationResult: Codable {
    let latitude: Double
    let longitude: Double
    let elevation: Double
}

struct USGSResponse: Codable {
    let elevationQuery: USGSQuery?
    
    enum CodingKeys: String, CodingKey {
        case elevationQuery = "USGS_Elevation_Point_Query_Service"
    }
}

struct USGSQuery: Codable {
    let elevation: Double?
    
    enum CodingKeys: String, CodingKey {
        case elevation = "Elevation"
    }
}

// MARK: - Error Types

enum ElevationError: Error {
    case invalidURL
    case apiError
    case decodingError
}
