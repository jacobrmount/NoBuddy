import Foundation
import Combine

/// ViewModel for the dashboard view
@MainActor
class DashboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var stats = DashboardStats()
    @Published var recentDatabases: [CachedDatabase] = []
    @Published var recentPages: [CachedPage] = []
    @Published var isLoading = false
    @Published var error: DataError?
    
    // MARK: - Private Properties
    private let tokenManager: SecureTokenManager
    private let dataManager: DataManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(tokenManager: SecureTokenManager, dataManager: DataManager) {
        self.tokenManager = tokenManager
        self.dataManager = dataManager
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func loadDashboardData() {
        isLoading = true
        defer { isLoading = false }
        
        // Load cached data for all tokens
        var allDatabases: [CachedDatabase] = []
        var allPages: [CachedPage] = []
        
        for token in tokenManager.tokens {
            let databases = dataManager.fetchCachedDatabases(for: token.id)
            let pages = dataManager.fetchCachedPages(for: token.id)
            
            allDatabases.append(contentsOf: databases)
            allPages.append(contentsOf: pages)
        }
        
        // Sort by last cached date
        recentDatabases = allDatabases.sorted { 
            ($0.lastCached ?? Date.distantPast) > ($1.lastCached ?? Date.distantPast) 
        }
        
        recentPages = allPages.sorted { 
            ($0.lastCached ?? Date.distantPast) > ($1.lastCached ?? Date.distantPast) 
        }
        
        updateStats()
    }
    
    func refreshData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Validate all tokens
        await tokenManager.validateAllTokens()
        
        // Refresh data from API for valid tokens
        for token in tokenManager.tokens where token.isValid {
            // TODO: Implement API data refresh
            // This would involve calling the Notion API to get latest data
            // and caching it using the DataManager
        }
        
        // Reload dashboard data
        loadDashboardData()
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        dataManager.$error
            .assign(to: \.error, on: self)
            .store(in: &cancellables)
        
        // Reload dashboard when tokens change
        tokenManager.$tokens
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadDashboardData()
            }
            .store(in: &cancellables)
    }
    
    private func updateStats() {
        let lastSync = recentDatabases.first?.lastCached ?? recentPages.first?.lastCached
        
        stats = DashboardStats(
            databaseCount: recentDatabases.count,
            pageCount: recentPages.count,
            tokenCount: tokenManager.tokens.count,
            lastSync: lastSync
        )
    }
}