//
//  SafetyDataManager.swift
//  SafeRouteAI
//
//  Manages safety data, community reports, and AI predictions
//  Provides centralized data access for the app
//

import Foundation
import Combine
import CoreLocation

class SafetyDataManager: ObservableObject {
    
    // Published data for SwiftUI
    @Published var communityReports: [CommunityReport] = []
    @Published var communityEvents: [CommunityEvent] = []
    @Published var userProfiles: [UserProfile] = []
    @Published var communityStats: CommunityStats?
    @Published var isLoading = false
    @Published var lastUpdate: Date?
    
    // AI and prediction data
    @Published var recentPredictions: [SafetyPredictionOutput] = []
    @Published var aiInsights: [AIInsight] = []
    
    // Real-time data sources
    private let externalDataManager = ExternalDataSourceManager()
    
    private var cancellables = Set<AnyCancellable>()
    private let predictionModel = SafetyPredictionModel()
    
    init() {
        loadSampleData()
        startDataRefreshTimer()
    }
    
    // MARK: - Public Access to ExternalDataManager
    
    /// Get access to the real-time external data manager
    func getExternalDataManager() -> ExternalDataSourceManager {
        return externalDataManager
    }
    
    // MARK: - Data Loading
    
    private func loadSampleData() {
        isLoading = true
        
        // Simulate network delay
        DispatchQueue.global(qos: .background).async { [weak self] in
            Thread.sleep(forTimeInterval: 0.5)
            
            DispatchQueue.main.async {
                self?.communityReports = self?.generateSampleReports() ?? []
                self?.communityEvents = self?.generateSampleEvents() ?? []
                self?.userProfiles = self?.generateSampleUsers() ?? []
                self?.communityStats = self?.generateSampleStats()
                self?.aiInsights = self?.generateSampleInsights() ?? []
                self?.isLoading = false
                self?.lastUpdate = Date()
            }
        }
    }
    
    private func startDataRefreshTimer() {
        // Refresh data every 5 minutes
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }
    
    func refreshData() {
        // Simulate data refresh
        DispatchQueue.global(qos: .background).async { [weak self] in
            Thread.sleep(forTimeInterval: 0.3)
            
            DispatchQueue.main.async {
                // Add some randomness to simulate real updates
                if Bool.random() {
                    self?.addRandomReport()
                }
                self?.lastUpdate = Date()
            }
        }
    }
    
    // MARK: - Sample Data Generation
    
    private func generateSampleReports() -> [CommunityReport] {
        let sampleReports = [
            CommunityReport(
                title: "Street Light Out",
                description: "Street light on 5th and Main is not working, making the intersection very dark at night.",
                reportType: .lightingIssue,
                location: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                address: "5th St & Main Ave",
                timestamp: Date().addingTimeInterval(-3600),
                userId: "user1",
                userDisplayName: "Sarah M.",
                severity: .medium,
                verified: true,
                helpfulVotes: 12,
                imageUrls: nil,
                tags: ["lighting", "intersection", "safety"]
            ),
            CommunityReport(
                title: "Safe Walk Home",
                description: "Walked home from work at 9 PM and felt very safe. Good lighting and people around.",
                reportType: .positiveExperience,
                location: CLLocationCoordinate2D(latitude: 40.7580, longitude: -73.9855),
                address: "Broadway & 42nd St",
                timestamp: Date().addingTimeInterval(-7200),
                userId: "user2",
                userDisplayName: "Mike R.",
                severity: .low,
                verified: false,
                helpfulVotes: 8,
                imageUrls: nil,
                tags: ["positive", "lighting", "community"]
            ),
            CommunityReport(
                title: "Construction Safety Concern",
                description: "Construction site lacks proper barriers and signage for pedestrian safety.",
                reportType: .infrastructure,
                location: CLLocationCoordinate2D(latitude: 40.7505, longitude: -73.9934),
                address: "7th Ave Construction Zone",
                timestamp: Date().addingTimeInterval(-10800),
                userId: "user3",
                userDisplayName: "Lisa K.",
                severity: .high,
                verified: true,
                helpfulVotes: 15,
                imageUrls: ["construction1.jpg"],
                tags: ["construction", "safety", "infrastructure"]
            ),
            CommunityReport(
                title: "Community Safety Walk",
                description: "Join us for a neighborhood safety walk this Saturday at 2 PM starting from City Hall.",
                reportType: .communityEvent,
                location: CLLocationCoordinate2D(latitude: 40.7614, longitude: -73.9776),
                address: "City Hall Plaza",
                timestamp: Date().addingTimeInterval(-86400),
                userId: "user4",
                userDisplayName: "Community Team",
                severity: .low,
                verified: true,
                helpfulVotes: 25,
                imageUrls: nil,
                tags: ["event", "community", "safety walk"]
            )
        ]
        
        return sampleReports
    }
    
