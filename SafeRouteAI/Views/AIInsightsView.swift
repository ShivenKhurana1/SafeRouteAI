//
//  AIInsightsView.swift
//  SafeRouteAI
//
//  AI Insights Tab with safety analytics dashboard
//  Shows safety trends, incident reports, and AI model insights
//

import SwiftUI
// Note: Charts framework (iOS 16+) could be used here for advanced visualizations
// Currently using custom SwiftUI views for broader iOS compatibility

struct AIInsightsView: View {
    @EnvironmentObject var safetyDataManager: SafetyDataManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var selectedTimeRange = "7D"
    @State private var selectedMetric = "Safety Score"
    
    let timeRanges = ["24H", "7D", "30D", "90D"]
    let metrics = ["Safety Score", "Incidents", "Route Usage"]

    // Dynamic safety scores based on actual data
    private var safetyScores: [Double] {
        let reports = safetyDataManager.communityReports
        let timeRange = getTimeRangeInDays()
        
        // Generate scores based on recent reports
        return (0..<timeRange).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let dayReports = reports.filter { report in
                Calendar.current.isDate(report.timestamp, inSameDayAs: date)
            }
            
            // Calculate safety score based on report severity and count
            let baseScore: Double = 8.0
            let penalty = Double(dayReports.count) * 0.3
            let severityPenalty = dayReports.reduce(0.0) { total, report in
                total + Double(report.severity.priority) * 0.1
            }
            
            return max(3.0, min(10.0, baseScore - penalty - severityPenalty))
        }.reversed()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Time Range Selector
                    timeRangeSelector
                    
                    // Safety Score Trend Chart
                    safetyScoreChart
                    
                    // Incident Reports by Type
                    incidentReportsChart
                    
                    // Route Usage Patterns
                    routeUsageChart
                    
                    // AI Model Insights
                    aiModelInsights
                    
                    // Safety Factors Breakdown
                    safetyFactorsBreakdown
                    
                    // Data Sources
                    dataSourcesSection
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.large)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                    
                    Text("AI Safety Analytics")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Text("Machine learning insights from community data and environmental factors")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                
                HStack(spacing: 24) {
                    VStack(alignment: .leading) {
                        Text("\(safetyDataManager.communityReports.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Community Reports")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("\(locationManager.alternativeRoutes.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Analyzed Routes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("\(calculateAIConfidence())%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("AI Confidence")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("AI Safety Analytics Overview")
        .accessibilityHint("Machine learning insights from community data")
    }
    
    private var timeRangeSelector: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Time Range")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(timeRanges, id: \.self) { range in
                        Text(range)
                            .tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .accessibilityLabel("Select time range for analytics")
                
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(metrics, id: \.self) { metric in
                        Text(metric)
                            .tag(metric)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .accessibilityLabel("Select metric to display")
            }
        }
    }
    
    private var safetyScoreChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    Text("Safety Score Trend")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(safetyScores.first ?? 0) → \(safetyScores.last ?? 0)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                // Dynamic safety score chart
                SafetyScoreBars(scores: safetyScores, colorForScore: colorForScore)
                
                let scoreChange = calculateScoreChange()
                Text("Safety scores have \(scoreChange > 0 ? "improved" : "declined") \(abs(scoreChange))% this week")
                    .font(.caption)
                    .foregroundColor(scoreChange > 0 ? .green : .red)
                    .padding(.top, 8)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Safety Score Trend Chart")
        .accessibilityHint("Shows safety score changes over time")
    }

// Lightweight subview to reduce type-checking complexity in the chart
struct ScoreBar: View {
    let color: Color
    let height: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(height: height)
    }
}

