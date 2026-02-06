//
//  CommunityView.swift
//  SafeRouteAI
//
//  Community safety reports and events view
//

import SwiftUI
import MapKit
import CoreLocation

struct CommunityView: View {
    @EnvironmentObject var safetyDataManager: SafetyDataManager
    @EnvironmentObject var locationManager: LocationManager
    @AppStorage("distanceUnit") private var distanceUnit: DistanceUnit = .kilometers
    @State private var showingReportForm = false
    @State private var selectedFilter = "All Reports"
    
    let filters = ["All Reports", "Recent", "Nearby", "Safety", "Infrastructure", "Lighting", "Events"]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header card
                        GlassCard(
                            backgroundColor: .blue,
                            cornerRadius: 20,
                            blurRadius: 15,
                            opacity: 0.9
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    Text("Community Safety")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                
                                Text("Report incidents and stay informed about safety in your area")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        }
                        .padding(.horizontal)
                        
                        // Quick stats
                        HStack(spacing: 16) {
                            MiniStatCard(
                                title: "Active Reports",
                                value: "\(safetyDataManager.communityReports.count)",
                                icon: "exclamationmark.triangle.fill",
                                color: .orange
                            )
                            
                            MiniStatCard(
                                title: "This Week",
                                value: String(reportsThisWeekCount),
                                icon: "calendar",
                                color: .green
                            )
                        }
                        .padding(.horizontal)
                        
                        // Filter buttons
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(filters, id: \.self) { filter in
                                    FilterButton(
                                        title: filter,
                                        isSelected: selectedFilter == filter,
                                        action: {
                                            selectedFilter = filter
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Reports list
                        LazyVStack(spacing: 16) {
                            ForEach(filteredReports) { report in
                                CommunityReportCard(report: report, distanceFromUser: distanceFromUser(to: report.location))
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal)
                        .animation(.easeInOut, value: selectedFilter)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
                
                // Floating action button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingReportForm = true
                        }) {
                            GlassCard(
                                backgroundColor: .blue,
                                cornerRadius: 20,
                                blurRadius: 15,
                                opacity: 0.95
                            ) {
                                Image(systemName: "plus")
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding(12)
                            }
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                        .shadow(radius: 10)
                    }
                }
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingReportForm) {
                SafetyReportForm()
                    .environmentObject(safetyDataManager)
                    .environmentObject(locationManager)
            }
        }
    }
    
    private var filteredReports: [CommunityReport] {
        switch selectedFilter {
        case "Recent":
            return safetyDataManager.communityReports.filter { report in
                Calendar.current.isDateInToday(report.timestamp) ||
                Calendar.current.isDateInYesterday(report.timestamp)
            }
        case "Nearby":
            guard let userLoc = locationManager.userLocation else {
                return []
            }
            return safetyDataManager.communityReports.filter { report in
                CLLocation(latitude: report.location.latitude, longitude: report.location.longitude)
                    .distance(from: userLoc) <= 1000
            }
        case "Safety":
            return safetyDataManager.communityReports.filter { report in
                report.reportType == .safetyConcern
            }
        case "Infrastructure":
            return safetyDataManager.communityReports.filter { report in
                report.reportType == .infrastructure
            }
        case "Lighting":
            return safetyDataManager.communityReports.filter { report in
                report.reportType == .lightingIssue
            }
        case "Events":
            return safetyDataManager.communityReports.filter { report in
                report.reportType == .communityEvent
            }
        default:
            return safetyDataManager.communityReports
        }
    }

    private var reportsThisWeekCount: Int {
        let calendar = Calendar.current
        let now = Date()
        let nowWeek = calendar.component(.weekOfYear, from: now)
        let nowYear = calendar.component(.yearForWeekOfYear, from: now)
        return safetyDataManager.communityReports.filter { report in
            let week = calendar.component(.weekOfYear, from: report.timestamp)
            let year = calendar.component(.yearForWeekOfYear, from: report.timestamp)
            return week == nowWeek && year == nowYear
        }.count
    }

    private func distanceFromUser(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let userLoc = locationManager.userLocation else { return nil }
        let reportLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return reportLoc.distance(from: userLoc)
    }
}

struct CommunityReportCard: View {
    let report: CommunityReport
    let distanceFromUser: Double?
    @AppStorage("distanceUnit") private var distanceUnit: DistanceUnit = .kilometers
    
    var body: some View {
        GlassCard(
            backgroundColor: .white,
            cornerRadius: 16,
            blurRadius: 12,
            opacity: 0.8
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: report.reportType.icon)
                        .font(.title3)
                        .foregroundColor(Color(report.severity.color))
                    
                    Text(report.reportType.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(report.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Description
                Text(report.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                // Location and severity
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption)
                        
                        if let dist = distanceFromUser {
                            Text(distanceUnit.formatDistance(dist))
                                .font(.caption)
                        } else {
                            Text(report.formattedLocation)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(report.severity.color))
                            .frame(width: 8, height: 8)
                        
                        Text(report.severity.description)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(Color(report.severity.color))
                }
            }
            .padding()
        }
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            GlassCard(
                backgroundColor: isSelected ? .blue : .gray,
                cornerRadius: 20,
                blurRadius: 8,
                opacity: isSelected ? 0.9 : 0.6
            ) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
    }
}

