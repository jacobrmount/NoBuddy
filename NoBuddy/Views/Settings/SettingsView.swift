import SwiftUI

/// Main settings view with app preferences and configuration
struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false
    @AppStorage("isHapticsEnabled") private var isHapticsEnabled = true
    @State private var showingAbout = false
    @State private var showingLicenses = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background with glass morphism effect
                backgroundView
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header section
                        headerSection
                        
                        // Preferences section
                        preferencesSection
                        
                        // About section
                        aboutSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    settingsButton
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingLicenses) {
                LicensesView()
            }
        }
    }
    
    // MARK: - Background View
    
    private var backgroundView: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.black, Color(white: 0.05)]
                        : [Color(white: 0.98), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .ignoresSafeArea()
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                Image(systemName: "star.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text("NoBuddy")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Preferences Section
    
    private var preferencesSection: some View {
        VStack(spacing: 16) {
            sectionHeader("Preferences")
            
            VStack(spacing: 12) {
                // Dark Mode setting
                settingsRow(
                    icon: "moon.fill",
                    iconColor: .indigo,
                    title: "Dark Mode",
                    subtitle: "Automatically adjust the app appearance throughout your device"
                ) {
                Toggle("", isOn: $isDarkModeEnabled)
                    .labelsHidden()
                    .scaleEffect(0.9)
                    .onChange(of: isDarkModeEnabled) {
                        // Apply haptic feedback
                        if isHapticsEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
                }
                
                // Haptics setting
                settingsRow(
                    icon: "hand.tap.fill",
                    iconColor: .green,
                    title: "Haptics",
                    subtitle: "Feel physical feedback on touches throughout the app"
                ) {
                Toggle("", isOn: $isHapticsEnabled)
                    .labelsHidden()
                    .scaleEffect(0.9)
                    .onChange(of: isHapticsEnabled) { oldValue, newValue in
                        // Apply haptic feedback if enabled
                        if newValue {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(spacing: 16) {
            sectionHeader("About")
            
            VStack(spacing: 12) {
                // About row
                Button(action: { showingAbout = true }) {
                    settingsRowButton(
                        icon: "info.circle.fill",
                        iconColor: .blue,
                        title: "About NoBuddy",
                        subtitle: "Learn more about this app"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Licenses row
                Button(action: { showingLicenses = true }) {
                    settingsRowButton(
                        icon: "doc.text.fill",
                        iconColor: .orange,
                        title: "Licenses",
                        subtitle: "Third-party software licenses"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Version info
                settingsRow(
                    icon: "gear.badge.checkmark",
                    iconColor: .gray,
                    title: "Version",
                    subtitle: "App version and build information"
                ) {
                    Text("1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Settings Button
    
    private var settingsButton: some View {
        Button(action: {
            // Settings button action
            if isHapticsEnabled {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(NoBuddyScaleButtonStyle())
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    private func settingsRow<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Custom content
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func settingsRowButton(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .default, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("About NoBuddy")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("NoBuddy is your powerful companion app for Notion, helping you manage API tokens and access your workspace data seamlessly.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("About")
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

// MARK: - Licenses View

struct LicensesView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    licenseSection(
                        title: "KeychainAccess",
                        description: "MIT License - A simple Swift wrapper for Keychain Services",
                        url: "https://github.com/kishikawakatsumi/KeychainAccess"
                    )
                    
                    licenseSection(
                        title: "SwiftUI-Introspect",
                        description: "MIT License - Introspect underlying UIKit components from SwiftUI",
                        url: "https://github.com/siteline/SwiftUI-Introspect"
                    )
                }
                .padding()
            }
            .navigationTitle("Licenses")
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
    
    private func licenseSection(title: String, description: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
            
            Text(url)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .preferredColorScheme(.light)
        
        SettingsView()
            .preferredColorScheme(.dark)
    }
} 
