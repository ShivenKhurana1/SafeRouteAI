//
//  GlassCard.swift
//  SafeRouteAI
//
//  Reusable glass-morphism card component with modern design
//  Provides consistent styling across the app with accessibility support
//

import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    var backgroundColor: Color = .white
    var cornerRadius: CGFloat = 20
    var blurRadius: CGFloat = 10
    var opacity: Double = 0.8
    var shadowRadius: CGFloat = 10
    var shadowColor: Color = .black
    var padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    
    init(
        backgroundColor: Color = .white,
        cornerRadius: CGFloat = 20,
        blurRadius: CGFloat = 10,
        opacity: Double = 0.8,
        shadowRadius: CGFloat = 10,
        shadowColor: Color = .black,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.blurRadius = blurRadius
        self.opacity = opacity
        self.shadowRadius = shadowRadius
        self.shadowColor = shadowColor
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                GlassBackground(
                    color: backgroundColor,
                    cornerRadius: cornerRadius,
                    blurRadius: blurRadius,
                    opacity: opacity
                )
            )
            .shadow(color: shadowColor.opacity(0.15), radius: shadowRadius, x: 0, y: 5)
            .cornerRadius(cornerRadius)
    }
}

struct GlassBackground: View {
    let color: Color
    let cornerRadius: CGFloat
    let blurRadius: CGFloat
    let opacity: Double
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(color.opacity(opacity))
            .background(
                BlurView(style: .systemMaterial)
                    .cornerRadius(cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Safety Score Card
struct SafetyScoreCard: View {
    /// Safety score on a 0–100 scale (higher is safer).
    let score: Double
    let safetyLevel: SafetyLevel
    let confidence: Double
    var showConfidence = true
    
    var body: some View {
        GlassCard(
            backgroundColor: safetyColor(),
            cornerRadius: 16,
            blurRadius: 8,
            opacity: 0.9
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: safetyIcon())
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if showConfidence {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Confidence")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("\(Int(confidence * 100))%")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Safety Score")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack(alignment: .bottom, spacing: 4) {
                        Text(String(format: "%.0f", score))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("/100")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Text(safetyLevel.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Safety Score \(Int(score)) out of 100, \(safetyLevel.rawValue) level")
        .accessibilityValue("Confidence \(Int(confidence * 100)) percent")
    }
    
    private func safetyColor() -> Color {
        switch safetyLevel {
        case .safe:
            return Color.green
        case .moderate:
            return Color.orange
        case .risky:
            return Color.red
        }
    }
    
    private func safetyIcon() -> String {
        switch safetyLevel {
        case .safe:
            return "shield.checkerboard"
        case .moderate:
            return "exclamationmark.triangle"
        case .risky:
            return "exclamationmark.octagon"
        }
    }
}

// MARK: - Route Card
struct RouteCard: View {
    let route: Route
    let isSelected: Bool
    let aiRiskFactors: [RiskFactor] // Add AI risk factors
    var onSelect: (() -> Void)?
    
    var body: some View {
        GlassCard(
            backgroundColor: isSelected ? Color.blue.opacity(0.1) : Color.white,
            cornerRadius: 16,
            blurRadius: 12,
            opacity: 0.85,
            shadowRadius: isSelected ? 12 : 8,
            padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(route.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("AI: \(Int(route.aiConfidence * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    SafetyBadge(level: route.safetyLevel)
                }
                
                // Route details
                HStack(spacing: 12) {
                    DetailItem(
                        icon: "figure.walk",
                        value: String(format: "%.1f", route.distanceInMiles),
                        unit: "mi"
                    )
                    
                    DetailItem(
                        icon: "clock",
                        value: String(format: "%.0f", route.timeInMinutes),
                        unit: "min"
                    )
                    
                    DetailItem(
                        icon: "exclamationmark.triangle",
                        value: "\(aiRiskFactors.count)",
                        unit: "risks"
                    )
                }
                
                // Risk factors if any
                if !aiRiskFactors.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Potential Risks")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ForEach(aiRiskFactors.prefix(2), id: \.id) { factor in
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundColor(Color(factor.severity.color))
                                    .font(.caption2)
                                
                                Text(factor.type.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 200)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onTapGesture {
            onSelect?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Route \(route.name), \(route.safetyLevel.rawValue) safety level")
        .accessibilityHint("Double tap to select this route")
    }
}

// MARK: - Safety Badge
struct SafetyBadge: View {
    let level: SafetyLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(level.color))
                .frame(width: 8, height: 8)
            
            Text(level.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(Color(level.color))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color(level.color).opacity(0.15))
        )
    }
}

// MARK: - Detail Item
struct DetailItem: View {
    let icon: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            
            HStack(alignment: .bottom, spacing: 1) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Report Card
struct ReportCard: View {
    let report: CommunityReport
    var onVote: ((Bool) -> Void)?
    
    @State private var isExpanded = false
    
    var body: some View {
        GlassCard(
            backgroundColor: Color(report.reportType.color).opacity(0.1),
            cornerRadius: 20,
            blurRadius: 10,
            opacity: 0.8
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: report.reportType.icon)
                        .font(.title2)
                        .foregroundColor(Color(report.reportType.color))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color(report.reportType.color).opacity(0.15))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Text(report.userDisplayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(report.timeAgo)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if report.verified {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                // Description
                Text(report.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(isExpanded ? nil : 3)
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
                
                if !isExpanded && report.description.count > 150 {
                    Button("Show more") {
                        isExpanded = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                // Location and tags
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(report.formattedLocation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !report.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(report.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(Color.secondary.opacity(0.1))
                                        )
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                // Actions
                HStack {
                    Button(action: {
                        onVote?(true)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.thumbsup")
                            Text("\(report.helpfulVotes)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    
                    Button(action: {
                        onVote?(false)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.right")
                            Text("Reply")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                    
                    Spacer()
                    
                    ShareButton(report: report)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(report.reportType.rawValue) report: \(report.title)")
        .accessibilityHint("Double tap to expand or collapse")
    }
}

// MARK: - Share Button
struct ShareButton: View {
    let report: CommunityReport
    @State private var showShareSheet = false
    
    var body: some View {
        Button(action: {
            showShareSheet = true
        }) {
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(.secondary)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                )
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: ["Check out this community safety report: \(report.title) - \(report.description)"])
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}