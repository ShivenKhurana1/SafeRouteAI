//
//  DataFusionEngine.swift
//  SafeRouteAI
//
//  Advanced data fusion algorithm that combines multiple safety signals
//  Uses weighted scoring, temporal analysis, and machine learning techniques
//

import Foundation
import CoreLocation

class DataFusionEngine {
    
    // MARK: - Configuration
    private let dataSourceWeights: [String: Double] = [
        "Crime Data": 0.35,        // Highest priority for safety
        "City Services (311)": 0.25, // Infrastructure issues
        "Weather Data": 0.20,      // Environmental factors
        "Traffic Data": 0.15,      // Traffic-related risks
        "Community Reports": 0.05  // User reports (lowest weight)
    ]
    
    private let temporalDecayFactors: [String: Double] = [
        "Crime Data": 0.8,         // Crime has lasting impact
        "City Services (311)": 0.6, // Infrastructure issues decay faster
        "Weather Data": 0.3,       // Weather changes quickly
        "Traffic Data": 0.4,       // Traffic is dynamic
        "Community Reports": 0.7   // Community reports have moderate persistence
    ]
    
    // MARK: - Main Fusion Methods
    
    /// Fuse multiple safety data sources into a comprehensive safety score
    func fuseSafetyData(_ dataSources: [SafetyData], for location: CLLocationCoordinate2D) -> FusedSafetyResult {
        var weightedScores: [String: Double] = [:]
        var totalWeight: Double = 0.0
        var allIncidents: [SafetyIncident] = []
        var allInfrastructureIssues: [InfrastructureIssue] = []
        var sourceConfidences: [String: Double] = [:]
        var riskFactors: [RiskFactor] = []
        
        // Process each data source
        for source in dataSources {
            let weight = dataSourceWeights[source.source] ?? 0.0
            let confidence = source.confidence
            
            // Calculate individual source score
            let sourceScore = calculateSourceScore(source, for: location)
            let temporalWeight = calculateTemporalWeight(source)
            let finalWeight = weight * temporalWeight * confidence
            
            weightedScores[source.source] = sourceScore
            sourceConfidences[source.source] = confidence
            totalWeight += finalWeight
            
            // Collect all incidents and issues
            allIncidents.append(contentsOf: source.incidents)
            allInfrastructureIssues.append(contentsOf: source.infrastructureIssues)
        }
        
        // Calculate fused safety score
        let fusedScore = totalWeight > 0 ? 
            weightedScores.reduce(0.0) { total, pair in
                let weight = dataSourceWeights[pair.key] ?? 0.0
                let temporalWeight = calculateTemporalWeight(dataSources.first { $0.source == pair.key } ?? dataSources[0])
                let confidence = sourceConfidences[pair.key] ?? 0.0
                return total + (pair.value * weight * temporalWeight * confidence)
            } / totalWeight : 0.5
        
        // Analyze risk factors
        riskFactors = analyzeRiskFactors(from: allIncidents, infrastructureIssues: allInfrastructureIssues, location: location)
        
        // Generate safety insights
        let insights = generateSafetyInsights(from: dataSources, incidents: allIncidents, location: location)
        
        return FusedSafetyResult(
            location: location,
            overallSafetyScore: fusedScore,
            safetyLevel: determineSafetyLevel(fusedScore),
            sourceScores: weightedScores,
            sourceConfidences: sourceConfidences,
            incidents: allIncidents,
            infrastructureIssues: allInfrastructureIssues,
            riskFactors: riskFactors,
            insights: insights,
            timestamp: Date(),
            dataQuality: calculateDataQuality(dataSources)
        )
    }
    