    private func generateSampleEvents() -> [CommunityEvent] {
        let sampleEvents = [
            CommunityEvent(
                title: "Neighborhood Safety Meeting",
                description: "Monthly community meeting to discuss safety improvements and share updates.",
                location: CLLocationCoordinate2D(latitude: 40.7614, longitude: -73.9776),
                address: "Community Center, Main St",
                startTime: Date().addingTimeInterval(86400), // Tomorrow
                endTime: Date().addingTimeInterval(90000), // 4 hours later
                organizer: "Neighborhood Association",
                eventType: .communityMeeting,
                attendeeCount: 45,
                safetyRating: 4.8,
                imageUrl: "meeting.jpg",
                tags: ["meeting", "safety", "community"],
                isPublic: true,
                requiresRegistration: false
            ),
            CommunityEvent(
                title: "Self-Defense Workshop",
                description: "Free self-defense class for community members. All skill levels welcome.",
                location: CLLocationCoordinate2D(latitude: 40.7282, longitude: -73.9942),
                address: "Recreation Center",
                startTime: Date().addingTimeInterval(172800), // Day after tomorrow
                endTime: Date().addingTimeInterval(176400), // 10 hours later
                organizer: "Safety First Organization",
                eventType: .safetyTraining,
                attendeeCount: 28,
                safetyRating: 4.9,
                imageUrl: "workshop.jpg",
                tags: ["training", "self-defense", "safety"],
                isPublic: true,
                requiresRegistration: true
            )
        ]
        
        return sampleEvents
    }
    
    private func generateSampleUsers() -> [UserProfile] {
        let sampleUsers = [
            UserProfile(
                userId: "user1",
                displayName: "Sarah M.",
                avatarUrl: "avatar1.jpg",
                joinDate: Date().addingTimeInterval(-31536000), // 1 year ago
                reputationScore: 1250,
                reportCount: 23,
                helpfulVotesReceived: 156,
                trustedReporter: true,
                communityRole: .safetyAmbassador,
                bio: "Community safety advocate and neighborhood watch coordinator.",
                interests: ["safety", "community", "volunteering"],
                languages: ["English", "Spanish"],
                accessibilityNeeds: nil
            ),
            UserProfile(
                userId: "user2",
                displayName: "Mike R.",
                avatarUrl: "avatar2.jpg",
                joinDate: Date().addingTimeInterval(-15768000), // 6 months ago
                reputationScore: 680,
                reportCount: 12,
                helpfulVotesReceived: 89,
                trustedReporter: false,
                communityRole: .volunteer,
                bio: "Local resident passionate about making our streets safer for everyone.",
                interests: ["cycling", "urban planning", "safety"],
                languages: ["English"],
                accessibilityNeeds: nil
            )
        ]
        
        return sampleUsers
    }
    
    private func generateSampleStats() -> CommunityStats {
        CommunityStats(
            totalReports: 127,
            activeUsers: 342,
            eventsThisMonth: 8,
            safetyImprovements: 15,
            averageResponseTime: 1800, // 30 minutes
            communityTrustScore: 4.7,
            recentActivity: [
                ActivityItem(type: .newReport, description: "New lighting issue reported", 
                           timestamp: Date().addingTimeInterval(-600), userName: "Sarah M.", location: "5th & Main"),
                ActivityItem(type: .reportVerified, description: "Construction safety concern verified", 
                           timestamp: Date().addingTimeInterval(-1800), userName: "Community Team", location: "7th Ave"),
                ActivityItem(type: .eventCreated, description: "Safety workshop scheduled", 
                           timestamp: Date().addingTimeInterval(-3600), userName: "Mike R.", location: "Rec Center")
            ],
            topContributors: []
        )
    }
    
