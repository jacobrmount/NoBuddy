import SwiftUI

/// Main settings view with app preferences and configuration
struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var showingAbout = false
    @State private var showingLicenses = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background with glass morphism effect
                backgroundView
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Info section
                        infoSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.large)
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
    
    
    
    // MARK: - Info Section
    
    private var infoSection: some View {
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
