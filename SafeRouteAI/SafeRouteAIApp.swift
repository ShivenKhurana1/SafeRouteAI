//
//  SafeRouteAIApp.swift
//  SafeRouteAI
//
//  Main app entry point with state management
//  Manages app-wide state and dependencies with animated launch screen
//

import SwiftUI

@main
struct SafeRouteAIApp: App {
    // MARK: - App State
    @StateObject private var locationManager = LocationManager()
    @StateObject private var safetyDataManager = SafetyDataManager()
    @State private var showLaunchAnimation = true
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app content
                ContentView()
                    .environmentObject(locationManager)
                    .environmentObject(safetyDataManager)
                    .opacity(showLaunchAnimation ? 0 : 1)
                
                // Animated launch screen overlay
                if showLaunchAnimation {
                    LaunchAnimationView {
                        // Animation completion callback
                        withAnimation(.easeOut(duration: 0.3)) {
                            showLaunchAnimation = false
                        }
                    }
                    .transition(.opacity)
                    .ignoresSafeArea()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showLaunchAnimation)
        }
    }
}
