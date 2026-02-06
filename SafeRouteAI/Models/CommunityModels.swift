//
//  CommunityModels.swift
//  SafeRouteAI
//
//  Data models for community safety reports and user interactions
//  Designed to foster community engagement and safety awareness
//

import Foundation
import CoreLocation

// MARK: - Community Report
struct CommunityReport: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let reportType: ReportType
    let location: CLLocationCoordinate2D
    let address: String
    let timestamp: Date
    let userId: String
    let userDisplayName: String
    let severity: ReportSeverity
    let verified: Bool
    var helpfulVotes: Int
    let imageUrls: [String]?
    let tags: [String]
    
    // Computed properties
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var isRecent: Bool {
        timestamp > Date().addingTimeInterval(-86400) // Within 24 hours
    }
    
    var formattedLocation: String {
        address.isEmpty ? "Unknown Location" : address
    }
}

enum ReportType: String, CaseIterable, Codable {
    case safetyConcern = "Safety Concern"
    case lightingIssue = "Lighting Issue"
    case infrastructure = "Infrastructure"
    case positiveExperience = "Positive Experience"
    case emergency = "Emergency"
    case weatherHazard = "Weather Hazard"
    case trafficIssue = "Traffic Issue"
    case communityEvent = "Community Event"
    
    var icon: String {
        switch self {
        case .safetyConcern: return "exclamationmark.triangle"
        case .lightingIssue: return "light.max"
        case .infrastructure: return "wrench.and.screwdriver"
        case .positiveExperience: return "hand.thumbsup"
        case .emergency: return "phone.badge.waveform"
        case .weatherHazard: return "cloud.rain"
        case .trafficIssue: return "car"
        case .communityEvent: return "person.3"
        }
    }
    
    var color: String {
        switch self {
        case .safetyConcern: return "SafetyRed"
        case .lightingIssue: return "SafetyYellow"
        case .infrastructure: return "SafetyBlue"
        case .positiveExperience: return "SafetyGreen"
        case .emergency: return "SafetyRed"
        case .weatherHazard: return "SafetyBlue"
        case .trafficIssue: return "SafetyOrange"
        case .communityEvent: return "SafetyPurple"
        }
    }
}

enum ReportSeverity: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var description: String {
        return self.rawValue
    }

    var color: String {
        switch self {
        case .low: return "SafetyGreen"
        case .medium: return "SafetyYellow"
        case .high: return "SafetyOrange"
        case .critical: return "SafetyRed"
        }
    }
    
    var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

// MARK: - Community Event
struct CommunityEvent: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let location: CLLocationCoordinate2D
    let address: String
    let startTime: Date
    let endTime: Date
    let organizer: String
    let eventType: EventType
    let attendeeCount: Int
    let safetyRating: Double // Community-rated safety score
    let imageUrl: String?
    let tags: [String]
    let isPublic: Bool
    let requiresRegistration: Bool
    
    // Computed properties
    var isUpcoming: Bool {
        startTime > Date()
    }
    
    var isOngoing: Bool {
        let now = Date()
        return now >= startTime && now <= endTime
    }
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var formattedTime: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime, to: endTime)
    }
}

enum EventType: String, CaseIterable, Codable {
    case safetyWalk = "Safety Walk"
    case communityMeeting = "Community Meeting"
    case awarenessWorkshop = "Awareness Workshop"
    case neighborhoodWatch = "Neighborhood Watch"
    case cleanupEvent = "Cleanup Event"
    case safetyTraining = "Safety Training"
    case socialGathering = "Social Gathering"
    
    var icon: String {
        switch self {
        case .safetyWalk: return "figure.walk"
        case .communityMeeting: return "person.2"
        case .awarenessWorkshop: return "book"
        case .neighborhoodWatch: return "eye"
        case .cleanupEvent: return "leaf"
        case .safetyTraining: return "shield"
        case .socialGathering: return "party.popper"
        }
    }
}

// MARK: - User Profile
struct UserProfile: Identifiable, Codable {
    let id = UUID()
    let userId: String
    let displayName: String
    let avatarUrl: String?
    let joinDate: Date
    let reputationScore: Int
    let reportCount: Int
    let helpfulVotesReceived: Int
    let trustedReporter: Bool
    let communityRole: CommunityRole
    let bio: String?
    let interests: [String]
    let languages: [String]
    let accessibilityNeeds: [String]?
    
    // Computed properties
    var trustLevel: TrustLevel {
        if trustedReporter || reputationScore > 1000 {
            return .trusted
        } else if reputationScore > 500 {
            return .established
        } else if reputationScore > 100 {
            return .active
        } else {
            return .new
        }
    }
    
    var formattedJoinDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: joinDate)
    }
}

enum CommunityRole: String, CaseIterable, Codable {
    case member = "Community Member"
    case volunteer = "Volunteer"
    case moderator = "Moderator"
    case organizer = "Event Organizer"
    case safetyAmbassador = "Safety Ambassador"
    
    var icon: String {
        switch self {
        case .member: return "person"
        case .volunteer: return "heart"
        case .moderator: return "shield"
        case .organizer: return "calendar"
        case .safetyAmbassador: return "star.badge"
        }
    }
}

enum TrustLevel: String, CaseIterable {
    case new = "New Member"
    case active = "Active Member"
    case established = "Established Member"
    case trusted = "Trusted Member"
    
    var color: String {
        switch self {
        case .new: return "Gray"
        case .active: return "SafetyBlue"
        case .established: return "SafetyGreen"
        case .trusted: return "SafetyGold"
        }
    }
}

// MARK: - Community Statistics
struct CommunityStats: Codable {
    let totalReports: Int
    let activeUsers: Int
    let eventsThisMonth: Int
    let safetyImprovements: Int
    let averageResponseTime: TimeInterval
    let communityTrustScore: Double
    let recentActivity: [ActivityItem]
    let topContributors: [UserProfile]
    
    var formattedResponseTime: String {
        let minutes = Int(averageResponseTime) / 60
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            return "\(hours) hr"
        }
    }
}

struct ActivityItem: Identifiable, Codable {
    let id = UUID()
    let type: ActivityType
    let description: String
    let timestamp: Date
    let userName: String
    let location: String?
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

enum ActivityType: String, CaseIterable, Codable {
    case newReport = "New Report"
    case reportVerified = "Report Verified"
    case eventCreated = "Event Created"
    case safetyImprovement = "Safety Improvement"
    case communityMilestone = "Milestone"
    
    var icon: String {
        switch self {
        case .newReport: return "plus.circle"
        case .reportVerified: return "checkmark.circle"
        case .eventCreated: return "calendar.badge.plus"
        case .safetyImprovement: return "arrow.up.circle"
        case .communityMilestone: return "star.circle"
        }
    }
}