    /// Calculate safety score for a specific route with multiple waypoints
    func fuseRouteSafety(_ route: [CLLocationCoordinate2D], dataManager: ExternalDataSourceManager) async -> RouteSafetyResult {
        var waypointResults: [FusedSafetyResult] = []
        var totalRouteScore: Double = 0.0
        var routeInsights: [SafetyInsight] = []
        
        // Analyze each waypoint
        for (index, waypoint) in route.enumerated() {
            if let safetyData = await dataManager.getSafetyData(for: waypoint, radius: 200.0) {
                let result = fuseSafetyData([safetyData], for: waypoint)
                waypointResults.append(result)
                totalRouteScore += result.overallSafetyScore
                
                // Generate waypoint-specific insights
                if result.overallSafetyScore > 0.7 {
                    routeInsights.append(SafetyInsight(
                        type: .highRisk,
                        location: waypoint,
                        message: "High risk area detected at waypoint \(index + 1)",
                        severity: .high,
                        recommendations: generateRecommendations(for: result)
                    ))
                }
            }
        }
        
        // Calculate overall route safety
        let averageRouteScore = waypointResults.isEmpty ? 0.5 : totalRouteScore / Double(waypointResults.count)
        
        // Identify high-risk segments
        let highRiskSegments = identifyHighRiskSegments(waypointResults)
        
        // Generate route-level insights
        if averageRouteScore > 0.6 {
            routeInsights.append(SafetyInsight(
                type: .routeWarning,
                location: route.first ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                message: "This route passes through multiple high-risk areas",
                severity: .medium,
                recommendations: ["Consider alternative routes", "Travel during daylight hours", "Share your location with trusted contacts"]
            ))
        }
        
        return RouteSafetyResult(
            route: route,
            overallSafetyScore: averageRouteScore,
            safetyLevel: determineSafetyLevel(averageRouteScore),
            waypointResults: waypointResults,
            highRiskSegments: highRiskSegments,
            insights: routeInsights,
            timestamp: Date()
        )
    }
    
    // MARK: - Source Score Calculation
    
    private func calculateSourceScore(_ source: SafetyData, for location: CLLocationCoordinate2D) -> Double {
        var incidentScore: Double = 0.0
        var infrastructureScore: Double = 0.0
        
        // Calculate incident-based risk
        for incident in source.incidents {
            let distance = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: incident.location.latitude, longitude: incident.location.longitude))
            
