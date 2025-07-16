import SwiftUI

struct SettingsView: View {
    
    // MARK: - Environment Objects
    @EnvironmentObject var tokenManager: SecureTokenManager
    @EnvironmentObject var dataManager: DataManager
    
    // MARK: - State
    @State private var showingTokenManagement = false
    @State private var showingClearDataAlert = false
    @State private var isClearing = false
    @State private var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    @State private var buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        NavigationView {
            List {
                // Account Section
                AccountSection()
                
                // Data & Storage Section
                DataStorageSection()
                
                // App Preferences Section
                AppPreferencesSection()
                
                // About Section
                AboutSection()
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingTokenManagement) {
            TokenManagementView()
        }
        .alert("Clear All Data", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Data", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will remove all cached data from your device. Your tokens will remain safe. This action cannot be undone.")
        }
    }
    
    // MARK: - Account Section
    
    @ViewBuilder
    private func AccountSection() -> some View {
        Section("Account") {
            // Token Management
            Button(action: {
                showingTokenManagement = true
            }) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Tokens")
                            .foregroundColor(.primary)
                        
                        Text("\(tokenManager.tokens.count) token(s) configured")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Token Status
            if !tokenManager.tokens.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Token Status")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(tokenManager.tokens.prefix(3)) { token in
                        HStack {
                            Text(token.name)
                                .font(.caption)
                            
                            Spacer()
                            
                            ValidationStatusBadge(token: token)
                        }
                    }
                    
                    if tokenManager.tokens.count > 3 {
                        Text("and \(tokenManager.tokens.count - 3) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Data & Storage Section
    
    @ViewBuilder
    private func DataStorageSection() -> some View {
        Section("Data & Storage") {
            // Cache Status
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    Text("Local Cache")
                    
                    Spacer()
                    
                    Text(getCacheSize())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Cached data helps widgets load faster and work offline")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
            // Clear Cache
            Button(action: {
                showingClearDataAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    Text("Clear All Cached Data")
                        .foregroundColor(.red)
                }
            }
            .disabled(isClearing)
            
            // Auto-cleanup settings
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-cleanup")
                    Text("Automatically removes old cached data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: .constant(true))
                    .disabled(true) // TODO: Implement auto-cleanup settings
            }
        }
    }
    
    // MARK: - App Preferences Section
    
    @ViewBuilder
    private func AppPreferencesSection() -> some View {
        Section("App Preferences") {
            // Notifications (placeholder)
            HStack {
                Image(systemName: "bell")
                    .foregroundColor(.purple)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications")
                    Text("Widget update notifications")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: .constant(false))
                    .disabled(true) // TODO: Implement notifications
            }
            
            // Dark Mode (follows system)
            HStack {
                Image(systemName: "paintbrush")
                    .foregroundColor(.indigo)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Appearance")
                    Text("Follows system setting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("Auto")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Privacy
            Button(action: {
                // TODO: Navigate to privacy settings
            }) {
                HStack {
                    Image(systemName: "hand.raised")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text("Privacy & Security")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - About Section
    
    @ViewBuilder
    private func AboutSection() -> some View {
        Section("About") {
            // App Version
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version")
                    Text("NoBuddy v\(appVersion) (\(buildNumber))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Help & Support
            Button(action: {
                openSupportEmail()
            }) {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    Text("Help & Support")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "envelope")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Acknowledgments
            Button(action: {
                // TODO: Show acknowledgments
            }) {
                HStack {
                    Image(systemName: "heart")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    Text("Acknowledgments")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // GitHub
            Button(action: {
                openGitHub()
            }) {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    
                    Text("GitHub Repository")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        
        Section {
            // Credits
            VStack(spacing: 8) {
                Text("NoBuddy")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("Your Notion Companion")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Made with ❤️ for the Notion community")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }
    
    // MARK: - Private Methods
    
    private func getCacheSize() -> String {
        // TODO: Calculate actual cache size
        return "2.4 MB"
    }
    
    private func clearAllData() {
        isClearing = true
        
        Task {
            await dataManager.clearAllCachedData()
            
            await MainActor.run {
                isClearing = false
            }
        }
    }
    
    private func openSupportEmail() {
        let email = "support@nobuddy.app"
        let subject = "NoBuddy Support Request"
        let body = """
        
        
        ---
        App Version: \(appVersion) (\(buildNumber))
        iOS Version: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.model)
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openGitHub() {
        if let url = URL(string: "https://github.com/nobuddy/nobuddy-ios") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let action: () -> Void
    
    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let isEnabled: Bool
    
    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>,
        isEnabled: Bool = true
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .disabled(!isEnabled)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(SecureTokenManager())
        .environmentObject(DataManager())
}