    private func generateSampleInsights() -> [AIInsight] {
        [
            AIInsight(
                title: "Lighting Improvements Needed",
                description: "AI analysis shows 40% improvement in safety scores when street lighting is adequate.",
                type: .infrastructure,
                confidence: 0.87,
                timestamp: Date().addingTimeInterval(-7200),
                dataPoints: ["Lighting correlation: 0.82", "Safety improvement: 40%", "Confidence: 87%"]
            ),
            AIInsight(
                title: "Peak Safety Hours Identified",
                description: "Community is safest between 10 AM and 6 PM based on incident data analysis.",
                type: .temporal,
                confidence: 0.92,
                timestamp: Date().addingTimeInterval(-14400),
                dataPoints: ["Peak safety: 10 AM - 6 PM", "Risk increase: 300% after 10 PM", "Confidence: 92%"]
            )
        ]
    }
    
    // MARK: - Data Management
    
    private func addRandomReport() {
        let randomReport = CommunityReport(
            title: "New Community Update",
            description: "Fresh community safety report generated by AI simulation.",
            reportType: [.safetyConcern, .positiveExperience, .infrastructure].randomElement()!,
            location: CLLocationCoordinate2D(
                latitude: 40.7128 + Double.random(in: -0.01...0.01),
                longitude: -74.0060 + Double.random(in: -0.01...0.01)
            ),
            address: "Random Location",
            timestamp: Date(),
            userId: "ai_user",
            userDisplayName: "Community AI",
            severity: ReportSeverity.allCases.randomElement()!,
            verified: Bool.random(),
            helpfulVotes: Int.random(in: 0...20),
            imageUrls: nil,
            tags: ["ai-generated", "simulation"]
        )
        
        communityReports.insert(randomReport, at: 0)
        
        // Keep only recent reports
        if communityReports.count > 50 {
            communityReports = Array(communityReports.prefix(50))
        }
    }
    
    // MARK: - Public Methods
    
    func addCommunityReport(_ report: CommunityReport) {
        communityReports.insert(report, at: 0)
    }
    
    func addCommunityEvent(_ event: CommunityEvent) {
        communityEvents.append(event)
    }
    
    func getSafetyPrediction(for location: CLLocationCoordinate2D) -> SafetyPredictionOutput {
        let input = SafetyDataProcessor.processLocationData(coordinate: location)
        return predictionModel.prediction(input: input)
    }
    
    func voteOnReport(_ reportId: UUID, helpful: Bool) {
        if let index = communityReports.firstIndex(where: { $0.id == reportId }) {
            if helpful {
                communityReports[index].helpfulVotes += 1
            } else {
                communityReports[index].helpfulVotes = max(0, communityReports[index].helpfulVotes - 1)
            }
        }
    }
}

// MARK: - AI Insight Model
struct AIInsight: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let type: SafetyInsightType
    let confidence: Double
    let timestamp: Date
    let dataPoints: [String]
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

enum SafetyInsightType: String, CaseIterable, Codable {
    case temporal = "Temporal Analysis"
    case spatial = "Spatial Analysis"
    case infrastructure = "Infrastructure"
    case community = "Community"
    case weather = "Weather"
    case behavioral = "Behavioral"
    
    var icon: String {
        switch self {
        case .temporal: return "clock"
        case .spatial: return "map"
        case .infrastructure: return "building.2"
        case .community: return "person.3"
        case .weather: return "cloud.sun"
        case .behavioral: return "brain.head.profile"
        }
    }
    
    var color: String {
        switch self {
        case .temporal: return "SafetyBlue"
        case .spatial: return "SafetyGreen"
        case .infrastructure: return "SafetyOrange"
        case .community: return "SafetyPurple"
        case .weather: return "SafetyCyan"
        case .behavioral: return "SafetyPink"
        }
    }
}