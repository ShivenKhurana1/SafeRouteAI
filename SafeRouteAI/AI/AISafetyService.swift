//
//  AISafetyService.swift
//  SafeRouteAI
//
//  Lightweight backend abstraction for AI-powered route safety.
//  Currently returns mocked responses but is structured so a real
//  network implementation can replace the internals later.
//

import Foundation
import CoreLocation

/// Abstraction over the AI safety backend.
///
/// In a production build this would use URLSession to call:
///   - GET /predict_safety?start=&end=
///   - POST /summarize_route?route_data=
/// For now we parse a static JSON payload that matches the
/// expected backend response and return it asynchronously.
final class AISafetyService {
    static let shared = AISafetyService()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Predicts an overall safety score for a route between two points.
    /// Uses REAL safety calculations with real-time data sources.
    func predictSafety(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        externalDataManager: ExternalDataSourceManager? = nil,
        completion: @escaping (RouteSafety) -> Void
    ) {
        // Calculate REAL safety score using our prediction model with real-time data
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
            let (safetyScore, confidence, riskFactors) = Self.calculateRealSafetyScore(start: start, end: end, externalDataManager: externalDataManager)
            let summary = Self.generateSafetySummary(safetyScore: safetyScore)
            
            let routeSafety = RouteSafety(
                start: start,
                end: end,
                score: safetyScore,
                summary: summary,
                confidence: confidence,
                riskFactors: Array(riskFactors)
            )
            DispatchQueue.main.async {
                completion(routeSafety)
            }
        }
    }
    
    /// Produces an AI explanation for a fully specified route.
    /// Uses REAL route analysis with real-time data sources.
    func summarizeRoute(
        route: Route,
        externalDataManager: ExternalDataSourceManager? = nil,
        completion: @escaping (RouteSafety) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3) {
            let (safetyScore, confidence, riskFactors) = Self.calculateRealRouteSafety(route: route, externalDataManager: externalDataManager)
            let summary = Self.generateSafetySummary(safetyScore: safetyScore)
            
            let routeSafety = RouteSafety(
                start: route.startPoint.coordinate,
                end: route.endPoint.coordinate,
                score: safetyScore,
                summary: summary,
                confidence: confidence,
                riskFactors: Array(riskFactors)
            )
            DispatchQueue.main.async {
                completion(routeSafety)
            }
        }
    }
    
    // MARK: - Request Builders (placeholders)
    
    private func makePredictSafetyRequest(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D
    ) -> URLRequest {
        // These query parameters mirror the documented backend interface.
        let startParam = "\(start.latitude),\(start.longitude)"
        let endParam = "\(end.latitude),\(end.longitude)"
        let url = URL(string: "https://api.saferoute.ai/predict_safety?start=\(startParam)&end=\(endParam)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return request
    }
    
    private func makeSummarizeRouteRequest(route: Route) -> URLRequest {
        let url = URL(string: "https://api.saferoute.ai/summarize_route?route_data=")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // In a real implementation we would JSON-encode the route here.
        return request
    }
    
    // MARK: - REAL Safety Calculations
    
    /// Calculate REAL safety score between two points using actual data sources
    private static func calculateRealSafetyScore(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D, externalDataManager: ExternalDataSourceManager? = nil) -> (score: Int, confidence: Double, riskFactors: Set<String>) {
        print("🔍 AI Service: Calculating real safety score for route")
        print("  📍 Start: \(start.latitude), \(start.longitude)")
        print("  🎯 End: \(end.latitude), \(end.longitude)")
        
        let predictionModel = SafetyPredictionModel()
        
        // Calculate safety for multiple points along the route
        let midPoint = CLLocationCoordinate2D(
            latitude: (start.latitude + end.latitude) / 2,
            longitude: (start.longitude + end.longitude) / 2
        )
        
        // Get safety predictions for start, middle, and end points with real-time data
        let startInput = SafetyDataProcessor.processLocationData(coordinate: start, externalDataManager: externalDataManager)
        let midInput = SafetyDataProcessor.processLocationData(coordinate: midPoint, externalDataManager: externalDataManager)
        let endInput = SafetyDataProcessor.processLocationData(coordinate: end, externalDataManager: externalDataManager)
        
        let startPrediction = predictionModel.prediction(input: startInput)
        let midPrediction = predictionModel.prediction(input: midInput)
        let endPrediction = predictionModel.prediction(input: endInput)
        
        // Average the safety scores (convert from 0-1 unsafe scale to 0-100 safe scale)
        let averageUnsafeScore = (startPrediction.safetyScore + midPrediction.safetyScore + endPrediction.safetyScore) / 3.0
        let safetyScore = Int((1.0 - averageUnsafeScore) * 100)
        
        // Average the confidence scores
        let averageConfidence = (startPrediction.confidence + midPrediction.confidence + endPrediction.confidence) / 3.0
        
        // Collect all risk factors
        var allRiskFactors: Set<String> = []
        allRiskFactors.formUnion(startPrediction.riskFactors)
        allRiskFactors.formUnion(midPrediction.riskFactors)
        allRiskFactors.formUnion(endPrediction.riskFactors)
        
        print("  📊 Individual Scores:")
        print("    Start: \(String(format: "%.1f", (1.0 - startPrediction.safetyScore) * 100))/100 (Confidence: \(String(format: "%.1f", startPrediction.confidence * 100))%)")
        print("    Middle: \(String(format: "%.1f", (1.0 - midPrediction.safetyScore) * 100))/100 (Confidence: \(String(format: "%.1f", midPrediction.confidence * 100))%)")
        print("    End: \(String(format: "%.1f", (1.0 - endPrediction.safetyScore) * 100))/100 (Confidence: \(String(format: "%.1f", endPrediction.confidence * 100))%)")
        print("  🎯 Final Safety Score: \(safetyScore)/100")
        print("  🎖️ Final Confidence: \(String(format: "%.1f", averageConfidence * 100))%")
        print("  ⚠️ Total Risk Factors: \(allRiskFactors.count)")
        
        return (max(1, min(100, safetyScore)), averageConfidence, allRiskFactors)
    }
    
    /// Calculate REAL safety score for a complete route based on its waypoints
    private static func calculateRealRouteSafety(route: Route, externalDataManager: ExternalDataSourceManager? = nil) -> (score: Int, confidence: Double, riskFactors: Set<String>) {
        print("🔍 AI Service: Analyzing complete route safety")
        print("  🛣️ Route: \(route.name)")
        print("  📍 Waypoints: \(route.waypoints.count)")
        
        guard !route.waypoints.isEmpty else {
            print("  ⚠️ No waypoints available, using midpoint calculation")
            return calculateRealSafetyScore(start: route.startPoint.coordinate, end: route.endPoint.coordinate, externalDataManager: externalDataManager)
        }
        
        // Sample waypoints for analysis (take every 5th waypoint to avoid too many calculations)
        let sampledWaypoints = Array(route.waypoints.enumerated().compactMap { index, waypoint in
            index % 5 == 0 ? waypoint : nil
        })
        
        print("  📊 Analyzing \(sampledWaypoints.count) sample waypoints")
        
        var totalSafetyScore = 0.0
        var totalConfidence = 0.0
        var allRiskFactors: Set<String> = []
        
        for waypoint in sampledWaypoints {
            let input = SafetyDataProcessor.processLocationData(coordinate: waypoint.coordinate, externalDataManager: externalDataManager)
            let prediction = SafetyPredictionModel().prediction(input: input)
            
            totalSafetyScore += (1.0 - prediction.safetyScore) // Convert to safe scale
            totalConfidence += prediction.confidence
            allRiskFactors.formUnion(prediction.riskFactors)
        }
        
        let averageSafetyScore = totalSafetyScore / Double(sampledWaypoints.count)
        let averageConfidence = totalConfidence / Double(sampledWaypoints.count)
        let finalScore = Int(averageSafetyScore * 100)
        
        print("  📈 Average Safety Score: \(String(format: "%.1f", averageSafetyScore * 100))/100")
        print("  🎖️ Average Confidence: \(String(format: "%.1f", averageConfidence * 100))%")
        print("  ⚠️ Risk Factors Found: \(allRiskFactors.count)")
        print("  🎯 Final Route Safety: \(finalScore)/100")
        
        return (max(1, min(100, finalScore)), averageConfidence, allRiskFactors)
    }
    
    /// Generate dynamic safety summary based on the actual score
    private static func generateSafetySummary(safetyScore: Int) -> String {
        print("📝 AI Service: Generating dynamic safety summary for score: \(safetyScore)")
        
        switch safetyScore {
        case 90...100:
            return "Excellent safety rating. Well-lit, low incident area with good infrastructure."
        case 80...89:
            return "Very safe route. Good lighting and low incident rate in the past month."
        case 70...79:
            return "Generally safe area. Normal precautions recommended."
        case 60...69:
            return "Moderate safety level. Some areas may require extra caution."
        case 50...59:
            return "Use caution. Some safety concerns identified along this route."
        case 40...49:
            return "Elevated risk. Consider alternative routes if available."
        case 30...39:
            return "High risk area. Avoid if possible or travel during daylight hours."
        case 20...29:
            return "Significant safety concerns. Not recommended for solo travel."
        case 10...19:
            return "Very high risk. Emergency services access limited."
        default:
            return "Extreme risk area. Avoid this route entirely."
        }
    }
}