struct SafetyScoreBars: View {
    let scores: [Double]
    let colorForScore: (Double) -> Color
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(scores.indices, id: \.self) { index in
                    let score = scores[index]
                    let height = CGFloat(30 + index * 2)
                    ScoreBar(color: colorForScore(score), height: height)
                }
            }
            .frame(height: 60)

            HStack {
                Text("Mon")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Sun")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
    
    private var incidentReportsChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                    
                    Text("Incident Reports by Type")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                VStack(spacing: 12) {
                    ForEach(getIncidentTypeData(), id: \.type) { incidentData in
                        IncidentTypeRow(
                            type: incidentData.type,
                            count: incidentData.count,
                            color: incidentData.color,
                            percentage: incidentData.percentage
                        )
                    }
                }
                
                Text("Total: \(safetyDataManager.communityReports.count) reports this week")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Incident Reports by Type")
        .accessibilityHint("Breakdown of different types of safety incidents reported")
    }
    
    private var routeUsageChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "map.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                    
                    Text("Route Usage Patterns")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                VStack(spacing: 12) {
                    ForEach(getRouteUsageData(), id: \.time) { routeData in
                        RouteUsageRow(
                            time: routeData.time,
                            usage: routeData.usage,
                            color: routeData.color
                        )
                    }
                }
                
                Text("Peak usage during evening commute hours")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Route Usage Patterns")
        .accessibilityHint("Shows when routes are most frequently used")
    }
    
    private var aiModelInsights: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20))
                        .foregroundColor(.purple)
                    
                    Text("AI Model Insights")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(getDynamicAIInsights(), id: \.id) { insight in
                        AIInsightRow(
                            icon: insight.icon,
                            title: insight.title,
                            description: insight.description,
                            impact: insight.impact
                        )
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("AI Model Insights")
        .accessibilityHint("Key factors that influence AI safety predictions")
    }
    
    private var safetyFactorsBreakdown: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    Text("Safety Factors Breakdown")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                VStack(spacing: 12) {
                    ForEach(getSafetyFactors(), id: \.factor) { factorData in
                        SafetyFactorRow(
                            factor: factorData.factor,
                            score: factorData.score,
                            color: factorData.color
                        )
                    }
                }
                
                let overallScore = calculateOverallSafetyScore()
                Text("Overall Safety Score: \(String(format: "%.1f", overallScore))/10")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top, 8)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Safety Factors Breakdown")
        .accessibilityHint("Individual component scores that make up overall safety rating")
    }
    
    private var dataSourcesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "server.rack")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                    
                    Text("Data Sources")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    DataSourceRow(
                        name: "Community Reports",
                        description: "User-generated safety observations",
                        reliability: "High",
                        updateFrequency: "Real-time"
                    )
                    
                    DataSourceRow(
                        name: "Weather Services",
                        description: "Current weather conditions",
                        reliability: "High",
                        updateFrequency: "15 min"
                    )
                    
                    DataSourceRow(
                        name: "Public Infrastructure",
                        description: "Street lighting and road conditions",
                        reliability: "Medium",
                        updateFrequency: "Weekly"
                    )
                    
                    DataSourceRow(
                        name: "AI Model Predictions",
                        description: "Machine learning safety analysis",
                        reliability: "High",
                        updateFrequency: "Continuous"
                    )
                }
                
                Text("Last Updated: Just now")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Data Sources")
        .accessibilityHint("Information sources used for safety analysis")
    }
    
    // MARK: - Helper Functions
    
    private func getTimeRangeInDays() -> Int {
        switch selectedTimeRange {
        case "24H": return 1
        case "7D": return 7
        case "30D": return 30
        case "90D": return 90
        default: return 7
        }
    }
    
    private func calculateAIConfidence() -> Int {
        let reportsCount = safetyDataManager.communityReports.count
        let baseConfidence = 85
        let confidenceBoost = min(reportsCount * 2, 15)
        return baseConfidence + confidenceBoost
    }
    
    private func calculateScoreChange() -> Double {
        guard safetyScores.count >= 2 else { return 0.0 }
        let firstScore = safetyScores.first ?? 0
        let lastScore = safetyScores.last ?? 0
        return ((lastScore - firstScore) / firstScore) * 100
    }
    
    private func getIncidentTypeData() -> [IncidentTypeData] {
        let reports = safetyDataManager.communityReports
        let groupedReports = Dictionary(grouping: reports, by: { $0.reportType })
        
        return groupedReports.map { reportType, reports in
            let count = reports.count
            let totalReports = safetyDataManager.communityReports.count
            let percentage = totalReports > 0 ? Double(count) / Double(totalReports) : 0
            
            return IncidentTypeData(
                type: reportType.rawValue,
                count: count,
                color: colorForReportType(reportType),
                percentage: percentage
            )
        }.sorted { $0.count > $1.count }
    }
    
    private func getRouteUsageData() -> [RouteUsageData] {
        // Simulate route usage based on time and reports
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        return [
            RouteUsageData(time: "Morning (6-9 AM)", usage: currentHour >= 6 && currentHour <= 9 ? 85 : 65, color: .orange),
            RouteUsageData(time: "Midday (9 AM-3 PM)", usage: currentHour >= 9 && currentHour <= 15 ? 75 : 55, color: .yellow),
            RouteUsageData(time: "Evening (3-7 PM)", usage: currentHour >= 15 && currentHour <= 19 ? 92 : 70, color: .red),
            RouteUsageData(time: "Night (7 PM-12 AM)", usage: currentHour >= 19 && currentHour <= 23 ? 45 : 35, color: .purple),
            RouteUsageData(time: "Late Night (12-6 AM)", usage: currentHour >= 0 && currentHour <= 6 ? 25 : 20, color: .blue)
        ]
    }
    
    private func getDynamicAIInsights() -> [AIInsightData] {
        let reports = safetyDataManager.communityReports
        let lightingReports = reports.filter { $0.reportType == .lightingIssue }
        let safetyReports = reports.filter { $0.reportType == .safetyConcern }
        let infrastructureReports = reports.filter { $0.reportType == .infrastructure }
        
        return [
            AIInsightData(
                id: "lighting",
                icon: "light.max",
                title: "Lighting Impact",
                description: "Street lighting contributes \(calculateLightingImpact())% to safety predictions",
                impact: lightingReports.count > 5 ? "High" : "Medium"
            ),
            AIInsightData(
                id: "crowd",
                icon: "person.3.fill",
                title: "Crowd Density",
                description: "Areas with higher foot traffic show \(calculateCrowdImpact())% better safety scores",
                impact: "Medium"
            ),
            AIInsightData(
                id: "weather",
                icon: "cloud.rain.fill",
                title: "Weather Conditions",
                description: "Poor weather increases incident probability by \(calculateWeatherImpact())%",
                impact: "Medium"
            ),
            AIInsightData(
                id: "time",
                icon: "clock.fill",
                title: "Time of Day",
                description: "Night hours show \(calculateTimeImpact())% higher risk factors",
                impact: "High"
            )
        ]
    }
    
    private func getSafetyFactors() -> [SafetyFactorData] {
        let reports = safetyDataManager.communityReports
        let environmentalScore = calculateEnvironmentalScore(reports: reports)
        let communityScore = calculateCommunityScore(reports: reports)
        let infrastructureScore = calculateInfrastructureScore(reports: reports)
        let weatherScore = calculateWeatherScore()
        let timeScore = calculateTimeScore()
        
        return [
            SafetyFactorData(factor: "Environmental", score: environmentalScore, color: .green),
            SafetyFactorData(factor: "Community Reports", score: communityScore, color: .blue),
            SafetyFactorData(factor: "Infrastructure", score: infrastructureScore, color: .orange),
            SafetyFactorData(factor: "Weather", score: weatherScore, color: .purple),
            SafetyFactorData(factor: "Time Context", score: timeScore, color: .red)
        ]
    }
    
    private func calculateOverallSafetyScore() -> Double {
        let factors = getSafetyFactors()
        return factors.reduce(0.0) { $0 + $1.score } / Double(factors.count)
    }
    
    // MARK: - Calculation Helpers
    
    private func calculateLightingImpact() -> Int {
        let lightingReports = safetyDataManager.communityReports.filter { $0.reportType == .lightingIssue }
        let baseImpact = 25
        let additionalImpact = min(lightingReports.count * 3, 15)
        return baseImpact + additionalImpact
    }
    
    private func calculateCrowdImpact() -> Int {
        return 28 // Simulated crowd density impact
    }
    
    private func calculateWeatherImpact() -> Int {
        return 22 // Simulated weather impact
    }
    
    private func calculateTimeImpact() -> Int {
        let currentHour = Calendar.current.component(.hour, from: Date())
        return (currentHour >= 20 || currentHour <= 6) ? 45 : 25
    }
    
    private func calculateEnvironmentalScore(reports: [CommunityReport]) -> Double {
        let baseScore = 8.0
        let penalty = Double(reports.filter { $0.reportType == .weatherHazard }.count) * 0.2
        return max(5.0, baseScore - penalty)
    }
    
    private func calculateCommunityScore(reports: [CommunityReport]) -> Double {
        let baseScore = 8.0
        let verifiedReports = reports.filter { $0.verified }
        let bonus = Double(verifiedReports.count) * 0.1
        return min(10.0, baseScore + bonus)
    }
    
    private func calculateInfrastructureScore(reports: [CommunityReport]) -> Double {
        let baseScore = 7.5
        let penalty = Double(reports.filter { $0.reportType == .infrastructure }.count) * 0.3
        return max(5.0, baseScore - penalty)
    }
    
    private func calculateWeatherScore() -> Double {
        return 8.7 // Simulated weather score
    }
    
    private func calculateTimeScore() -> Double {
        let currentHour = Calendar.current.component(.hour, from: Date())
        return (currentHour >= 20 || currentHour <= 6) ? 6.9 : 8.2
    }
    
    private func colorForReportType(_ type: ReportType) -> Color {
        switch type {
        case .safetyConcern: return .red
        case .lightingIssue: return .orange
        case .infrastructure: return .blue
        case .positiveExperience: return .green
        case .emergency: return .red
        case .weatherHazard: return .purple
        case .trafficIssue: return .yellow
        case .communityEvent: return .pink
        }
    }
    
    private func colorForScore(score: Double) -> Color {
        switch score {
        case 0..<4:
            return .red
        case 4..<7:
            return .orange
        case 7..<9:
            return .yellow
        default:
            return .green
        }
    }
}

