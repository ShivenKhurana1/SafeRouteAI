//
//  SettingsView.swift
//  SafeRouteAI
//
//  Settings view for user preferences and app configuration
//  Includes unit conversion, notifications, and other user settings
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("distanceUnit") private var distanceUnit: DistanceUnit = .kilometers
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("locationServicesEnabled") private var locationServicesEnabled: Bool = true
    @AppStorage("autoRefreshData") private var autoRefreshData: Bool = true
    @AppStorage("themePreference") private var themePreference: ThemePreference = .system
    
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.gray.opacity(0.1), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Units Section
                        unitsSection
                        
                        // Notifications Section
                        notificationsSection
                        
                        // Privacy Section
                        privacySection
                        
                        // Appearance Section
                        appearanceSection
                        
                        // Data Management Section
                        dataManagementSection
                        
                        // About Section
                        aboutSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetSettings()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
    }
    
    private var headerSection: some View {
        GlassCard(
            backgroundColor: .gray,
            cornerRadius: 20,
            blurRadius: 15,
            opacity: 0.9
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Text("Customize your SafeRouteAI experience")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .padding(.horizontal)
    }
    
    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Units & Measurements")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            GlassCard(
                backgroundColor: .white,
                cornerRadius: 16,
                blurRadius: 12,
                opacity: 0.8
            ) {
                VStack(spacing: 0) {
                    // Distance Unit
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "ruler")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Distance Unit")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Choose between miles and kilometers")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Picker("Distance Unit", selection: $distanceUnit) {
                            ForEach(DistanceUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                    .padding()
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Example conversion
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .font(.title3)
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Example")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("1.0 miles = 1.6 kilometers")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notifications")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            GlassCard(
                backgroundColor: .white,
                cornerRadius: 16,
                blurRadius: 12,
                opacity: 0.8
            ) {
                VStack(spacing: 0) {
                    // Push Notifications
                    SettingsToggleRow(
                        icon: "bell.fill",
                        title: "Push Notifications",
                        description: "Receive safety alerts and updates",
                        isOn: $notificationsEnabled,
                        iconColor: .orange
                    )
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Location Services
                    SettingsToggleRow(
                        icon: "location.fill",
                        title: "Location Services",
                        description: "Allow app to access your location",
                        isOn: $locationServicesEnabled,
                        iconColor: .blue
                    )
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Auto Refresh
                    SettingsToggleRow(
                        icon: "arrow.clockwise",
                        title: "Auto Refresh Data",
                        description: "Automatically update safety information",
                        isOn: $autoRefreshData,
                        iconColor: .green
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy & Security")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            GlassCard(
                backgroundColor: .white,
                cornerRadius: 16,
                blurRadius: 12,
                opacity: 0.8
            ) {
                VStack(spacing: 0) {
                    SettingsNavigationRow(
                        icon: "lock.shield",
                        title: "Privacy Policy",
                        description: "Learn how we protect your data",
                        iconColor: .purple
                    )
                    
                    Divider()
                        .padding(.horizontal)
                    
                    SettingsNavigationRow(
                        icon: "hand.raised.fill",
                        title: "Data & Permissions",
                        description: "Manage app permissions and data",
                        iconColor: .red
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Appearance")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            GlassCard(
                backgroundColor: .white,
                cornerRadius: 16,
                blurRadius: 12,
                opacity: 0.8
            ) {
                VStack(spacing: 0) {
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "paintbrush.fill")
                                .font(.title3)
                                .foregroundColor(.indigo)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Theme")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Choose app appearance")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Picker("Theme", selection: $themePreference) {
                            ForEach(ThemePreference.allCases, id: \.self) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding()
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Management")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            GlassCard(
                backgroundColor: .white,
                cornerRadius: 16,
                blurRadius: 12,
                opacity: 0.8
            ) {
                VStack(spacing: 0) {
                    SettingsNavigationRow(
                        icon: "trash.fill",
                        title: "Clear Cache",
                        description: "Remove temporary data and files",
                        iconColor: .red
                    )
                    
                    Divider()
                        .padding(.horizontal)
                    
                    Button(action: {
                        showingResetAlert = true
                    }) {
                        HStack {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Reset Settings")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text("Restore default settings")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            GlassCard(
                backgroundColor: .white,
                cornerRadius: 16,
                blurRadius: 12,
                opacity: 0.8
            ) {
                VStack(spacing: 0) {
                    SettingsNavigationRow(
                        icon: "info.circle.fill",
                        title: "App Version",
                        description: "SafeRouteAI v1.0.0",
                        iconColor: .blue
                    )
                    
                    Divider()
                        .padding(.horizontal)
                    
                    SettingsNavigationRow(
                        icon: "questionmark.circle.fill",
                        title: "Help & Support",
                        description: "Get help and contact support",
                        iconColor: .green
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func resetSettings() {
        distanceUnit = .kilometers
        notificationsEnabled = true
        locationServicesEnabled = true
        autoRefreshData = true
        themePreference = .system
    }
}

// MARK: - Supporting Views

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    let iconColor: Color
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding()
    }
}

struct SettingsNavigationRow: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Enums

enum DistanceUnit: String, CaseIterable {
    case miles = "Miles"
    case kilometers = "Kilometers"
    
    var abbreviation: String {
        switch self {
        case .miles: return "mi"
        case .kilometers: return "km"
        }
    }
    
    func convert(_ value: Double) -> Double {
        switch self {
        case .miles: return value / 1.60934
        case .kilometers: return value
        }
    }
    
    func formatDistance(_ meters: Double) -> String {
        let convertedValue = self.convert(meters)
        if convertedValue < 1 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.1f %@", convertedValue, self.abbreviation)
        }
    }
}

enum ThemePreference: String, CaseIterable {
    case light = "Light"
    case system = "System"
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
