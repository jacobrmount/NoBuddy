import Foundation

/// Shared data manager for widget access to selected databases
/// This file should be included in both the main app target and widget extension target
struct WidgetDataManager {
    
    // MARK: - Constants
    
    private static let sharedGroupId = "group.com.nobuddy.app"
    private static let configKey = "database_selection_config"
    private static let availableDatabasesKey = "available_databases_cache"
    private static let cacheVersion = 1
    
    // MARK: - Database Selection for Widgets
    
    /// Get selected databases for widget display
    static func getSelectedDatabasesForWidget() -> [WidgetDatabase] {
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId),
              let data = sharedDefaults.data(forKey: configKey) else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let config = try decoder.decode(WidgetDatabaseConfig.self, from: data)
            return config.selectedDatabases.filter(\.isSelected)
        } catch {
            print("[WidgetDataManager] Failed to decode database config: \(error)")
            return []
        }
    }
    
    /// Check if widget needs configuration
    static func widgetNeedsConfiguration() -> Bool {
        return getSelectedDatabasesForWidget().isEmpty
    }
    
    /// Get database count for widget display
    static func getSelectedDatabaseCount() -> Int {
        return getSelectedDatabasesForWidget().count
    }
    
    /// Update widget data from main app (called by DatabaseSelectionManager)
    static func updateWidgetData(from databases: [SelectedDatabase], tokenId: UUID, workspaceName: String?) {
        let widgetDatabases = databases.map { database in
            WidgetDatabase(
                id: database.id,
                name: database.name,
                icon: database.icon?.displayIcon ?? "📋",
                iconURL: nil, // Legacy support - no URL for selected databases
                isSelected: database.isSelected,
                selectedAt: database.selectedAt,
                workspaceName: database.workspaceName
            )
        }
        
        let config = WidgetDatabaseConfig(
            tokenId: tokenId,
            workspaceName: workspaceName,
            selectedDatabases: widgetDatabases,
            lastUpdated: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(config)
            
            if let sharedDefaults = UserDefaults(suiteName: sharedGroupId) {
                sharedDefaults.set(data, forKey: configKey)
                print("[WidgetDataManager] ✅ Updated widget data with \(widgetDatabases.count) databases")
            }
        } catch {
            print("[WidgetDataManager] ❌ Failed to update widget data: \(error)")
        }
    }
    
    // MARK: - Available Databases Cache
    
    /// Cache available databases for widget access
    static func cacheDatabases(_ databases: [WidgetDatabase]) {
        let cache = AvailableDatabasesCache(
            version: cacheVersion,
            databases: databases,
            cachedAt: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            
            if let sharedDefaults = UserDefaults(suiteName: sharedGroupId) {
                sharedDefaults.set(data, forKey: availableDatabasesKey)
                print("[WidgetDataManager] ✅ Cached \(databases.count) available databases")
            }
        } catch {
            print("[WidgetDataManager] ❌ Failed to cache databases: \(error)")
        }
    }
    
    /// Get available databases from cache (for widget use)
    static func getAvailableDatabases() -> [WidgetDatabase] {
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId),
              let data = sharedDefaults.data(forKey: availableDatabasesKey) else {
            print("[WidgetDataManager] No cached databases found")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cache = try decoder.decode(AvailableDatabasesCache.self, from: data)
            
            // Check cache version for future compatibility
            guard cache.version == cacheVersion else {
                print("[WidgetDataManager] Cache version mismatch, returning empty")
                return []
            }
            
            print("[WidgetDataManager] Retrieved \(cache.databases.count) cached databases")
            return cache.databases
        } catch {
            print("[WidgetDataManager] Failed to decode cached databases: \(error)")
            return []
        }
    }
    
    /// Cache available databases from NotionDatabase objects (called when fetching from API)
    static func cacheDatabasesFromAPI(_ databases: [NotionDatabase], workspaceName: String? = nil) {
        let widgetDatabases = databases.map { database in
            WidgetDatabase(
                id: database.id,
                name: database.displayTitle,
                icon: database.icon?.displayIcon ?? "📋",
                iconURL: nil, // NotionDatabase doesn't have external icon URLs
                isSelected: false,
                selectedAt: Date(),
                workspaceName: workspaceName
            )
        }
        cacheDatabases(widgetDatabases)
    }
    
    /// Cache available databases from DatabaseInfo objects (used with enhanced API)
    static func cacheDatabasesFromInfo(_ databases: [DatabaseInfo], workspaceName: String? = nil) {
        let widgetDatabases = databases.map { database in
            WidgetDatabase(
                id: database.id,
                name: database.title,
                icon: database.icon ?? "📋",
                iconURL: nil, // DatabaseInfo uses emoji icons
                isSelected: false,
                selectedAt: Date(),
                workspaceName: workspaceName
            )
        }
        cacheDatabases(widgetDatabases)
    }
    
    /// Check if databases cache exists and is valid
    static func hasCachedDatabases() -> Bool {
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId),
              let data = sharedDefaults.data(forKey: availableDatabasesKey) else {
            return false
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cache = try decoder.decode(AvailableDatabasesCache.self, from: data)
            return cache.version == cacheVersion && !cache.databases.isEmpty
        } catch {
            return false
        }
    }
    
    /// Clear available databases cache
    static func clearDatabasesCache() {
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId) else { return }
        sharedDefaults.removeObject(forKey: availableDatabasesKey)
        print("[WidgetDataManager] ✅ Cleared databases cache")
    }
}

