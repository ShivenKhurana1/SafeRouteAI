//
//  ContentView.swift
//  SafeRouteAI
//
//  Main tab view with navigation structure
//  Contains Home, Community, AI Insights, and About tabs
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var safetyDataManager: SafetyDataManager
    
    @State private var selectedTab = 0
    @State private var showingOnboarding = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab - Map and Route Planning
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
                .environmentObject(locationManager)
                .environmentObject(safetyDataManager)
            
            // Community Tab - Safety Reports and Events
            CommunityView()
                .tabItem {
                    Label("Community", systemImage: "person.2.fill")
                }
                .tag(1)
                .environmentObject(safetyDataManager)
            
            // AI Insights Tab - Safety Analytics
            AIInsightsView()
                .tabItem {
                    Label("AI Insights", systemImage: "brain.head.profile")
                }
                .tag(2)
                .environmentObject(safetyDataManager)
            
            // About Tab - Mission and Ethics
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle.fill")
                }
                .tag(3)
            
            // Settings Tab - User Preferences
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .accentColor(.green) // Green accent aligns with safety theme
        .onAppear {
            checkFirstLaunch()
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
        }
        .edgesIgnoringSafeArea(.all) // Make app use full screen
    }
    
    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunchedBefore {
            showingOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    
    let pages = [
        OnboardingPage(
            title: "Welcome to SafeRouteAI",
            description: "Find the safest walking and biking routes in your city using AI-powered analysis",
            image: "shield.checkerboard",
            color: .blue
        ),
        OnboardingPage(
            title: "AI Safety Analysis",
            description: "Our AI analyzes lighting, weather, crowd density, and incident data to recommend safe routes",
            image: "brain.head.profile",
            color: .green
        ),
        OnboardingPage(
            title: "Community Driven",
            description: "Share safety reports and help your community stay informed and safe",
            image: "person.2.fill",
            color: .purple
        ),
        OnboardingPage(
            title: "Privacy First",
            description: "Your location data stays on your device. We prioritize your privacy and security",
            image: "lock.shield.fill",
            color: .orange
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [pages[currentPage].color.opacity(0.1), .white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Content
                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(pages[currentPage].color.opacity(0.2))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: pages[currentPage].image)
                            .font(.system(size: 60))
                            .foregroundColor(pages[currentPage].color)
                    }
                    
                    // Title
                    Text(pages[currentPage].title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                    
                    // Description
                    Text(pages[currentPage].description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? pages[currentPage].color : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                // Action button
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation(.easeInOut) {
                            currentPage += 1
                        }
                    } else {
                        dismiss()
                    }
                }) {
                    GlassCard(
                        backgroundColor: pages[currentPage].color.opacity(0.9),
                        cornerRadius: 25,
                        blurRadius: 10,
                        opacity: 0.95
                    ) {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                    }
                }
                
                Spacer()
                    .frame(height: 40)
            }
            .padding()
        }
    }
}


struct OnboardingPage {
    let title: String
    let description: String
    let image: String
    let color: Color
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(LocationManager())
            .environmentObject(SafetyDataManager())
    }
}