            if distance <= incident.radius {
                let proximityFactor = 1.0 - (distance / incident.radius)
                let timeDecay = calculateTimeDecay(for: incident.timestamp)
                let incidentRisk = incident.weight * incident.severity.score * proximityFactor * timeDecay
                incidentScore += incidentRisk
            }
        }
        
        // Calculate infrastructure-based risk
        for issue in source.infrastructureIssues {
            let distance = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: issue.location.latitude, longitude: issue.location.longitude))
            
            let impactRadius = sqrt(issue.affectedArea / Double.pi)
            if distance <= impactRadius {
                let proximityFactor = 1.0 - (distance / impactRadius)
                let timeDecay = calculateTimeDecay(for: issue.timestamp)
                let infrastructureRisk = issue.type.safetyImpact * issue.severity.score * proximityFactor * timeDecay
                infrastructureScore += infrastructureRisk
            }
        }
        
        // Apply environmental factors
        let environmentalMultiplier = calculateEnvironmentalMultiplier(from: source.environmentalFactors)
        
        let totalScore = (incidentScore + infrastructureScore) * environmentalMultiplier
        
        // Normalize to 0.0-1.0 scale (higher = riskier)
        return min(max(totalScore, 0.0), 1.0)
    }
    
    private func calculateTemporalWeight(_ source: SafetyData) -> Double {
        let decayFactor = temporalDecayFactors[source.source] ?? 0.5
        let age = Date().timeIntervalSince(source.timestamp)
        let maxAge: Double = 3600 // 1 hour
        
        // Exponential decay based on data age
        let ageFactor = exp(-age / maxAge)
        return decayFactor * ageFactor + (1.0 - decayFactor)
    }
    
    private func calculateTimeDecay(for timestamp: Date) -> Double {
        let hoursSince = Date().timeIntervalSince(timestamp) / 3600
        
        switch hoursSince {
        case 0...1: return 1.0 // Last hour: full impact
        case 1...6: return 0.8 // Last 6 hours: high impact
        case 6...24: return 0.6 // Last day: medium impact
        case 24...72: return 0.4 // Last 3 days: low impact
        default: return 0.2 // Older: minimal impact
        }
    }
    
    private func calculateEnvironmentalMultiplier(from factors: EnvironmentalFactors) -> Double {
        var multiplier: Double = 1.0
        
        // Time of day factor
        multiplier *= factors.timeOfDay.safetyMultiplier
        
        // Day of week factor
        multiplier *= factors.dayOfWeek.activityLevel
        
        // Lighting factor
        multiplier *= factors.lightingLevel
        
        // Weather factor
        switch factors.weatherCondition {
        case .clear: multiplier *= 1.0
        case .cloudy: multiplier *= 0.95
        case .rainy, .snowy: multiplier *= 0.8
        case .foggy: multiplier *= 0.7
        case .stormy: multiplier *= 0.5
        }
        
        // Visibility factor
        if factors.visibility < 200 {
            multiplier *= 0.6
        } else if factors.visibility < 500 {
            multiplier *= 0.8
        }
        
        // Temperature factor
        if factors.temperature < -10 || factors.temperature > 35 {
            multiplier *= 0.8
        } else if factors.temperature < 0 || factors.temperature > 30 {
            multiplier *= 0.9
        }
        
        return multiplier
    }
    
    // MARK: - Risk Analysis
    
    private func analyzeRiskFactors(from incidents: [SafetyIncident], infrastructureIssues: [InfrastructureIssue], location: CLLocationCoordinate2D) -> [RiskFactor] {
        var riskFactors: [RiskFactor] = []
        
        // Analyze incident patterns
        let crimeIncidents = incidents.filter { $0.type == .crime }
        let lightingIncidents = incidents.filter { $0.type == .lightingIssue }
        let trafficIncidents = incidents.filter { $0.type == .trafficAccident }
        
        if crimeIncidents.count > 2 {
            riskFactors.append(RiskFactor(
                type: .highCrimeArea,
                severity: .high,
                location: location
            ))
        }
        
        if lightingIncidents.count > 1 {
            riskFactors.append(RiskFactor(
                type: .poorLighting,
                severity: .medium,
                location: location
            ))
        }
        
        if trafficIncidents.count > 1 {
            riskFactors.append(RiskFactor(
                type: .heavyTraffic,
                severity: .medium,
                location: location
            ))
        }
        
        // Analyze infrastructure issues
        let streetlightIssues = infrastructureIssues.filter { $0.type == .streetLight }
        let sidewalkIssues = infrastructureIssues.filter { $0.type == .sidewalk }
        let constructionIssues = infrastructureIssues.filter { $0.type == .construction }
        
        if streetlightIssues.count > 0 {
            riskFactors.append(RiskFactor(
                type: .poorLighting,
                severity: .medium,
                location: location
            ))
        }
        
        if sidewalkIssues.count > 1 {
            riskFactors.append(RiskFactor(
                type: .isolatedPath,
                severity: .medium,
                location: location
            ))
        }
        
        if constructionIssues.count > 0 {
            riskFactors.append(RiskFactor(
                type: .constructionZone,
                severity: .medium,
                location: location
            ))
        }
        
        return riskFactors
    }
    
    // MARK: - Insight Generation
    
    private func generateSafetyInsights(from dataSources: [SafetyData], incidents: [SafetyIncident], location: CLLocationCoordinate2D) -> [SafetyInsight] {
        var insights: [SafetyInsight] = []
        
        // Analyze temporal patterns
        let recentIncidents = incidents.filter { Date().timeIntervalSince($0.timestamp) < 24 * 3600 }
        if recentIncidents.count > 3 {
            insights.append(SafetyInsight(
                type: .temporal,
                location: location,
                message: "High number of recent incidents in past 24 hours",
                severity: .medium,
                recommendations: ["Exercise increased caution", "Consider alternative routes"]
            ))
        }
        
        // Analyze data source coverage
        let activeSources = dataSources.filter { $0.confidence > 0.5 }
        if activeSources.count < 3 {
            insights.append(SafetyInsight(
                type: .dataQuality,
                location: location,
                message: "Limited data sources available for this area",
                severity: .low,
                recommendations: ["Safety assessment based on limited data", "Exercise normal caution"]
            ))
        }
        
        return insights
    }
    
    private func generateRecommendations(for result: FusedSafetyResult) -> [String] {
        var recommendations: [String] = []
        
        if result.overallSafetyScore > 0.7 {
            recommendations.append("Consider alternative routes if available")
            recommendations.append("Travel during daylight hours")
            recommendations.append("Share your location with trusted contacts")
        }
        
        if result.overallSafetyScore > 0.5 {
            recommendations.append("Stay alert and aware of surroundings")
            recommendations.append("Use well-lit streets")
        }
        
        // Add specific recommendations based on risk factors
        for riskFactor in result.riskFactors {
            switch riskFactor.type {
            case .poorLighting:
                recommendations.append("Carry a flashlight or use phone light")
            case .highCrimeArea:
                recommendations.append("Avoid displaying valuables")
                recommendations.append("Walk with confidence and purpose")
            case .heavyTraffic:
                recommendations.append("Use designated crosswalks")
                recommendations.append("Make eye contact with drivers")
            case .constructionZone:
                recommendations.append("Follow posted detour signs")
                recommendations.append("Be aware of construction vehicles")
            default:
                break
            }
        }
        
        return Array(Set(recommendations)) // Remove duplicates
    }
    
    // MARK: - Helper Methods
    
    private func determineSafetyLevel(_ score: Double) -> SafetyLevel {
        switch score {
        case 0.0..<0.3: return .safe
        case 0.3..<0.7: return .moderate
        default: return .risky
        }
    }
    
    private func calculateDataQuality(_ dataSources: [SafetyData]) -> DataQuality {
        let averageConfidence = dataSources.isEmpty ? 0.0 : dataSources.map { $0.confidence }.reduce(0, +) / Double(dataSources.count)
        let sourceCount = dataSources.count
        let maxAge = dataSources.map { Date().timeIntervalSince($0.timestamp) }.max() ?? 0
        
        let qualityScore: Double
        if averageConfidence > 0.8 && sourceCount >= 3 && maxAge < 1800 {
            qualityScore = 1.0 // Excellent
        } else if averageConfidence > 0.6 && sourceCount >= 2 && maxAge < 3600 {
            qualityScore = 0.8 // Good
        } else if averageConfidence > 0.4 && sourceCount >= 1 && maxAge < 7200 {
            qualityScore = 0.6 // Fair
        } else {
            qualityScore = 0.4 // Poor
        }
        
        return DataQuality(
            score: qualityScore,
            confidence: averageConfidence,
            sourceCount: sourceCount,
            maxAge: maxAge
        )
    }
    
    private func identifyHighRiskSegments(_ waypointResults: [FusedSafetyResult]) -> [HighRiskSegment] {
        var segments: [HighRiskSegment] = []
        
        for (index, result) in waypointResults.enumerated() {
            if result.overallSafetyScore > 0.7 {
                segments.append(HighRiskSegment(
                    startIndex: index,
                    endIndex: index,
                    riskScore: result.overallSafetyScore,
                    primaryRisk: result.riskFactors.first?.type ?? .highCrimeArea,
                    recommendations: generateRecommendations(for: result)
                ))
            }
        }
        
        return segments
    }
}

