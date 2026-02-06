//
//  AboutView.swift
//  SafeRouteAI
//
//  About SafeRouteAI - Mission, Ethics, and Team
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Hero section
                        VStack(spacing: 24) {
                            // App icon
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "shield.checkerboard")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 8) {
                                Text("SafeRouteAI")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text("AI-Powered Route Safety")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                        
                        // Mission section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "target")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                
                                Text("Our Mission")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)
                            
                            GlassCard(
                                backgroundColor: .blue.opacity(0.1),
                                cornerRadius: 16,
                                blurRadius: 10,
                                opacity: 0.8,
                                padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
                            ) {
                                Text("To make urban navigation safer for everyone by leveraging AI to analyze environmental factors, community reports, and real-time data to recommend the safest walking and biking routes.")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Core values
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                
                                Text("Core Values")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 16) {
                                ValueCard(
                                    icon: "lock.shield.fill",
                                    title: "Privacy First",
                                    description: "Your location data never leaves your device. All processing happens locally to protect your privacy.",
                                    color: .green
                                )
                                
                                ValueCard(
                                    icon: "person.2.fill",
                                    title: "Community Driven",
                                    description: "Built by the community, for the community. Your safety reports help keep everyone safe.",
                                    color: .blue
                                )
                                
                                ValueCard(
                                    icon: "brain.head.profile",
                                    title: "AI Transparency",
                                    description: "We believe in transparent AI. Our safety scores are explained clearly with detailed breakdowns.",
                                    color: .purple
                                )
                                
                                ValueCard(
                                    icon: "globe",
                                    title: "Accessibility",
                                    description: "Safe routes should be available to everyone, regardless of ability or background.",
                                    color: .orange
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Technology section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "cpu.fill")
                                    .font(.title2)
                                    .foregroundColor(.purple)
                                
                                Text("How It Works")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 16) {
                                TechStepCard(
                                    number: 1,
                                    title: "AI Analysis",
                                    description: "Our CoreML model analyzes lighting, weather, crowd density, and historical incident data.",
                                    icon: "brain.head.profile"
                                )
                                
                                TechStepCard(
                                    number: 2,
                                    title: "Community Input",
                                    description: "Real-time safety reports from users like you provide current, hyperlocal information.",
                                    icon: "person.2.fill"
                                )
                                
                                TechStepCard(
                                    number: 3,
                                    title: "Route Optimization",
                                    description: "We combine AI predictions with community data to find the safest available route.",
                                    icon: "map.fill"
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Team section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "person.3.fill")
                                    .font(.title2)
                                    .foregroundColor(.teal)
                                
                                Text("Meet the Team")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)
                            
                            Text("SafeRouteAI is developed by a diverse team of AI researchers, urban planners, and safety advocates committed to making cities safer for everyone.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal)
                        }
                        .padding(.horizontal)
                        
                        // Contact section
                        VStack(spacing: 20) {
                            Text("Get Involved")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top)
                            
                            Text("Help us make SafeRouteAI better for everyone")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            HStack(spacing: 20) {
                                ContactButton(
                                    title: "Report Bug",
                                    icon: "ant.fill",
                                    color: .red
                                ) {
                                    // Open bug report
                                }
                                
                                ContactButton(
                                    title: "Feature Request",
                                    icon: "lightbulb.fill",
                                    color: .yellow
                                ) {
                                    // Open feature request
                                }
                                
                                ContactButton(
                                    title: "Contact Us",
                                    icon: "envelope.fill",
                                    color: .blue
                                ) {
                                    // Open contact form
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Footer
                        VStack(spacing: 8) {
                            Text("Made with ❤️ for safer communities")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("© 2024 SafeRouteAI. All rights reserved.")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ValueCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        GlassCard(
            backgroundColor: color.opacity(0.1),
            cornerRadius: 16,
            blurRadius: 10,
            opacity: 0.8,
            padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct TechStepCard: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        GlassCard(
            backgroundColor: .purple.opacity(0.1),
            cornerRadius: 16,
            blurRadius: 10,
            opacity: 0.8,
            padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            HStack(alignment: .top, spacing: 12) {
                // Number circle
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                    
                    Text("\(number)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: icon)
                            .font(.caption)
                            .foregroundColor(.purple)
                        
                        Text(title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ContactButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            GlassCard(
                backgroundColor: color.opacity(0.2),
                cornerRadius: 12,
                blurRadius: 8,
                opacity: 0.9,
                padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
            ) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                    
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
                .frame(width: 100)
            }
        }
    }
}

// MARK: - Preview
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}