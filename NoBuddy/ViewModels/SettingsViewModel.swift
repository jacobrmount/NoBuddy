import Foundation
import Combine

/// ViewModel for the settings view
@MainActor
class SettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var notificationsEnabled = false
    @Published var autoCleanupEnabled = true
    @Published var cacheSize = "0 MB"
    @Published var isClearing = false
    @Published var showingClearAlert = false
    @Published var error: DataError?
    
    // MARK: - Private Properties
    private let dataManager: DataManager
    private let tokenManager: SecureTokenManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(dataManager: DataManager, tokenManager: SecureTokenManager) {
        self.dataManager = dataManager
        self.tokenManager = tokenManager
        setupBindings()
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    func loadSettings() {
        // Load user preferences from UserDefaults
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
        autoCleanupEnabled = UserDefaults.standard.bool(forKey: "auto_cleanup_enabled")
        
        // Calculate cache size
        calculateCacheSize()
    }
    
    func saveSettings() {
        UserDefaults.standard.set(notificationsEnabled, forKey: "notifications_enabled")
        UserDefaults.standard.set(autoCleanupEnabled, forKey: "auto_cleanup_enabled")
    }
    
    func clearAllData() {
        isClearing = true
        
        Task {
            await dataManager.clearAllCachedData()
            
            // Recalculate cache size
            calculateCacheSize()
            
            isClearing = false
        }
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Computed Properties
    
    var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var tokenCount: Int {
        return tokenManager.tokens.count
    }
    
    var validTokenCount: Int {
        return tokenManager.tokens.filter { $0.isValid }.count
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        dataManager.$error
            .assign(to: \.error, on: self)
            .store(in: &cancellables)
        
        // Save settings when they change
        $notificationsEnabled
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
        
        $autoCleanupEnabled
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }
    
    private func calculateCacheSize() {
        // TODO: Implement actual cache size calculation
        // This would involve calculating the size of all Core Data entities
        // For now, use a placeholder
        cacheSize = "2.4 MB"
    }
}

// MARK: - Settings Keys

extension SettingsViewModel {
    private enum SettingsKeys {
        static let notificationsEnabled = "notifications_enabled"
        static let autoCleanupEnabled = "auto_cleanup_enabled"
        static let lastCleanupDate = "last_cleanup_date"
    }
}