// MARK: - Result Models

struct FusedSafetyResult {
    let location: CLLocationCoordinate2D
    let overallSafetyScore: Double // 0.0-1.0 (higher = riskier)
    let safetyLevel: SafetyLevel
    let sourceScores: [String: Double]
    let sourceConfidences: [String: Double]
    let incidents: [SafetyIncident]
    let infrastructureIssues: [InfrastructureIssue]
    let riskFactors: [RiskFactor]
    let insights: [SafetyInsight]
    let timestamp: Date
    let dataQuality: DataQuality
}

struct RouteSafetyResult {
    let route: [CLLocationCoordinate2D]
    let overallSafetyScore: Double
    let safetyLevel: SafetyLevel
    let waypointResults: [FusedSafetyResult]
    let highRiskSegments: [HighRiskSegment]
    let insights: [SafetyInsight]
    let timestamp: Date
}

struct SafetyInsight {
    let type: InsightType
    let location: CLLocationCoordinate2D
    let message: String
    let severity: InsightSeverity
    let recommendations: [String]
}

struct HighRiskSegment {
    let startIndex: Int
    let endIndex: Int
    let riskScore: Double
    let primaryRisk: RiskType
    let recommendations: [String]
}

struct DataQuality {
    let score: Double // 0.0-1.0
    let confidence: Double
    let sourceCount: Int
    let maxAge: Double // seconds
    
    var level: String {
        switch score {
        case 0.8...1.0: return "Excellent"
        case 0.6..<0.8: return "Good"
        case 0.4..<0.6: return "Fair"
        default: return "Poor"
        }
    }
}

enum InsightType: String, CaseIterable {
    case temporal = "Temporal Pattern"
    case spatial = "Spatial Analysis"
    case dataQuality = "Data Quality"
    case highRisk = "High Risk Area"
    case routeWarning = "Route Warning"
    
    var icon: String {
        switch self {
        case .temporal: return "clock"
        case .spatial: return "map"
        case .dataQuality: return "info.circle"
        case .highRisk: return "exclamationmark.triangle"
        case .routeWarning: return "signpost.warning"
        }
    }
}

enum InsightSeverity: String, CaseIterable {
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
