import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var tokenManager: SecureTokenManager
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                generalSection
                
                notificationsSection
                
                dataSection
                
                aboutSection
            }
            .navigationTitle("Settings")
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .alert("Clear Cache", isPresented: $viewModel.showingClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    viewModel.clearCache(dataManager: dataManager)
                }
            } message: {
                Text("This will remove all cached Notion data. The data will be re-downloaded when needed.")
            }
        }
    }
    
    private var generalSection: some View {
        Section("General") {
            HStack {
                Image(systemName: "key.horizontal")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text("Manage Tokens")
                
                Spacer()
                
                Text("\(tokenManager.tokens.count)")
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            HStack {
                Image(systemName: "square.grid.2x2")
                    .foregroundColor(.purple)
                    .frame(width: 24)
                
                Text("Widget Configuration")
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            Toggle(isOn: $viewModel.enableHapticFeedback) {
                HStack {
                    Image(systemName: "hand.tap")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    Text("Haptic Feedback")
                }
            }
            .onChange(of: viewModel.enableHapticFeedback) { newValue in
                viewModel.saveSettings()
            }
        }
    }
    
    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle(isOn: $viewModel.enableWidgetNotifications) {
                HStack {
                    Image(systemName: "bell")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    Text("Widget Updates")
                }
            }
            .onChange(of: viewModel.enableWidgetNotifications) { newValue in
                viewModel.saveSettings()
            }
            
            Toggle(isOn: $viewModel.enableTokenValidationNotifications) {
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    Text("Token Validation")
                }
            }
            .onChange(of: viewModel.enableTokenValidationNotifications) { newValue in
                viewModel.saveSettings()
            }
        }
    }
    
    private var dataSection: some View {
        Section("Data & Storage") {
            HStack {
                Image(systemName: "externaldrive")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cache Size")
                    Text(viewModel.cacheSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Button(action: {
                viewModel.showingClearCacheAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    Text("Clear Cache")
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.green)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-sync Interval")
                    Text("\(Int(viewModel.autoSyncInterval / 60)) minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Picker("Auto-sync Interval", selection: $viewModel.autoSyncInterval) {
                Text("5 minutes").tag(300.0)
                Text("15 minutes").tag(900.0)
                Text("30 minutes").tag(1800.0)
                Text("1 hour").tag(3600.0)
                Text("Never").tag(0.0)
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.autoSyncInterval) { newValue in
                viewModel.saveSettings()
            }
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text("Version")
                
                Spacer()
                
                Text(viewModel.appVersion)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(.green)
                    .frame(width: 24)
                
                Text("Support")
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .onTapGesture {
                viewModel.openSupport()
            }
            
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                
                Text("Privacy Policy")
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .onTapGesture {
                viewModel.openPrivacyPolicy()
            }
            
            HStack {
                Image(systemName: "heart")
                    .foregroundColor(.red)
                    .frame(width: 24)
                
                Text("Rate App")
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .onTapGesture {
                viewModel.rateApp()
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var enableHapticFeedback = true
    @Published var enableWidgetNotifications = true
    @Published var enableTokenValidationNotifications = true
    @Published var autoSyncInterval: TimeInterval = 900 // 15 minutes
    @Published var cacheSize = "Calculating..."
    @Published var showingClearCacheAlert = false
    @Published var errorMessage: String?
    
    private let userDefaults = UserDefaults.standard
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    init() {
        loadSettings()
        calculateCacheSize()
    }
    
    func loadSettings() {
        enableHapticFeedback = userDefaults.bool(forKey: "enableHapticFeedback")
        enableWidgetNotifications = userDefaults.bool(forKey: "enableWidgetNotifications")
        enableTokenValidationNotifications = userDefaults.bool(forKey: "enableTokenValidationNotifications")
        autoSyncInterval = userDefaults.double(forKey: "autoSyncInterval")
        
        // Set defaults if first launch
        if !userDefaults.bool(forKey: "hasLaunchedBefore") {
            enableHapticFeedback = true
            enableWidgetNotifications = true
            enableTokenValidationNotifications = true
            autoSyncInterval = 900
            saveSettings()
            userDefaults.set(true, forKey: "hasLaunchedBefore")
        }
    }
    
    func saveSettings() {
        userDefaults.set(enableHapticFeedback, forKey: "enableHapticFeedback")
        userDefaults.set(enableWidgetNotifications, forKey: "enableWidgetNotifications")
        userDefaults.set(enableTokenValidationNotifications, forKey: "enableTokenValidationNotifications")
        userDefaults.set(autoSyncInterval, forKey: "autoSyncInterval")
    }
    
    func calculateCacheSize() {
        Task {
            let size = await getCacheSizeInMB()
            await MainActor.run {
                self.cacheSize = String(format: "%.1f MB", size)
            }
        }
    }
    
    func clearCache(dataManager: DataManager) {
        Task {
            await dataManager.cleanupExpiredCache()
            calculateCacheSize()
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func openSupport() {
        if let url = URL(string: "mailto:support@nobuddy.app") {
            UIApplication.shared.open(url)
        }
    }
    
    func openPrivacyPolicy() {
        if let url = URL(string: "https://nobuddy.app/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/idXXXXXXXXXX?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
    
    private func getCacheSizeInMB() async -> Double {
        // Calculate the size of cached data
        // This is a simplified implementation
        let appGroupIdentifier = "group.com.nobuddy.shared"
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return 0.0
        }
        
        let storeURL = containerURL.appendingPathComponent("NoBuddyDataModel.sqlite")
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
            if let fileSize = attributes[.size] as? NSNumber {
                return Double(fileSize.intValue) / (1024 * 1024) // Convert to MB
            }
        } catch {
            // File doesn't exist or can't be read
        }
        
        return 0.0
    }
}

#Preview {
    SettingsView()
        .environmentObject(SecureTokenManager())
        .environmentObject(DataManager())
}