//
//  HomeView.swift
//  SafeRouteAI
//
//  Main home view with MapKit integration and route visualization
//  Shows AI-recommended safe routes with color-coded safety levels
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

struct HomeView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var safetyDataManager: SafetyDataManager
    @AppStorage("preferSaferRoute") private var preferSaferRoute: Bool = true
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco as fallback
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    @State private var selectedRoute: Route?
    @State private var showingRouteDetails = false
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var showingDestinationSearch = false
    @State private var travelMode: TravelMode = .walking
    @State private var showSafetyLegend = false
    @State private var showInAppNavigation = false
    @State private var showSafetyHeatmap = true
    @State private var showingLocationAlert = false
    
    // Route options & AI metadata
    @State private var routes: [Route] = []
    @State private var routeSafetyInfo: [UUID: RouteSafety] = [:]
    @State private var routeRiskFactors: [UUID: [RiskFactor]] = [:] // Store AI-generated risk factors
    @State private var fastestRouteId: UUID?
    @State private var safestRouteId: UUID?
    @State private var isProcessingAI = false
    
    // Search fields
    @State private var startLocationText: String = "Current Location"
    @State private var destinationLocationText: String = ""
    
    // Map annotations
    @State private var annotations: [SafetyAnnotation] = []
    @State private var selectedRiskLocation: CLLocationCoordinate2D? // Add selected risk location
    
    private func makeMapView() -> some View {
        Map(
            coordinateRegion: $region,
            interactionModes: [.pan, .zoom, .pitch, .rotate],
            showsUserLocation: true
        )
        .onTapGesture { location in
            // Handle map tap for debugging and potential future features
            print("🗺️ Map tapped at: \(location)")
        }
        .onLongPressGesture {
            // Handle long press for potential future features
            print("🗺️ Map long pressed")
        }
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    print("🗺️ Map dragging: \(value.translation)")
                }
                .onEnded { value in
                    print("🗺️ Map drag ended")
                }
        )
        .overlay {
            // Show selected risk location marker
            if let riskLocation = selectedRiskLocation {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                            Text("Risk Location")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.9))
                        )
                        .foregroundColor(.white)
                        .padding()
                        .onTapGesture {
                            selectedRiskLocation = nil // Clear selection
                        }
                        .allowsHitTesting(true) // Ensure this overlay can be tapped
                    }
                }
                .allowsHitTesting(false) // Don't block map gestures
            }
        }
        .overlay {
            // Route polylines
            routeOverlayContent
                .allowsHitTesting(false) // Don't block map gestures
        }
        .overlay {
            // Safety Heatmap Overlay
            if showSafetyHeatmap {
                SafetyHeatmapOverlay(
                    region: region,
                    safetyData: safetyDataManager.communityReports,
                    opacity: 0.3
                )
                .allowsHitTesting(false) // Don't block map gestures
            }
        }
    }
    
    private var routeOverlayContent: some View {
        Canvas { context, size in
            // Debug logging
            print("🗺️ Route Overlay Debug:")
            print("  - selectedRoute: \(selectedRoute?.name ?? "none")")
            print("  - routes.count: \(routes.count)")
            print("  - showInAppNavigation: \(showInAppNavigation)")
            print("  - selectedRoute waypoints: \(selectedRoute?.waypoints.count ?? 0)")
            
            // Always show the selected route prominently
            if let selectedRoute = selectedRoute {
                print("  ✅ Drawing selected route: \(selectedRoute.name)")
                let points = selectedRoute.waypoints.map { waypoint in
                    coordinateToPoint(waypoint.coordinate, in: size)
                }
                
                if points.count >= 2 {
                    var path = Path()
                    path.move(to: points[0])
                    for i in 1..<points.count {
                        path.addLine(to: points[i])
                    }
                    
                    // Draw the selected route with prominent styling
                    context.stroke(
                        path,
                        with: .color(.blue),
                        style: StrokeStyle(
                            lineWidth: 8,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [10, 8] // Dotted pattern: 10pt dash, 8pt gap
                        )
                    )
                } else {
                    print("  ❌ Selected route has insufficient points: \(points.count)")
                }
            } else {
                print("  ❌ No selected route to display")
            }
            
            // Show other calculated routes (dimmed) when not in navigation
            if !showInAppNavigation {
                print("  📍 Drawing alternative routes (\(routes.count) routes)")
                for route in routes {
                    // Skip if this is the selected route (already drawn above)
                    if selectedRoute?.id == route.id { continue }
                    
                    let isSafest = route.id == safestRouteId
                    let isFastest = route.id == fastestRouteId
                    let color: Color = isSafest ? .green : (isFastest ? .gray.opacity(0.9) : .blue)
                    
                    // Convert route waypoints to screen coordinates
                    let points = route.waypoints.map { waypoint in
                        coordinateToPoint(waypoint.coordinate, in: size)
                    }
                    
                    // Create path from points
                    if points.count >= 2 {
                        var path = Path()
                        path.move(to: points[0])
                        for i in 1..<points.count {
                            path.addLine(to: points[i])
                        }
                        
                        // Draw the route with dotted style (dimmed)
                        context.stroke(
                            path,
                            with: .color(color.opacity(0.5)),
                            style: StrokeStyle(
                                lineWidth: 4,
                                lineCap: .round,
                                lineJoin: .round,
                                dash: [10, 8] // Dotted pattern: 10pt dash, 8pt gap
                            )
                        )
                    }
                }
            }
        }
    }
    
    private func coordinateToPoint(_ coordinate: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        let mapRegion = region
        let x = (coordinate.longitude - mapRegion.center.longitude) / mapRegion.span.longitudeDelta * size.width + size.width / 2
        let y = (mapRegion.center.latitude - coordinate.latitude) / mapRegion.span.latitudeDelta * size.height + size.height / 2
        return CGPoint(x: x, y: y)
    }
    
    private var topControls: some View {
        VStack(spacing: 8) {
            // Logo + current location + legend
            HStack(spacing: 8) {
                // SafeRouteAI logo placeholder
                GlassCard(
                    backgroundColor: Color.white,
                    cornerRadius: 12,
                    blurRadius: 8,
                    opacity: 0.95,
                    padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.checkerboard")
                            .font(.body)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("SafeRouteAI")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Safer routes")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer(minLength: 4)
                
                // Safety Legend Button
                Button(action: { showSafetyLegend = true }) {
                    GlassCard(
                        backgroundColor: Color.white.opacity(0.8),
                        cornerRadius: 12,
                        blurRadius: 8,
                        opacity: 0.9,
                        padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
                    ) {
                        Image(systemName: "info.circle.fill")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Location status in separate row
            GlassCard(
                backgroundColor: Color.white,
                cornerRadius: 16,
                blurRadius: 10,
                opacity: 0.95,
                padding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    if locationManager.isLocationAvailable {
                        Text("Location available")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Button(action: {
                            locationManager.requestLocationPermission()
                        }) {
                            Image(systemName: locationManager.isLocationAvailable ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(locationManager.isLocationAvailable ? .green : .orange)
                        }
                    }
                }
            }
            
            // Start / Destination fields
            GlassCard(
                backgroundColor: Color.white,
                cornerRadius: 16,
                blurRadius: 10,
                opacity: 0.95,
                padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
            ) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("Start")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        
                        TextField("Current Location", text: $startLocationText)
                            .disabled(true)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    
                    Divider()
                        .padding(.vertical, 1)
                    
                    HStack {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Text("Destination")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        
                        TextField("Search destination", text: $destinationLocationText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.caption)
                            .foregroundColor(.primary)
                            .onTapGesture {
                                // Use the dedicated search sheet for precise selection
                                showingDestinationSearch = true
                            }
                    }
                }
            }
            
            Spacer()
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Map View
            makeMapView()
                .ignoresSafeArea()
            
            // Top Controls
            topControls
            
            // Route Selection Panel
            routeSelectionPanel
            
            // Bottom Content
            bottomContent
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // Allow map gestures to pass through
                }
        )
        .overlay {
            if isProcessingAI {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .green))
                        Text("Analyzing routes for safety...")
                            .font(.footnote)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(16)
                }
            }
        }
        .sheet(isPresented: $showingDestinationSearch) {
            DestinationSearchView { coordinate in
                destinationCoordinate = coordinate
                calculateRoutes(to: coordinate)
            }
        }
        .sheet(isPresented: $showInAppNavigation) {
            if let route = selectedRoute,
               let current = locationManager.getCurrentLocation() {
                InAppNavigationView(
                    start: current,
                    end: route.waypoints.last?.coordinate ?? current,
                    travelMode: travelMode,
                    onEnd: {
                        showInAppNavigation = false
                    }
                )
            }
        }
        .sheet(isPresented: $showSafetyLegend) {
            SafetyLegendView()
        }
        .alert("Location Required", isPresented: $showingLocationAlert) {
            Button("Settings", action: openSettings)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("SafeRouteAI needs location access to provide accurate safety information and route recommendations.")
        }
        .onAppear {
            // Request location permission when view appears
            locationManager.requestLocationPermission()
            
            // Center on user location if available
            if let userLocation = locationManager.userLocation {
                withAnimation(.easeInOut(duration: 1.0)) {
                    region.center = userLocation.coordinate
                }
                print("📍 Map centered on user location: \(userLocation.coordinate)")
            }
        }
        .onChange(of: locationManager.userLocation) { oldLocation, newLocation in
            if let newLocation = newLocation {
                withAnimation(.easeInOut(duration: 1.0)) {
                    region.center = newLocation.coordinate
                }
                print("📍 Map updated to new user location: \(newLocation.coordinate)")
            }
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private var routeSelectionPanel: some View {
        Group {
            // Route Selection Panel
            if let route = selectedRoute {
                VStack(spacing: 0) {
                    // Back button at top - positioned next to info button area
                    HStack {
                        Spacer(minLength: 8) // Space from SafeRoute logo
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedRoute = nil // Clear selected route
                                routes = [] // Clear all calculated routes
                                routeSafetyInfo = [:] // Clear safety info
                                routeRiskFactors = [:] // Clear risk factors
                                destinationCoordinate = nil // Clear destination
                                destinationLocationText = "" // Clear destination text
                            }
                        }) {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.9))
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                )
                        }
                        
                        Spacer() // Push to the right but leave room for info button
                    }
                    .padding(.top, 12)
                    
                    Spacer()
                    
                    RouteDetailsPanel(
                        route: route,
                        routeSafety: routeSafetyInfo[route.id],
                        aiRiskFactors: routeRiskFactors[route.id] ?? [],
                        onClose: {
                            selectedRoute = nil
                        },
                        onNavigate: {
                            // Show in-app navigation sheet with live directions
                            showInAppNavigation = true
                        },
                        onNavigateToRisk: { location in
                            // Navigate to risk location on map
                            print("🗺️ RISK MAP NAVIGATION TRIGGERED!")
                            print("  - Location: \(location.latitude), \(location.longitude)")
                            selectedRiskLocation = location
                            withAnimation(.easeInOut(duration: 0.5)) {
                                region = MKCoordinateRegion(
                                    center: location,
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                )
                            }
                            print("  - Map updated to center on risk location")
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
                .zIndex(1)
            }
        }
    }
    
    private var bottomContent: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Route options list - positioned at bottom when routes are available
            if !routes.isEmpty && selectedRoute == nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(routes, id: \.id) { route in
                            RouteCard(
                                route: route,
                                isSelected: selectedRoute?.id == route.id,
                                aiRiskFactors: routeRiskFactors[route.id] ?? [],
                                onSelect: {
                                    selectedRoute = route
                                    // Center map on this route
                                    let coordinates = route.waypoints.map { $0.coordinate }
                                    region = calculateRegion(for: coordinates)
                                }
                            )
                            .frame(maxHeight: 160) // Increased height to prevent cropping
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8) // Small bottom padding to stay above safe area
                .background(
                    // Add a subtle background to separate from map
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
                .transition(.move(edge: .bottom)) // Animate from bottom
            }
            
            // Travel Mode Selector - only show when no route is selected and no routes available
            if selectedRoute == nil && routes.isEmpty {
                GlassCard(
                    backgroundColor: Color.white.opacity(0.2),
                    cornerRadius: 16,
                    blurRadius: 10,
                    opacity: 0.95,
                    padding: EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
                ) {
                    HStack(spacing: 6) {
                        ForEach(TravelMode.allCases, id: \.self) { mode in
                            TravelModeButton(
                                mode: mode,
                                isSelected: travelMode == mode,
                                action: {
                                    travelMode = mode
                                    recalculateRoutes()
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .transition(.move(edge: .bottom)) // Animate from bottom
            }
            
            // Main Action Buttons - only show when no route is selected and no routes available
            if selectedRoute == nil && routes.isEmpty {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        // Find Safe Route Button
                        Button(action: {
                            showingDestinationSearch = true
                        }) {
                            GlassCard(
                                backgroundColor: Color.green.opacity(0.9),
                                cornerRadius: 14,
                                blurRadius: 10,
                                opacity: 0.95,
                                padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
                            ) {
                                HStack(spacing: 6) {
                                    Image(systemName: "safari.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    
                                    Text("Find Safe Route")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .accessibilityLabel("Find Safe Route")
                        .accessibilityHint("Double tap to search for a destination and find the safest route")
                        
                        // Heatmap Toggle Button
                        Button(action: {
                            showSafetyHeatmap.toggle()
                        }) {
                            GlassCard(
                                backgroundColor: showSafetyHeatmap ? Color.orange.opacity(0.9) : Color.white.opacity(0.9),
                                cornerRadius: 14,
                                blurRadius: 10,
                                opacity: 0.95,
                                padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
                            ) {
                                HStack(spacing: 6) {
                                    Image(systemName: "map.fill")
                                        .font(.caption)
                                        .foregroundColor(showSafetyHeatmap ? .white : .orange)
                                    
                                    Text("Heatmap")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(showSafetyHeatmap ? .white : .primary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .accessibilityLabel("Safety Heatmap")
                        .accessibilityHint("Double tap to toggle safety heatmap overlay")
                        
                        // Quick Safety Check
                        Button(action: {
                            performQuickSafetyCheck()
                        }) {
                            GlassCard(
                                backgroundColor: Color.white.opacity(0.9),
                                cornerRadius: 14,
                                blurRadius: 10,
                                opacity: 0.95,
                                padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
                            ) {
                                HStack(spacing: 6) {
                                    Image(systemName: "shield.checkerboard")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    
                                    Text("Quick Check")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .accessibilityLabel("Quick Safety Check")
                        .accessibilityHint("Double tap to check the safety score of your current location")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8) // Small bottom padding to stay above safe area
                .transition(.move(edge: .bottom)) // Animate from bottom
            }
        }
        .ignoresSafeArea(.keyboard) // Ignore keyboard safe area
        .padding(.bottom, selectedRoute == nil ? 0 : 20) // No bottom padding when buttons are shown
    }
    
    // MARK: - Helper Functions
    
    private func setupInitialLocation() {
            // Try to get user location immediately
            if let userLocation = locationManager.userLocation {
                region.center = userLocation.coordinate
                print("📍 Map centered on user location: \(userLocation.coordinate)")
            } else {
                // Request location permission and try to get location
                locationManager.requestLocationPermission()
                
                // Set a temporary default (will be updated when location becomes available)
                region.center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
                print("📍 Using default location, waiting for user location...")
            }
        }
        
        private func loadCommunityAnnotations() {
            // Add community reports as map annotations
            annotations = safetyDataManager.communityReports.map { report in
                SafetyAnnotation(
                    coordinate: report.location,
                    title: report.title,
                    type: .report(report.reportType),
                    severity: report.severity
                )
            }
            
            // Add community events
            let eventAnnotations = safetyDataManager.communityEvents.map { event in
                SafetyAnnotation(
                    coordinate: event.location,
                    title: event.title,
                    type: .event(event.eventType),
                    severity: .low
                )
            }
            
            annotations.append(contentsOf: eventAnnotations)
        }
        
        private func calculateRoutes(to destination: CLLocationCoordinate2D) {
            print("\n🚀 === ROUTE CALCULATION STARTED ===")
            guard let startLocation = locationManager.getCurrentLocation() else {
                print("❌ ERROR: Current location not available")
                locationManager.locationError = "Current location not available"
                return
            }
            
            print("📍 Start Location: \(startLocation.latitude), \(startLocation.longitude)")
            print("🎯 Destination: \(destination.latitude), \(destination.longitude)")
            print("🚶 Travel Mode: \(travelMode)")
            print("🛡️ Prefer Safer Route: \(preferSaferRoute)")
            
            isProcessingAI = true
            routes = []
            routeSafetyInfo = [:]
            routeRiskFactors = [:] // Clear AI risk factors
            fastestRouteId = nil
            safestRouteId = nil
            
            // Log available safety data
            print("\n📊 AVAILABLE SAFETY DATA:")
            print("  - Community Reports: \(safetyDataManager.communityReports.count)")
            print("  - Community Events: \(safetyDataManager.communityEvents.count)")
            print("  - Recent Predictions: \(safetyDataManager.recentPredictions.count)")
            
            // Log sample safety reports
            if !safetyDataManager.communityReports.isEmpty {
                print("\n📋 SAMPLE SAFETY REPORTS:")
                for (index, report) in safetyDataManager.communityReports.enumerated() {
                    if index < 3 { // Show first 3 reports
                        print("  \(index + 1). \(report.title) - \(report.severity) - \(report.reportType.rawValue)")
                        print("     Location: \(report.location.latitude), \(report.location.longitude)")
                        print("     Description: \(report.description.prefix(100))...")
                    }
                }
            }
            
            // Enhanced AI-powered route calculation
            print("\n🤖 AI ROUTE CALCULATION IN PROGRESS...")
            locationManager.calculateSafeRoutes(
                from: startLocation,
                to: destination,
                travelMode: travelMode
            ) { newRoutes in
                print("\n📈 ROUTE CALCULATION RESULTS:")
                print("  - Total Routes Found: \(newRoutes.count)")
                
                // Determine fastest and safest routes using AI analysis
                routes = newRoutes
                fastestRouteId = newRoutes.min(by: { $0.estimatedTime < $1.estimatedTime })?.id
                safestRouteId = newRoutes.min(by: { $0.overallSafetyScore < $1.overallSafetyScore })?.id
                
                print("\n🏆 ROUTE ANALYSIS:")
                for (index, route) in newRoutes.enumerated() {
                    let isFastest = route.id == fastestRouteId
                    let isSafest = route.id == safestRouteId
                    let badges = "\(isFastest ? "⚡FASTEST " : "")\(isSafest ? "🛡️SAFEST " : "")"
                    
                    print("  Route \(index + 1): \(route.name)")
                    print("    \(badges)")
                    print("    ⏱️ Estimated Time: \(String(format: "%.0f", route.estimatedTime / 60)) min")
                    print("    🛡️ Safety Score: \(String(format: "%.2f", route.overallSafetyScore))")
                    print("    📍 Waypoints: \(route.waypoints.count)")
                    
                    // Log waypoint coordinates
                    if route.waypoints.count <= 5 {
                        for (wIndex, waypoint) in route.waypoints.enumerated() {
                            print("      WP\(wIndex + 1): \(waypoint.coordinate.latitude), \(waypoint.coordinate.longitude)")
                        }
                    } else {
                        print("      Start: \(route.waypoints.first!.coordinate.latitude), \(route.waypoints.first!.coordinate.longitude)")
                        print("      End: \(route.waypoints.last!.coordinate.latitude), \(route.waypoints.last!.coordinate.longitude)")
                        print("      ... \(route.waypoints.count - 2) intermediate waypoints")
                    }
                    print("")
                }
                
                if let preferredRoute = preferSaferRoute ? newRoutes.min(by: { $0.overallSafetyScore < $1.overallSafetyScore }) : newRoutes.min(by: { $0.estimatedTime < $1.estimatedTime }) {
                    selectedRoute = preferredRoute
                    let coordinates = preferredRoute.waypoints.map { $0.coordinate }
                    region = calculateRegion(for: coordinates)
                    
                    print("✅ SELECTED ROUTE: \(preferredRoute.name)")
                    print("   Selection Criteria: \(preferSaferRoute ? "Safest" : "Fastest")")
                    print("   Final Safety Score: \(String(format: "%.2f", preferredRoute.overallSafetyScore))")
                    print("   Final Time: \(String(format: "%.0f", preferredRoute.estimatedTime / 60)) min")
                }
                
                // Enhanced AI safety analysis for each route
                print("\n🔍 AI SAFETY ANALYSIS STARTED...")
                for route in routes {
                    let start = route.startPoint.coordinate
                    let end = route.endPoint.coordinate
                    let routeId = route.id
                    
                    print("  Analyzing route: \(route.name)")
                    
                    // Get comprehensive AI safety prediction
                    AISafetyService.shared.predictSafety(start: start, end: end) { safety in
                        routeSafetyInfo[routeId] = safety
                        
                        print("🤖 AI SAFETY RESULTS for \(route.name):")
                        print("  📊 Safety Score: \(safety.score)/100")
                        print("  🎖️ AI Confidence: \(String(format: "%.1f", safety.confidence * 100))%")
                        print("  📝 Summary: \(safety.summary)")
                        print("  ⚠️ Risk Factors: \(safety.riskFactors.count)")
                        for factor in safety.riskFactors {
                            print("    - \(factor)")
                        }
                        
                        // Log individual risk factors from the safety summary
                        print("    🔍 Risk Analysis:")
                        if safety.score < 30 {
                            print("      - High risk area detected")
                        } else if safety.score < 50 {
                            print("      - Moderate risk area")
                        } else if safety.score < 70 {
                            print("      - Low to moderate risk")
                        } else {
                            print("      - Generally safe area")
                        }
                        
                        // Add AI-powered risk factors to the route
                        if safety.score < 70 { // score is Int (0-100), not Double
                            print("    ⚠️ LOW SAFETY SCORE - Adding additional risk factors...")
                            let additionalFactors = generateAIRiskFactors(from: safety, route: route)
                            routeRiskFactors[routeId] = additionalFactors // Store the risk factors
                            print("    Generated \(additionalFactors.count) additional risk factors")
                            for factor in additionalFactors {
                                print("      + \(factor.type.rawValue) - \(factor.severity)")
                            }
                        } else {
                            // Still store empty risk factors for consistency
                            routeRiskFactors[routeId] = []
                        }
                        
                        print("  ✅ Safety analysis complete for \(route.name)")
                        print("")
                        
                        // Check if all routes have been processed
                        if routeSafetyInfo.count == routes.count {
                            print("🎉 ALL ROUTE SAFETY ANALYSIS COMPLETE!")
                            print("  Total routes analyzed: \(routeSafetyInfo.count)")
                            
                            // Final summary
                            print("\n📊 FINAL ROUTE SUMMARY:")
                            for route in routes {
                                if let safety = routeSafetyInfo[route.id] {
                                    let isFastest = route.id == fastestRouteId
                                    let isSafest = route.id == safestRouteId
                                    let isSelected = route.id == selectedRoute?.id
                                    let badges = "\(isFastest ? "⚡" : "")\(isSafest ? "🛡️" : "")\(isSelected ? "✅" : "")"
                                    
                                    print("  \(badges) \(route.name):")
                                    print("    Safety: \(safety.score)/100 (AI: \(String(format: "%.1f", safety.confidence * 100))%)")
                                    print("    Summary: \(safety.summary)")
                                    print("    Risks: \(safety.riskFactors.count)")
                                    print("    Time: \(String(format: "%.0f", route.estimatedTime / 60)) min")
                                }
                            }
                            
                            isProcessingAI = false
                            print("\n🏁 ROUTE CALCULATION COMPLETED ===\n")
                        }
                    }
                }
                
                // Fallback timeout in case AI analysis takes too long
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    if isProcessingAI {
                        print("⏰ TIMEOUT: AI safety analysis taking too long, proceeding with available data")
                        isProcessingAI = false
                    }
                }
            }
        }
        
        private func generateAIRiskFactors(from safety: RouteSafety, route: Route) -> [RiskFactor] {
            print("    🔧 GENERATING AI RISK FACTORS...")
            print("      Base Safety Score: \(safety.score)/100")
            print("      AI Confidence: \(String(format: "%.1f", safety.confidence * 100))%")
            print("      Safety Summary: \(safety.summary)")
            print("      Raw Risk Factors: \(safety.riskFactors.count)")
            print("      Route Waypoints: \(route.waypoints.count)")
            
            var factors: [RiskFactor] = []
            
            // Convert AI risk factors to RiskFactor objects with location information
            for (index, riskFactor) in safety.riskFactors.enumerated() {
                // Find a relevant waypoint for this risk factor
                let waypointIndex = min(index, route.waypoints.count - 1)
                let location = waypointIndex >= 0 ? route.waypoints[waypointIndex].coordinate : nil
                
                let factor = RiskFactor(
                    type: mapRiskFactorToType(riskFactor),
                    severity: mapRiskFactorToSeverity(riskFactor),
                    location: location,
                    waypointIndex: waypointIndex >= 0 ? waypointIndex : nil
                )
                factors.append(factor)
                print("      ➕ Added: \(riskFactor) -> \(factor.type.rawValue) (\(factor.severity)) at waypoint \(waypointIndex)")
            }
            
            // Add additional risk factors based on safety score if needed
            if safety.score < 30 && factors.isEmpty {
                let location = route.waypoints.first?.coordinate
                let factor = RiskFactor(
                    type: .poorLighting,
                    severity: .high,
                    location: location,
                    waypointIndex: 0
                )
                factors.append(factor)
                print("      ➕ Added: Poor Lighting (High) - Low score with no specific risks at waypoint 0")
            }
            
            print("      📊 Final Risk Factors: \(factors.count)")
            return factors
        }
        
        // Map AI risk factor strings to RiskType enum
        private func mapRiskFactorToType(_ riskFactor: String) -> RiskType {
            let lowercased = riskFactor.lowercased()
            
            if lowercased.contains("lighting") {
                return .poorLighting
            } else if lowercased.contains("incident") || lowercased.contains("crime") {
                return .highCrimeArea
            } else if lowercased.contains("traffic") {
                return .heavyTraffic
            } else if lowercased.contains("isolated") || lowercased.contains("foot traffic") {
                return .isolatedPath
            } else if lowercased.contains("weather") {
                return .weatherHazard
            } else if lowercased.contains("infrastructure") || lowercased.contains("construction") {
                return .constructionZone
            } else if lowercased.contains("emergency") {
                return .isolatedPath // Use available case
            } else if lowercased.contains("crowd") || lowercased.contains("crowded") {
                return .heavyTraffic // Use available case
            } else {
                return .lowVisibility // Use available case
            }
        }
        
        // Map AI risk factor strings to RiskSeverity
        private func mapRiskFactorToSeverity(_ riskFactor: String) -> RiskSeverity {
            let lowercased = riskFactor.lowercased()
            
            if lowercased.contains("high") || lowercased.contains("extreme") || lowercased.contains("severe") {
                return .high
            } else if lowercased.contains("moderate") || lowercased.contains("some") {
                return .medium
            } else {
                return .low
            }
        }
        
        private func recalculateRoutes() {
            if let destination = destinationCoordinate {
                calculateRoutes(to: destination)
            }
        }
        
        private func calculateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
            var minLat = 90.0
            var maxLat = -90.0
            var minLon = 180.0
            var maxLon = -180.0
            
            for coordinate in coordinates {
                minLat = min(minLat, coordinate.latitude)
                maxLat = max(maxLat, coordinate.latitude)
                minLon = min(minLon, coordinate.longitude)
                maxLon = max(maxLon, coordinate.longitude)
            }
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let span = MKCoordinateSpan(
                latitudeDelta: (maxLat - minLat) * 1.2,
                longitudeDelta: (maxLon - minLon) * 1.2
            )
            
            return MKCoordinateRegion(center: center, span: span)
        }
        
        private func performQuickSafetyCheck() {
            print("\n🛡️ === QUICK SAFETY CHECK STARTED ===")
            
            guard let currentLocation = locationManager.getCurrentLocation() else {
                print("❌ ERROR: Location not available for safety check")
                locationManager.locationError = "Location not available for safety check"
                return
            }
            
            print("📍 Current Location: \(currentLocation.latitude), \(currentLocation.longitude)")
            
            // Get safety prediction
            let prediction = safetyDataManager.getSafetyPrediction(for: currentLocation)
            
            print("📊 SAFETY PREDICTION RESULTS:")
            print("  🎯 Safety Score: \(String(format: "%.3f", prediction.safetyScore)) (0.0 = safest, 1.0 = most dangerous)")
            print("  📈 User-Friendly Score: \(String(format: "%.1f", (1.0 - prediction.safetyScore) * 10))/10")
            print("  � Current Location: \(currentLocation.latitude), \(currentLocation.longitude)")
            
            // Calculate safety level
            let safetyPercentage = (1.0 - prediction.safetyScore) * 100
            let safetyLevel: String
            if safetyPercentage >= 80 {
                safetyLevel = "🟢 EXCELLENT"
            } else if safetyPercentage >= 60 {
                safetyLevel = "🟡 GOOD"
            } else if safetyPercentage >= 40 {
                safetyLevel = "🟠 MODERATE"
            } else {
                safetyLevel = "🔴 POOR"
            }
            
            print("  🎖️ Safety Level: \(safetyLevel)")
            
            // Check nearby safety reports
            let nearbyReports = safetyDataManager.communityReports.filter { report in
                let distance = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
                    .distance(from: CLLocation(latitude: report.location.latitude, longitude: report.location.longitude))
                return distance < 500 // Within 500 meters
            }
            
            print("  📋 Nearby Safety Reports (500m radius): \(nearbyReports.count)")
            for (index, report) in nearbyReports.enumerated() {
                if index < 5 { // Show first 5
                    let distance = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
                        .distance(from: CLLocation(latitude: report.location.latitude, longitude: report.location.longitude))
                    print("    \(index + 1). \(report.title) - \(report.severity) - \(String(format: "%.0f", distance))m away")
                    print("       Type: \(report.reportType.rawValue)")
                    print("       Description: \(report.description.prefix(80))...")
                }
            }
            
            // Show safety check result
            let userFriendlyScore = String(format: "%.1f", (1.0 - prediction.safetyScore) * 10)
            locationManager.locationError = "Current area safety score: \(userFriendlyScore)/10 (\(safetyLevel))"
            
            print("✅ QUICK SAFETY CHECK COMPLETED")
            print("   Final Message: \(userFriendlyScore)/10 (\(safetyLevel))")
            print("🛡️ === QUICK SAFETY CHECK ENDED ===\n")
        }
        
        private func startNavigation() {
            if let route = selectedRoute {
                print("Starting navigation for route: \(route.name)")
                let destinationPlacemark = MKPlacemark(coordinate: route.endPoint.coordinate)
                let destinationItem = MKMapItem(placemark: destinationPlacemark)
                destinationItem.name = route.name
                let launchOptions = [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
                    MKLaunchOptionsShowsTrafficKey: true
                ] as [String : Any]
                DispatchQueue.main.async {
                    let lat = route.endPoint.latitude
                    let lon = route.endPoint.longitude
                    if let url = URL(string: "maps://?saddr=Current%20Location&daddr=\(lat),\(lon)&dirflg=w") {
                        UIApplication.shared.open(url, options: [:]) { success in
                            if !success {
                                MKMapItem.openMaps(
                                    with: [MKMapItem.forCurrentLocation(), destinationItem],
                                    launchOptions: launchOptions
                                )
                            }
                        }
                    } else {
                        MKMapItem.openMaps(
                            with: [MKMapItem.forCurrentLocation(), destinationItem],
                            launchOptions: launchOptions
                        )
                    }
                }
            }
        }
        
        private func endNavigation() {
            print("Navigation ended")
        }

    
    }

// MARK: - In-App Navigation (Map + Steps)

// Extension to get coordinates from MKPolyline
extension MKPolyline {
    func coordinates() -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
    
    func coordinate(at progress: CGFloat) -> CLLocationCoordinate2D {
        let coords = coordinates()
        guard !coords.isEmpty else { return kCLLocationCoordinate2DInvalid }
        
        let clampedProgress = max(0, min(1, progress))
        let index = Int(clampedProgress * CGFloat(coords.count - 1))
        return coords[index]
    }
}

@MainActor
final class InAppNavViewModel: ObservableObject {
    @Published var route: MKRoute?
    @Published var steps: [MKRoute.Step] = []
    @Published var currentStepIndex: Int = 0
    @Published var isCalculating = false
    @Published var errorMessage: String?
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isSimulating = false
    @Published var distanceToNextManeuver: Double = 0
    @Published var eta: TimeInterval = 0
        
        var currentStep: MKRoute.Step? {
            guard currentStepIndex < steps.count else { return nil }
            return steps[currentStepIndex]
        }
        
        private var simulationTimer: Timer?
        
        func calculate(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D, travelMode: TravelMode) {
            isCalculating = true
            errorMessage = nil
            currentStepIndex = 0
            userLocation = start
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
            request.transportType = {
                switch travelMode {
                case .walking: return .walking
                case .biking: return .walking
                case .wheelchair: return .walking
                }
            }()
            request.requestsAlternateRoutes = false
            let directions = MKDirections(request: request)
            directions.calculate { [weak self] response, error in
                guard let self = self else { return }
                Task { @MainActor in
                    self.isCalculating = false
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    if let route = response?.routes.first {
                        self.route = route
                        self.steps = route.steps.filter { !$0.instructions.isEmpty }
                        self.eta = route.expectedTravelTime
                    } else {
                        self.errorMessage = "No route found"
                    }
                }
            }
        }
        
        func startSimulation() {
            guard !isSimulating else { return } // Remove unused route parameter
            isSimulating = true
            
            simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.simulateProgress()
                }
            }
        }
        
        func stopSimulation() {
            isSimulating = false
            simulationTimer?.invalidate()
            simulationTimer = nil
        }
        
        private func simulateProgress() {
            guard currentStepIndex < steps.count else {
                stopSimulation()
                return
            }
            
            let currentStep = steps[currentStepIndex]
            let stepDistance = currentStep.distance
            
            // Simulate moving along the current step
            if let currentLocation = userLocation {
                let remainingDistance = max(0, stepDistance - 50) // Simulate 50m per second
                distanceToNextManeuver = remainingDistance
                
                if remainingDistance < 10 {
                    // Move to next step
                    currentStepIndex += 1
                    if currentStepIndex < steps.count {
                        if let firstCoordinate = currentStep.polyline.coordinates().first {
                            userLocation = firstCoordinate
                        }
                    }
                } else {
                    // Update position along current step
                    let progress = 1.0 - (remainingDistance / stepDistance)
                    let coordinate = currentStep.polyline.coordinate(at: progress)
                    userLocation = coordinate
                }
            }
            
            // Update ETA
            if let route = route {
                let remainingSteps = steps.dropFirst(currentStepIndex)
                let remainingDistance = remainingSteps.reduce(0) { $0 + $1.distance }
                eta = remainingDistance / 1.4 // Average walking speed
            }
        }
    }
    
    struct InAppNavigationView: View {
        let start: CLLocationCoordinate2D
        let end: CLLocationCoordinate2D
        let travelMode: TravelMode
        let onEnd: () -> Void
        @StateObject private var vm = InAppNavViewModel()
        @Environment(\.dismiss) private var dismiss
        @State private var isFullscreen = false
        
        var body: some View {
            ZStack {
                // Full-screen map
                if let route = vm.route {
                    NavigationMapView(
                        route: route,
                        userLocation: vm.userLocation,
                        currentStep: vm.currentStep,
                        isSimulating: vm.isSimulating
                    )
                    .ignoresSafeArea()
                }
                
                // Top bar with minimal info
                VStack {
                    HStack {
                        Button(action: { onEnd() }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color(.systemBackground).opacity(0.9)))
                                .shadow(radius: 4)
                        }
                        
                        Spacer()
                        
                        if let route = vm.route {
                            VStack(spacing: 2) {
                                Text(etaString(from: vm.eta))
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text(String(format: "%.1f mi", route.distance / 1609.34))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(.systemBackground).opacity(0.9)))
                            .shadow(radius: 4)
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
                
                // Bottom navigation card (Google Maps style)
                VStack {
                    Spacer()
                    
                    if vm.currentStepIndex < vm.steps.count {
                        NavigationBottomCard(
                            step: vm.steps[vm.currentStepIndex],
                            distance: vm.distanceToNextManeuver,
                            totalDistance: vm.route?.distance ?? 0,
                            isSimulating: vm.isSimulating,
                            onStartSimulation: { vm.startSimulation() },
                            onStopSimulation: { 
                                vm.stopSimulation()
                                onEnd() // Also call the onEnd callback to close navigation
                            }
                        )
                    }
                }
                
                // Loading state
                if vm.isCalculating {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.5)
                        Text("Calculating route...")
                            .font(.headline)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
                
                // Error state
                if let error = vm.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Navigation Error")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            vm.calculate(start: start, end: end, travelMode: travelMode)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(32)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 8)
                    .padding()
                }
            }
            .onAppear {
                vm.calculate(start: start, end: end, travelMode: travelMode)
            }
            .onDisappear {
                vm.stopSimulation()
            }
        }
        
        private func etaString(from timeInterval: TimeInterval) -> String {
            let minutes = Int(timeInterval / 60)
            if minutes > 0 {
                return "\(minutes) min"
            } else {
                let seconds = Int(timeInterval)
                return "\(seconds) sec"
            }
        }
    }
    
    struct NavigationMapView: UIViewRepresentable {
        let route: MKRoute
        let userLocation: CLLocationCoordinate2D?
        let currentStep: MKRoute.Step?
        let isSimulating: Bool
        @State private var mainRoutePolyline: MKPolyline?
        @State private var currentStepPolyline: MKPolyline?
        @State private var mapView: MKMapView?
        
        func makeUIView(context: Context) -> MKMapView {
            let mapView = MKMapView(frame: .zero)
            
            // Configure for Google Maps style navigation
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .none
            mapView.delegate = context.coordinator
            mapView.pointOfInterestFilter = .includingAll
            mapView.isPitchEnabled = true
            mapView.isRotateEnabled = true
            mapView.isZoomEnabled = true
            mapView.isScrollEnabled = true
            
            // Set 3D perspective view (like Google Maps)
            mapView.camera = MKMapCamera(
                lookingAtCenter: userLocation ?? route.polyline.coordinate(at: 0),
                fromDistance: 200,
                pitch: 45,
                heading: 0
            )
            
            // Map appearance
            mapView.mapType = .standard
            
            // Store references
            self.mapView = mapView
            mainRoutePolyline = route.polyline
            currentStepPolyline = currentStep?.polyline
            
            return mapView
        }
        
        func updateUIView(_ mapView: MKMapView, context: Context) {
            // Clear existing overlays
            mapView.removeOverlays(mapView.overlays)
            
            // Update stored polylines
            mainRoutePolyline = route.polyline
            currentStepPolyline = currentStep?.polyline
            
            // Add route polyline
            mapView.addOverlay(route.polyline)
            
            // Highlight current step if available
            if let currentStep = currentStep {
                mapView.addOverlay(currentStep.polyline)
            }
            
            // Update camera to follow user with 3D perspective
            if let userLocation = userLocation {
                let camera = MKMapCamera(
                    lookingAtCenter: userLocation,
                    fromDistance: isSimulating ? 150 : 200,
                    pitch: 45,
                    heading: calculateHeading(for: currentStep)
                )
                mapView.setCamera(camera, animated: true)
            } else {
                // Show full route initially
                mapView.setVisibleMapRect(
                    route.polyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 100, left: 100, bottom: 200, right: 100),
                    animated: true
                )
            }
        }
        
        private func calculateHeading(for step: MKRoute.Step?) -> Double {
            guard let step = step else { return 0 }
            let coords = step.polyline.coordinates()
            guard coords.count >= 2 else { return 0 }
            
            let from = coords[0]
            let to = coords[1]
            
            let deltaLongitude = to.longitude - from.longitude
            let deltaLatitude = to.latitude - from.latitude
            let heading = atan2(deltaLongitude, deltaLatitude) * 180 / .pi
            
            return heading < 0 ? heading + 360 : heading
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(mainRoutePolyline: mainRoutePolyline, currentStepPolyline: currentStepPolyline)
        }
        
        final class Coordinator: NSObject, MKMapViewDelegate {
            private let mainRoutePolyline: MKPolyline?
            private let currentStepPolyline: MKPolyline?
            
            init(mainRoutePolyline: MKPolyline?, currentStepPolyline: MKPolyline?) {
                self.mainRoutePolyline = mainRoutePolyline
                self.currentStepPolyline = currentStepPolyline
            }
            
            func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
                if let polyline = overlay as? MKPolyline {
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    
                    if let currentStepPolyline = currentStepPolyline,
                       polyline === currentStepPolyline {
                        // Current step - bright blue
                        renderer.strokeColor = UIColor.systemBlue
                        renderer.lineWidth = 8
                    } else if let mainRoutePolyline = mainRoutePolyline,
                              polyline === mainRoutePolyline {
                        // Main route - subtle gray
                        renderer.strokeColor = UIColor.systemGray
                        renderer.lineWidth = 5
                    } else {
                        // Fallback
                        renderer.strokeColor = UIColor.systemGray
                        renderer.lineWidth = 5
                    }
                    
                    renderer.lineJoin = .round
                    renderer.lineCap = .round
                    return renderer
                }
                return MKOverlayRenderer(overlay: overlay)
            }
        }
    }
    
    struct NavigationBottomCard: View {
        let step: MKRoute.Step
        let distance: Double
        let totalDistance: Double
        let isSimulating: Bool
        let onStartSimulation: () -> Void
        let onStopSimulation: () -> Void
        
        var body: some View {
            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                
                // Main content
                VStack(spacing: 16) {
                    // Top section: Maneuver info
                    HStack(alignment: .top, spacing: 16) {
                        // Maneuver icon
                        maneuverIcon
                        
                        // Instructions and distance
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.instructions)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.leading)
                            
                            if distance > 0 {
                                Text(String(format: "In %.0f m", distance))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Speed/Info button
                        Button(action: {}) {
                            Image(systemName: "info.circle")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Progress bar
                    if totalDistance > 0 {
                        ProgressView(value: (totalDistance - distance) / totalDistance)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(y: 2)
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        // End navigation button
                        Button(action: { onStopSimulation() }) {
                            HStack {
                                Image(systemName: "xmark")
                                Text("End")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        // Simulation toggle
                        Button(action: {
                            if isSimulating {
                                onStopSimulation()
                            } else {
                                onStartSimulation()
                            }
                        }) {
                            HStack {
                                Image(systemName: isSimulating ? "pause.fill" : "play.fill")
                                Text(isSimulating ? "Pause" : "Start")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
            )
        }
        
        private var maneuverIcon: some View {
            let icon = maneuverIconName(for: step)
            return ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
        
        private func maneuverIconName(for step: MKRoute.Step) -> String {
            let lower = step.instructions.lowercased()
            if lower.contains("turn left") {
                return "arrow.turn.up.left"
            } else if lower.contains("turn right") {
                return "arrow.turn.up.right"
            } else if lower.contains("straight") || lower.contains("continue") {
                return "arrow.up"
            } else if lower.contains("head") {
                return "location.up"
            } else if lower.contains("slight left") {
                return "arrow.up.left"
            } else if lower.contains("slight right") {
                return "arrow.up.right"
            } else if lower.contains("sharp left") {
                return "arrow.turn.up.left"
            } else if lower.contains("sharp right") {
                return "arrow.turn.up.right"
            } else if lower.contains("u-turn") || lower.contains("turn around") {
                return "arrow.uturn.up"
            } else {
                return "arrow.up"
            }
        }
    }
    
    // MARK: - Map Annotations
    struct SafetyAnnotation: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let title: String
        let type: AnnotationType
        let severity: ReportSeverity
    }
    
    enum AnnotationType {
        case report(ReportType)
        case event(EventType)
        
        var icon: String {
            switch self {
            case .report(let type):
                return type.icon
            case .event(let type):
                return type.icon
            }
        }
        
        var color: Color {
            switch self {
            case .report(let type):
                return Color(type.color)
            case .event:
                return Color.purple
            }
        }
    }
    
    struct SafetyAnnotationView: View {
        let annotation: SafetyAnnotation
        @State private var isPressed = false
        
        var body: some View {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(annotation.type.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: fallbackIcon(for: annotation.type.icon))
                        .font(.caption)
                        .foregroundColor(annotation.type.color)
                }
                
                Text(annotation.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
            }
            .scaleEffect(isPressed ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onTapGesture {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
            }
            .accessibilityLabel("\(annotation.title) - \(annotation.type.icon)")
            .accessibilityHint("Community safety annotation")
        }
        
        private func fallbackIcon(for iconName: String) -> String {
            switch iconName {
            case "phone.badge.waveform":
                return "phone.fill" // Emergency
            case "wrench.and.screwdriver":
                return "wrench.fill" // Infrastructure
            case "person.3":
                return "person.3.fill" // Community Event
            case "light.max":
                return "lightbulb.fill" // Lighting Issue
            case "car":
                return "car.fill" // Traffic Issue
            case "cloud.rain":
                return "cloud.fill" // Weather Hazard - simpler fallback
            case "hand.thumbsup":
                return "hand.thumbsup.fill" // Positive Experience
            case "exclamationmark.triangle":
                return "exclamationmark.triangle.fill" // Safety Concern
                // Additional fallbacks for other potentially problematic icons
            case "wrench.and.screwdriver.fill":
                return "wrench.fill" // Infrastructure filled version
            case "phone.badge.waveform.fill":
                return "phone.fill" // Emergency filled version
            case "cloud.rain.fill":
                return "cloud.fill" // Weather Hazard filled version
            case "person.3.fill":
                return "person.2.fill" // Community Event alternative
            case "light.max.fill":
                return "lightbulb.fill" // Lighting Issue filled version
            case "car.fill":
                return "car.circle.fill" // Traffic Issue alternative
            case "exclamationmark.triangle.fill":
                return "exclamationmark.circle.fill" // Safety Concern alternative
            default:
                return iconName // Use original if no fallback needed
            }
        }
    }
    
    // MARK: - Route Overlay
    struct RouteOverlay: View {
        let route: Route
        let color: Color
        
        var body: some View {
            GeometryReader { geometry in
                Path { path in
                    let coordinates = route.waypoints.map { $0.coordinate }
                    let points = coordinates.map { coordinate in
                        CGPoint(
                            x: geometry.frame(in: .local).midX,
                            y: geometry.frame(in: .local).midY
                        )
                    }
                    
                    if let first = points.first {
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 6
                )
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
            }
        }
    }
    
    // MARK: - Travel Mode Button
    struct TravelModeButton: View {
        let mode: TravelMode
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 3) {
                    Image(systemName: mode.icon)
                        .font(.caption)
                    
                    Text(mode.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                )
                .foregroundColor(isSelected ? .blue : .primary)
            }
            .accessibilityLabel("Travel by \(mode.rawValue)")
            .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
        }
    }
    
    // MARK: - Route Details Panel
    struct RouteDetailsPanel: View {
        let route: Route
        let routeSafety: RouteSafety?
        let aiRiskFactors: [RiskFactor] // Add AI risk factors
        let onClose: () -> Void
        let onNavigate: () -> Void
        let onNavigateToRisk: (CLLocationCoordinate2D) -> Void // Add map navigation callback
        @State private var showingRiskDetails = false
        
        var body: some View {
            GlassCard(
                backgroundColor: Color.white.opacity(0.2),
                cornerRadius: 24,
                blurRadius: 15,
                opacity: 0.95,
                padding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            ) {
                VStack(spacing: 8) {
                    // Handle bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 2)
                    
                    // AI Summary
                    if let safety = routeSafety {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI Safety Analysis")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text("AI: \(String(format: "%.0f", safety.confidence * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // X button to close the panel
                            Button(action: onClose) {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(
                                        Circle()
                                            .fill(Color.secondary.opacity(0.2))
                                    )
                            }
                        }
                    }
                    
                    // Safety Score
                    let scoreValue: Double = {
                        if let safety = routeSafety {
                            return Double(safety.score)
                        } else {
                            // Fall back to converting the internal 0–1 risk score
                            return max(0, min(100, (1.0 - route.overallSafetyScore) * 100))
                        }
                    }()
                    
                    SafetyScoreCard(
                        score: scoreValue,
                        safetyLevel: route.safetyLevel,
                        confidence: route.aiConfidence
                    )
                    
                    // AI Summary
                    if let safety = routeSafety {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Why this route?")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(safety.summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    // Route Stats
                    HStack(spacing: 10) {
                        StatCard(
                            icon: "figure.walk",
                            value: String(format: "%.1f", route.distanceInMiles),
                            label: "miles"
                        )
                        
                        StatCard(
                            icon: "clock",
                            value: String(format: "%.0f", route.timeInMinutes),
                            label: "min"
                        )
                        
                        // Risk details StatCard
                        if !aiRiskFactors.isEmpty {
                            Button(action: {
                                showingRiskDetails = true
                            }) {
                                StatCard(
                                    icon: "exclamationmark.triangle",
                                    value: "\(aiRiskFactors.count)",
                                    label: "risks"
                                )
                            }
                        }
                    }
                    
                    // Action Buttons
                    HStack(spacing: 10) {
                        Button(action: onNavigate) {
                            GlassCard(
                                backgroundColor: Color.green.opacity(0.9),
                                cornerRadius: 14,
                                blurRadius: 8,
                                opacity: 0.95,
                                padding: EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
                            ) {
                                HStack(spacing: 6) {
                                    Image(systemName: "navigation")
                                        .font(.body)
                                    
                                    Text("Navigate")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        
                        Button(action: {
                            shareRoute()
                        }) {
                            GlassCard(
                                backgroundColor: Color.white.opacity(0.2),
                                cornerRadius: 14,
                                blurRadius: 8,
                                opacity: 0.9,
                                padding: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .sheet(isPresented: $showingRiskDetails) {
                RiskDetailsView(route: route, aiRiskFactors: aiRiskFactors, onNavigateToRisk: onNavigateToRisk)
            }
        }
        
        private func shareRoute() {
            let shareText = "Check out this safe route I found: \(route.name) - \(String(format: "%.1f", route.distanceInMiles)) miles, \(route.timeInMinutes) minutes"
            let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
    
    // MARK: - Supporting Views
    struct StatCard: View {
        let icon: String
        let value: String
        let label: String
        
        var body: some View {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.blue)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
    }
    
    struct RiskFactorRow: View {
        let factor: RiskFactor
        
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(Color(factor.severity.color))
                    .font(.caption2)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(factor.type.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(factor.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 0)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(factor.severity.color).opacity(0.1))
            )
        }
    }
    
    struct RiskDetailsView: View {
        let route: Route
        let aiRiskFactors: [RiskFactor] // Add AI risk factors
        let onNavigateToRisk: (CLLocationCoordinate2D) -> Void // Add callback for map navigation
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Risk Factors for \(route.name)")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("AI-generated safety concerns along this route")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        // Risk Factors List
                        if aiRiskFactors.isEmpty {
                            Text("No specific risk factors identified for this route.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(aiRiskFactors) { factor in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(Color(factor.severity.color))
                                        
                                        Text(factor.type.rawValue)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                        
                                        Spacer()
                                        
                                        Text(factor.severity.rawValue)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule()
                                                    .fill(Color(factor.severity.color).opacity(0.2))
                                            )
                                            .foregroundColor(Color(factor.severity.color))
                                    }
                                    
                                    Text(factor.description)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Text("Recommendation: \(factor.recommendation)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                    
                                    // Map navigation button if location is available
                                    if let location = factor.location {
                                        Button(action: {
                                            print("🗺️ VIEW ON MAP BUTTON PRESSED!")
                                            print("  - Risk Factor: \(factor.type.rawValue)")
                                            print("  - Location: \(location.latitude), \(location.longitude)")
                                            print("  - Calling onNavigateToRisk callback...")
                                            onNavigateToRisk(location)
                                        }) {
                                            HStack {
                                                Image(systemName: "map")
                                                    .font(.caption)
                                                Text("View on Map")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                            .foregroundColor(.blue)
                                            .padding(.top, 4)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .navigationTitle("Risk Factors")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    print("🔍 DISPLAYING RISK FACTORS:")
                    print("  - Total risk factors: \(aiRiskFactors.count)")
                    for factor in aiRiskFactors {
                        print("  - Risk: \(factor.type.rawValue), Location: \(factor.location?.latitude ?? 0), \(factor.location?.longitude ?? 0)")
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    struct DestinationSearchView: View {
        let onDestinationSelected: (CLLocationCoordinate2D) -> Void
        @Environment(\.dismiss) private var dismiss
        @State private var searchText = ""
        @State private var searchResults: [MKMapItem] = []
        @State private var isSearching = false
        @State private var searchCompleter = MKLocalSearchCompleter()
        @State private var searchTask: Task<Void, Never>?
        
        var body: some View {
            NavigationView {
                VStack(spacing: 0) {
                    // Search Bar
                    GlassCard(
                        backgroundColor: Color.white.opacity(0.2),
                        cornerRadius: 16,
                        blurRadius: 8,
                        opacity: 0.9
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search destination...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.body)
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .padding()
                    .onChange(of: searchText) { newValue in
                        // Cancel previous search task
                        searchTask?.cancel()
                        
                        if newValue.isEmpty {
                            searchResults = []
                            isSearching = false
                            return
                        }
                        
                        // Debounce search by 300ms
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            if !Task.isCancelled {
                                await MainActor.run {
                                    performSearch(query: newValue)
                                }
                            }
                        }
                    }
                    
                    // Search Results or Quick Destinations
                    ScrollView {
                        VStack(spacing: 12) {
                            if searchResults.isEmpty && searchText.isEmpty {
                                Text("Quick Destinations")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                
                                ForEach(quickDestinations, id: \.name) { destination in
                                    QuickDestinationButton(destination: destination) {
                                        onDestinationSelected(destination.coordinate)
                                        dismiss()
                                    }
                                }
                            } else if !searchResults.isEmpty {
                                Text("Search Results")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                
                                ForEach(searchResults, id: \.self) { mapItem in
                                    SearchResultButton(mapItem: mapItem) {
                                        if let coordinate = mapItem.placemark.location?.coordinate {
                                            onDestinationSelected(coordinate)
                                            dismiss()
                                        }
                                    }
                                }
                            } else if isSearching {
                                ProgressView()
                                    .padding()
                            } else if !searchText.isEmpty {
                                Text("No results found")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                        .padding(.vertical)
                    }
                }
                .navigationTitle("Select Destination")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
        
        private func performSearch(query: String) {
            guard !query.isEmpty else {
                searchResults = []
                return
            }
            
            isSearching = true
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                isSearching = false
                
                if let error = error {
                    print("Search error: \(error.localizedDescription)")
                    return
                }
                
                if let response = response {
                    searchResults = response.mapItems
                }
            }
        }
        
        private let quickDestinations = [
            QuickDestination(name: "Central Park", coordinate: CLLocationCoordinate2D(latitude: 40.7829, longitude: -73.9654)),
            QuickDestination(name: "Times Square", coordinate: CLLocationCoordinate2D(latitude: 40.7580, longitude: -73.9855)),
            QuickDestination(name: "Brooklyn Bridge", coordinate: CLLocationCoordinate2D(latitude: 40.7061, longitude: -73.9969)),
            QuickDestination(name: "Grand Central", coordinate: CLLocationCoordinate2D(latitude: 40.7527, longitude: -73.9772))
        ]
    }
    
    struct QuickDestination {
        let name: String
        let coordinate: CLLocationCoordinate2D
    }
    
    struct QuickDestinationButton: View {
        let destination: QuickDestination
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                GlassCard(
                    backgroundColor: Color.white.opacity(0.2),
                    cornerRadius: 16,
                    blurRadius: 8,
                    opacity: 0.8
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        Text(destination.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal)
        }
    }
    
    struct SearchResultButton: View {
        let mapItem: MKMapItem
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                GlassCard(
                    backgroundColor: Color.white.opacity(0.2),
                    cornerRadius: 16,
                    blurRadius: 8,
                    opacity: 0.8
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mapItem.name ?? "Unknown Location")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            if let address = mapItem.placemark.title {
                                Text(address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal)
        }
    }
    
    struct SafetyLegendView: View {
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        // Safety Levels
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Safety Levels")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ForEach(SafetyLevel.allCases, id: \.self) { level in
                                SafetyLevelRow(level: level)
                            }
                        }
                        .padding()
                        .background(
                            GlassCard(
                                backgroundColor: Color.white.opacity(0.2),
                                cornerRadius: 20,
                                blurRadius: 10,
                                opacity: 0.8
                            ) {
                                EmptyView()
                            }
                        )
                        .padding(.horizontal)
                        
                        // Map Icons
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Map Icons")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ForEach(ReportType.allCases, id: \.self) { type in
                                IconLegendRow(icon: type.icon, color: Color(type.color), label: type.rawValue)
                            }
                        }
                        .padding()
                        .background(
                            GlassCard(
                                backgroundColor: Color.white.opacity(0.2),
                                cornerRadius: 20,
                                blurRadius: 10,
                                opacity: 0.8
                            ) {
                                EmptyView()
                            }
                        )
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .navigationTitle("Safety Legend")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    struct SafetyLevelRow: View {
        let level: SafetyLevel
        
        var body: some View {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color(level.color))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(safetyLevelDescription(for: level))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        
        private func safetyLevelDescription(for level: SafetyLevel) -> String {
            switch level {
            case .safe:
                return "Well-lit areas with good visibility and low incident rates"
            case .moderate:
                return "Areas requiring some caution, check surroundings"
            case .risky:
                return "Exercise extra caution, consider alternatives"
            }
        }
    }
    
    struct IconLegendRow: View {
        let icon: String
        let color: Color
        let label: String
        
        var body: some View {
            HStack(spacing: 16) {
                // Use fallback icons for problematic SF Symbols
                Image(systemName: fallbackIcon(for: icon))
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(color.opacity(0.2))
                    )
                
                Text(label)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
            }
        }
        
        private func fallbackIcon(for iconName: String) -> String {
            switch iconName {
            case "phone.badge.waveform":
                return "phone.fill" // Emergency
            case "wrench.and.screwdriver":
                return "wrench.fill" // Infrastructure
            case "person.3":
                return "person.3.fill" // Community Event
            case "light.max":
                return "lightbulb.fill" // Lighting Issue
            case "car":
                return "car.fill" // Traffic Issue
            case "cloud.rain":
                return "cloud.fill" // Weather Hazard - simpler fallback
            case "hand.thumbsup":
                return "hand.thumbsup.fill" // Positive Experience
            case "exclamationmark.triangle":
                return "exclamationmark.triangle.fill" // Safety Concern
                // Additional fallbacks for other potentially problematic icons
            case "wrench.and.screwdriver.fill":
                return "wrench.fill" // Infrastructure filled version
            case "phone.badge.waveform.fill":
                return "phone.fill" // Emergency filled version
            case "cloud.rain.fill":
                return "cloud.fill" // Weather Hazard filled version
            case "person.3.fill":
                return "person.2.fill" // Community Event alternative
            case "light.max.fill":
                return "lightbulb.fill" // Lighting Issue filled version
            case "car.fill":
                return "car.circle.fill" // Traffic Issue alternative
            case "exclamationmark.triangle.fill":
                return "exclamationmark.circle.fill" // Safety Concern alternative
            default:
                return iconName // Use original if no fallback needed
            }
        }
    }
    
    // MARK: - Safety Heatmap Overlay
    struct SafetyHeatmapOverlay: View {
        let region: MKCoordinateRegion
        let safetyData: [CommunityReport]
        let opacity: Double
        
        var body: some View {
            Canvas { context, size in
                // Create heatmap visualization based on safety reports
                for report in safetyData {
                    let coordinate = report.location // Use location property, not coordinate
                    let point = coordinateToPoint(coordinate, in: size, region: region)
                    
                    // Create gradient circle for each safety report
                    let center = CGPoint(x: point.x, y: point.y)
                    let radius: CGFloat = 50
                    
                    // Color based on severity
                    let color = colorForSeverity(report.severity)
                    
                    // Create radial gradient for heatmap effect
                    let gradient = RadialGradient(
                        colors: [
                            color.opacity(opacity),
                            color.opacity(opacity * 0.5),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                    
                    // Draw filled circle with gradient
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .color(color.opacity(opacity))
                    )
                }
            }
        }
        
        private func coordinateToPoint(_ coordinate: CLLocationCoordinate2D, in size: CGSize, region: MKCoordinateRegion) -> CGPoint {
            let x = (coordinate.longitude - region.center.longitude) / region.span.longitudeDelta * size.width + size.width / 2
            let y = (region.center.latitude - coordinate.latitude) / region.span.latitudeDelta * size.height + size.height / 2
            return CGPoint(x: x, y: y)
        }
        
        private func colorForSeverity(_ severity: ReportSeverity) -> Color {
            switch severity {
            case .low: return .green
            case .medium: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }
    }


// MARK: - Supporting Types
// Removed duplicated enums (TravelMode, SafetyLevel, ReportSeverity, ReportType, EventType)
// Models are defined centrally in Models/RouteModels.swift and Models/CommunityModels.swift

// MARK: - Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(SafetyDataManager())
            .environmentObject(LocationManager())
    }
}