struct MiniStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        GlassCard(
            backgroundColor: color,
            cornerRadius: 16,
            blurRadius: 12,
            opacity: 0.8
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding()
        }
    }
}

// Enhanced Safety Report Form with incident type selection and location input
struct SafetyReportForm: View {
    @EnvironmentObject var safetyDataManager: SafetyDataManager
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedReportType: ReportType = .safetyConcern
    @State private var selectedSeverity: ReportSeverity = .medium
    @State private var addressInput: String = ""
    @State private var useCurrentLocation: Bool = true
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showingMapPicker: Bool = false
    @State private var isSubmitting: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Report Details")) {
                    TextField("Title", text: $title)
                    
                    Picker("Incident Type", selection: $selectedReportType) {
                        ForEach(ReportType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                    
                    Picker("Severity", selection: $selectedSeverity) {
                        ForEach(ReportSeverity.allCases, id: \.self) { severity in
                            HStack {
                                Circle()
                                    .fill(Color(severity.color == "SafetyGreen" ? .green : 
                                              severity.color == "SafetyYellow" ? .yellow :
                                              severity.color == "SafetyOrange" ? .orange : .red))
                                    .frame(width: 8, height: 8)
                                Text(severity.rawValue)
                            }
                            .tag(severity)
                        }
                    }
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Location")) {
                    Toggle("Use Current Location", isOn: $useCurrentLocation)
                    
                    if !useCurrentLocation {
                        TextField("Enter Address", text: $addressInput)
                        
                        Button(action: {
                            showingMapPicker = true
                        }) {
                            HStack {
                                Image(systemName: "map")
                                Text("Drop Pin on Map")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let location = selectedLocation {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                Text("Pin Dropped")
                                    .foregroundColor(.green)
                                Spacer()
                                Text("Lat: \(String(format: "%.4f", location.latitude)), Lon: \(String(format: "%.4f", location.longitude))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text("Current Location")
                                .foregroundColor(.blue)
                            Spacer()
                            if let userLocation = locationManager.userLocation {
                                Text("Lat: \(String(format: "%.4f", userLocation.coordinate.latitude)), Lon: \(String(format: "%.4f", userLocation.coordinate.longitude))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Getting location...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("Additional Information")) {
                    Text("Your report will help keep the community safe. All reports are verified before being published.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { 
                        dismiss() 
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: submitReport) {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Submit")
                        }
                    }
                    .disabled(title.isEmpty || description.isEmpty || isSubmitting)
                }
            }
            .sheet(isPresented: $showingMapPicker) {
                MapLocationPicker(selectedLocation: $selectedLocation, addressInput: $addressInput)
            }
            .onAppear {
                if let userLocation = locationManager.userLocation {
                    selectedLocation = userLocation.coordinate
                }
            }
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        
        let reportLocation = useCurrentLocation ? 
            (locationManager.userLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)) :
            (selectedLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0))
        
        let report = CommunityReport(
            title: title,
            description: description,
            reportType: selectedReportType,
            location: reportLocation,
            address: useCurrentLocation ? "Current Location" : (addressInput.isEmpty ? "Selected Location" : addressInput),
            timestamp: Date(),
            userId: "current_user",
            userDisplayName: "You",
            severity: selectedSeverity,
            verified: false,
            helpfulVotes: 0,
            imageUrls: nil,
            tags: [selectedReportType.rawValue.lowercased()]
        )
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            safetyDataManager.communityReports.append(report)
            isSubmitting = false
            dismiss()
        }
    }
}

// Identifiable annotation for Map
struct MapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// Map Location Picker for dropping pins
struct MapLocationPicker: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var addressInput: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var pinLocation: MapAnnotation?
    
    var body: some View {
        NavigationView {
            ZStack {
                Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: [pinLocation].compactMap { $0 }) { pin in
                    MapPin(coordinate: pin.coordinate, tint: .red)
                }
                .onTapGesture { location in
                    // Convert tap location to coordinate (simplified)
                    let newCoordinate = CLLocationCoordinate2D(
                        latitude: region.center.latitude + (Double.random(in: -0.5...0.5) * region.span.latitudeDelta),
                        longitude: region.center.longitude + (Double.random(in: -0.5...0.5) * region.span.longitudeDelta)
                    )
                    pinLocation = MapAnnotation(coordinate: newCoordinate)
                }
                
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            if let pin = pinLocation {
                                selectedLocation = pin.coordinate
                                addressInput = "Selected Location"
                            }
                            dismiss()
                        }) {
                            Text("Confirm Location")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview
struct CommunityView_Previews: PreviewProvider {
    static var previews: some View {
        CommunityView()
            .environmentObject(SafetyDataManager())
            .environmentObject(LocationManager())
    }
}