// MARK: - Widget-Specific Models

/// Simplified database model for widget use
struct WidgetDatabase: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let iconURL: String?
    let isSelected: Bool
    let selectedAt: Date
    let workspaceName: String?
    
    init(id: String, name: String, icon: String, iconURL: String? = nil, isSelected: Bool, selectedAt: Date, workspaceName: String?) {
        self.id = id
        self.name = name
        self.icon = icon
        self.iconURL = iconURL
        self.isSelected = isSelected
        self.selectedAt = selectedAt
        self.workspaceName = workspaceName
    }
}

/// Widget-specific database configuration
struct WidgetDatabaseConfig: Codable {
    let tokenId: UUID
    let workspaceName: String?
    let selectedDatabases: [WidgetDatabase]
    let lastUpdated: Date
    
    init(tokenId: UUID, workspaceName: String?, selectedDatabases: [WidgetDatabase], lastUpdated: Date = Date()) {
        self.tokenId = tokenId
        self.workspaceName = workspaceName
        self.selectedDatabases = selectedDatabases
        self.lastUpdated = lastUpdated
    }
}

/// Cache structure for available databases
struct AvailableDatabasesCache: Codable {
    let version: Int
    let databases: [WidgetDatabase]
    let cachedAt: Date
}

// MARK: - Extension for DatabaseSelectionManager Integration

extension WidgetDataManager {
    
    /// Convert SelectedDatabase to WidgetDatabase
    static func convertToWidgetDatabase(_ database: SelectedDatabase) -> WidgetDatabase {
        return WidgetDatabase(
            id: database.id,
            name: database.name,
            icon: database.icon?.displayIcon ?? "📋",
            iconURL: nil, // SelectedDatabase doesn't have icon URL
            isSelected: database.isSelected,
            selectedAt: database.selectedAt,
            workspaceName: database.workspaceName
        )
    }
    
    /// Get the primary selected database name for widget display
    static func getPrimaryDatabaseName() -> String? {
        let databases = getSelectedDatabasesForWidget()
        return databases.first?.name
    }
    
    /// Get workspace name for widget display
    static func getWorkspaceName() -> String? {
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId),
              let data = sharedDefaults.data(forKey: configKey) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let config = try decoder.decode(WidgetDatabaseConfig.self, from: data)
            return config.workspaceName
        } catch {
            return nil
        }
    }
}