// MARK: - Supporting Views

struct IncidentTypeRow: View {
    let type: String
    let count: Int
    let color: Color
    let percentage: Double
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(type)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.3))
                    .frame(width: geometry.size.width * 0.6, height: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * 0.6 * percentage, height: 8)
                        , alignment: .leading
                    )
            }
            .frame(width: 60, height: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type): \(count) reports")
    }
}

struct RouteUsageRow: View {
    let time: String
    let usage: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(time)
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            Text("\(usage)%")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(width: 40, alignment: .trailing)
            
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.3))
                    .frame(width: geometry.size.width, height: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * Double(usage) / 100, height: 8)
                        , alignment: .leading
                    )
            }
            .frame(width: 80, height: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(time): \(usage)% usage")
    }
}

struct AIInsightRow: View {
    let icon: String
    let title: String
    let description: String
    let impact: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(impact)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(impact == "High" ? .red : impact == "Medium" ? .orange : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(impact == "High" ? Color.red.opacity(0.1) : impact == "Medium" ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
                        )
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description). Impact: \(impact)")
    }
}

struct SafetyFactorRow: View {
    let factor: String
    let score: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(factor)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(String(format: "%.1f", score))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(factor): \(String(format: "%.1f", score)) out of 10")
    }
}

struct DataSourceRow: View {
    let name: String
    let description: String
    let reliability: String
    let updateFrequency: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(reliability)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(reliability == "High" ? .green : reliability == "Medium" ? .orange : .red)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Updates: \(updateFrequency)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(description). Reliability: \(reliability). Updates: \(updateFrequency)")
    }
}

// MARK: - Data Structures

struct IncidentTypeData {
    let type: String
    let count: Int
    let color: Color
    let percentage: Double
}

struct RouteUsageData {
    let time: String
    let usage: Int
    let color: Color
}

struct AIInsightData {
    let id: String
    let icon: String
    let title: String
    let description: String
    let impact: String
}

struct SafetyFactorData {
    let factor: String
    let score: Double
    let color: Color
}

// MARK: - Preview
struct AIInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        AIInsightsView()
            .environmentObject(SafetyDataManager())
            .environmentObject(LocationManager())
    }
}
