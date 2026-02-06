//
//  LaunchAnimationView.swift
//  SafeRouteAI
//
//  Animated launch screen view that mimics the static storyboard
//  Provides smooth transitions and animations for a professional app launch experience
//

import SwiftUI

struct LaunchAnimationView: View {
    // MARK: - Animation State
    @State private var shieldScale: CGFloat = 0.8
    @State private var shieldOpacity: Double = 0.0
    @State private var titleOpacity: Double = 0.0
    @State private var subtitleOpacity: Double = 0.0
    @State private var routeProgress: CGFloat = 0.0
    @State private var glowScale: CGFloat = 0.8
    @State private var glowOpacity: Double = 0.0
    @State private var backgroundOpacity: Double = 1.0
    @State private var showLoadingElements: Bool = false
    @State private var gridLineProgress: CGFloat = 0.0
    @State private var routeLineOpacity: Double = 0.0
    @State private var goldenRouteProgress: CGFloat = 0.0
    @State private var goldenRouteOpacity: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0
    
    // MARK: - Animation Completion
    let onAnimationComplete: () -> Void
    
    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundView
            gridView
            goldenRouteView
            mainContentView
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    // MARK: - View Components
    private var backgroundView: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.0588, green: 0.1804, blue: 0.3490), // Deep blue
                Color(red: 0.1255, green: 0.2941, blue: 0.4706)  // Medium blue
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .opacity(backgroundOpacity)
        .ignoresSafeArea()
    }
    
    private var gridView: some View {
        ZStack {
            // Vertical lines - slide down
            ForEach(0..<Int(UIScreen.main.bounds.width / 20) + 1, id: \.self) { index in
                Rectangle()
                    .fill(Color.white.opacity(0.05 * backgroundOpacity))
                    .frame(width: 0.5, height: UIScreen.main.bounds.height)
                    .offset(y: -UIScreen.main.bounds.height + (UIScreen.main.bounds.height * gridLineProgress))
                    .position(x: CGFloat(index) * 20, y: UIScreen.main.bounds.height / 2)
                    .animation(.easeInOut(duration: 1.0), value: gridLineProgress)
            }
            
            // Horizontal lines - slide right
            ForEach(0..<Int(UIScreen.main.bounds.height / 20) + 1, id: \.self) { index in
                Rectangle()
                    .fill(Color.white.opacity(0.05 * backgroundOpacity))
                    .frame(width: UIScreen.main.bounds.width, height: 0.5)
                    .offset(x: -UIScreen.main.bounds.width + (UIScreen.main.bounds.width * gridLineProgress))
                    .position(x: UIScreen.main.bounds.width / 2, y: CGFloat(index) * 20)
                    .animation(.easeInOut(duration: 1.0), value: gridLineProgress)
            }
        }
        .ignoresSafeArea()
        .clipped()
    }
    
    @ViewBuilder
    private var goldenRouteView: some View {
        if showLoadingElements {
            goldenRoutePath
        }
    }
    
    private var goldenRoutePath: some View {
        mainGoldenPath
    }
    
    private var mainGoldenPath: some View {
        Path { path in
            let width = UIScreen.main.bounds.width
            let height = UIScreen.main.bounds.height
            
            // Create a path from left edge to right edge with angled bends
            path.move(to: CGPoint(x: 0, y: height * 0.15))
            path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.25))
            path.addLine(to: CGPoint(x: width * 0.35, y: height * 0.42))
            path.addLine(to: CGPoint(x: width * 0.55, y: height * 0.52))
            path.addLine(to: CGPoint(x: width * 0.72, y: height * 0.68))
            path.addLine(to: CGPoint(x: width * 0.85, y: height * 0.82))
            path.addLine(to: CGPoint(x: width, y: height * 0.88))
        }
        .trim(from: 0, to: goldenRouteProgress)
        .stroke(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.843, blue: 0.0), // Gold
                    Color(red: 1.0, green: 0.922, blue: 0.502), // Light gold
                    Color(red: 1.0, green: 0.843, blue: 0.0)  // Gold
                ]),
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(
                lineWidth: 4,
                lineCap: .round,
                lineJoin: .round
            )
        )
        .opacity(goldenRouteOpacity * backgroundOpacity)
        .shadow(color: Color(red: 1.0, green: 0.843, blue: 0.0).opacity(0.6 * backgroundOpacity), radius: 8, x: 0, y: 0)
        .scaleEffect(pulseScale)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseScale)
    }
    
    private var mainContentView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Shield icon with glow effect
            ZStack {
                // Glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.green.opacity(0.3),
                                Color.green.opacity(0.1),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(glowScale)
                    .opacity(glowOpacity)
                
                // Shield background circle
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .scaleEffect(shieldScale)
                    .opacity(shieldOpacity)
                
                // Shield icon
                Image(systemName: "shield.checkerboard")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(shieldScale)
                    .opacity(shieldOpacity)
            }
            
            // App title
            Text("SafeRouteAI")
                .font(.system(size: 42, weight: .heavy, design: .default))
                .foregroundColor(.white)
                .opacity(titleOpacity)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            // Subtitle
            Text("Find Your Safest Path")
                .font(.system(size: 18, weight: .medium, design: .default))
                .foregroundColor(.white.opacity(0.9))
                .opacity(subtitleOpacity)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            
            Spacer()
            
            // Loading elements
            if showLoadingElements {
                loadingElementsView
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var loadingElementsView: some View {
        VStack(spacing: 10) {
            // Progress bar with golden theme
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2 * backgroundOpacity))
                    .frame(width: 200, height: 4)
                
                // Progress fill with golden gradient
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.843, blue: 0.0),
                                Color(red: 1.0, green: 0.922, blue: 0.502)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 200 * goldenRouteProgress, height: 4)
                    .animation(.easeInOut(duration: 2.5), value: goldenRouteProgress)
                    .opacity(backgroundOpacity)
                    .shadow(color: Color(red: 1.0, green: 0.843, blue: 0.0).opacity(0.4 * backgroundOpacity), radius: 3, x: 0, y: 0)
            }
            
            // Loading text
            Text("Charting your safe route...")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.white.opacity(0.7 * backgroundOpacity))
        }
        .padding(.bottom, 50)
        .opacity(backgroundOpacity)
    }
    
    // MARK: - Animation Sequence
    private func startAnimationSequence() {
        // Phase 0: Grid lines animation (0-1.0s)
        withAnimation(.easeInOut(duration: 1.0)) {
            gridLineProgress = 1.0
        }
        
        // Phase 1: Shield appearance with glow (0.2-1.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.6)) {
                shieldOpacity = 1.0
                shieldScale = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.8)) {
                glowOpacity = 1.0
                glowScale = 1.2
            }
        }
        
        // Phase 2: Title appearance (0.6-1.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.6)) {
                titleOpacity = 1.0
            }
        }
        
        // Phase 3: Subtitle appearance (0.8-1.4s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.6)) {
                subtitleOpacity = 1.0
            }
        }
        
        // Phase 4: Show loading elements and start golden route (1.2-1.4s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showLoadingElements = true
                goldenRouteOpacity = 1.0
            }
            
            // Start pulsing effect
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
        
        // Phase 5: Animate golden route progress (1.4-3.9s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 2.5)) {
                goldenRouteProgress = 1.0
            }
        }
        
        // Phase 6: Fade out and transition (4.2-4.7s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            withAnimation(.easeOut(duration: 0.5)) {
                backgroundOpacity = 0.0
                shieldOpacity = 0.0
                titleOpacity = 0.0
                subtitleOpacity = 0.0
                glowOpacity = 0.0
                goldenRouteOpacity = 0.0
                gridLineProgress = 0.0
                pulseScale = 1.0
            }
            
            // Complete transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onAnimationComplete()
            }
        }
    }
}

// MARK: - Preview
struct LaunchAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchAnimationView {
            print("Animation completed")
        }
    }
}
