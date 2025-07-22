import Foundation

// Note: TaskCache and CDDatabase are imported from the main app target
// This file can be used in both main app and widget extension

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

/// Model for selected database (bridge between app and widget)
struct SelectedDatabase {
    let id: String
    let name: String
    let icon: DatabaseIcon?
    let isSelected: Bool
    let selectedAt: Date
    let workspaceName: String?
    
    init(from database: DatabaseInfo, isSelected: Bool = true, workspaceName: String? = nil) {
        self.id = database.id
        self.name = database.title
        self.icon = DatabaseIcon.emoji(database.icon ?? "📋")
        self.isSelected = isSelected
        self.selectedAt = Date()
        self.workspaceName = workspaceName
    }
    
    init(from database: NotionDatabase, isSelected: Bool = true, workspaceName: String? = nil) {
        self.id = database.id
        self.name = database.displayTitle
        self.icon = database.icon
        self.isSelected = isSelected
        self.selectedAt = Date()
        self.workspaceName = workspaceName
    }
}

/// Database icon type
enum DatabaseIcon {
    case emoji(String)
    case url(String)
    
    var displayIcon: String {
        switch self {
        case .emoji(let emoji):
            return emoji
        case .url(_):
            return "📋" // Fallback for URL-based icons
        }
    }
}

// MARK: - Widget Task Models

/// Simplified task structure optimized for widget display and UserDefaults storage
struct WidgetTask: Identifiable, Codable {
    let id: String
    let title: String
    let isComplete: Bool
    let dueDate: Date?
    let priority: TaskCache.Priority
    let status: TaskCache.TaskStatus
    let lastUpdated: Date
    let isOverdue: Bool
    let isDueToday: Bool
    
    /// Initialize from TaskCache object
    init(id: String, title: String, isComplete: Bool, dueDate: Date?, 
         priority: TaskCache.Priority, status: TaskCache.TaskStatus, 
         lastUpdated: Date, isOverdue: Bool = false, isDueToday: Bool = false) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
        self.dueDate = dueDate
        self.priority = priority
        self.status = status
        self.lastUpdated = lastUpdated
        self.isOverdue = isOverdue
        self.isDueToday = isDueToday
    }
    
    /// Simplified initializer for basic task info
    init(id: String, title: String, isComplete: Bool = false, dueDate: Date? = nil) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
        self.dueDate = dueDate
        self.priority = .none
        self.status = isComplete ? .done : .notStarted
        self.lastUpdated = Date()
        self.isOverdue = false
        self.isDueToday = false
    }
}

/// Cache structure for storing tasks in UserDefaults
struct WidgetTasksCache: Codable {
    let databaseId: String
    let databaseName: String
    let tasks: [WidgetTask]
    let cachedAt: Date
    let version: Int
    
    /// Check if cache is stale
    func isStale(maxAge: TimeInterval = 300) -> Bool {
        return Date().timeIntervalSince(cachedAt) > maxAge
    }
    
    /// Get cache age in seconds
    var ageInSeconds: TimeInterval {
        return Date().timeIntervalSince(cachedAt)
    }
}

// MARK: - Task Caching for Widgets

extension WidgetDataManager {
    
    /// Cache tasks for a specific database in UserDefaults for widget access
    /// - Parameters:
    ///   - databaseId: The database ID these tasks belong to
    ///   - databaseName: Human-readable database name
    ///   - tasks: Array of WidgetTask objects
    static func cacheTasksForDatabase(databaseId: String, databaseName: String, tasks: [WidgetTask]) {
        let cacheKey = "widget_tasks_\(databaseId)"
        
        print("[WidgetDataManager] 📦 Caching \(tasks.count) tasks for database: \(databaseName)")
        
        // Create cache structure with metadata
        let cache = WidgetTasksCache(
            databaseId: databaseId,
            databaseName: databaseName,
            tasks: tasks,
            cachedAt: Date(),
            version: 1
        )
        
        // Serialize and store in shared UserDefaults
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            
            guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId) else {
                print("[WidgetDataManager] ❌ Failed to access shared UserDefaults")
                return
            }
            
            sharedDefaults.set(data, forKey: cacheKey)
            
            // Also update the database list cache with updated timestamp
            updateDatabaseCacheTimestamp(databaseId: databaseId)
            
            print("[WidgetDataManager] ✅ Successfully cached \(tasks.count) tasks for \(databaseId)")
            
        } catch {
            print("[WidgetDataManager] ❌ Failed to cache tasks: \(error)")
        }
    }
    
    /// Legacy method for backwards compatibility with Core Data objects
    /// - Parameters:
    ///   - database: The database these tasks belong to  
    ///   - tasks: Array of TaskCache objects from Core Data
    ///   - limit: Maximum number of tasks to cache (default: 10)
    @available(*, deprecated, message: "Use cacheTasksForDatabase(databaseId:databaseName:tasks:) instead")
    static func cacheTasksForWidget(database: CDDatabase, tasks: [TaskCache], limit: Int = 10) {
        // This method is deprecated but kept for backwards compatibility
        print("[WidgetDataManager] ⚠️ Using deprecated cacheTasksForWidget method. Please update to use cacheTasksForDatabase instead.")
    }
    
    /// Retrieve cached tasks for a specific database
    /// - Parameters:
    ///   - databaseId: The database ID to retrieve tasks for
    ///   - maxAge: Maximum age of cache in seconds (default: 300 = 5 minutes)
    /// - Returns: Array of WidgetTask objects or nil if cache is invalid/expired
    static func getCachedTasks(for databaseId: String, maxAge: TimeInterval = 300) -> [WidgetTask]? {
        let cacheKey = "widget_tasks_\(databaseId)"
        
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId),
              let data = sharedDefaults.data(forKey: cacheKey) else {
            print("[WidgetDataManager] No cached tasks found for database: \(databaseId)")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cache = try decoder.decode(WidgetTasksCache.self, from: data)
            
            // Check cache staleness
            let cacheAge = Date().timeIntervalSince(cache.cachedAt)
            if cacheAge > maxAge {
                print("[WidgetDataManager] Cache for \(databaseId) is stale (\(Int(cacheAge))s old)")
                return nil
            }
            
            print("[WidgetDataManager] ✅ Retrieved \(cache.tasks.count) cached tasks for \(databaseId)")
            return cache.tasks
            
        } catch {
            print("[WidgetDataManager] ❌ Failed to decode cached tasks: \(error)")
            return nil
        }
    }
    
    /// Get all cached tasks for all selected databases
    /// - Parameter maxAge: Maximum age of cache in seconds (default: 300 = 5 minutes)
    /// - Returns: Dictionary mapping database ID to tasks array
    static func getAllCachedTasks(maxAge: TimeInterval = 300) -> [String: [WidgetTask]] {
        let selectedDatabases = getSelectedDatabasesForWidget()
        var allTasks: [String: [WidgetTask]] = [:]
        
        for database in selectedDatabases {
            if let tasks = getCachedTasks(for: database.id, maxAge: maxAge) {
                allTasks[database.id] = tasks
            }
        }
        
        print("[WidgetDataManager] Retrieved cached tasks for \(allTasks.count) databases")
        return allTasks
    }
    
    /// Clear cached tasks for a specific database
    /// - Parameter databaseId: The database ID to clear cache for
    static func clearCachedTasks(for databaseId: String) {
        let cacheKey = "widget_tasks_\(databaseId)"
        
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId) else {
            return
        }
        
        sharedDefaults.removeObject(forKey: cacheKey)
        print("[WidgetDataManager] ✅ Cleared cached tasks for database: \(databaseId)")
    }
    
    /// Clear all cached tasks
    static func clearAllCachedTasks() {
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId) else {
            return
        }
        
        let selectedDatabases = getSelectedDatabasesForWidget()
        for database in selectedDatabases {
            let cacheKey = "widget_tasks_\(database.id)"
            sharedDefaults.removeObject(forKey: cacheKey)
        }
        
        print("[WidgetDataManager] ✅ Cleared all cached tasks")
    }
    
    /// Get cache info for all databases (useful for debugging)
    static func getCacheInfo() -> [String: Any] {
        let selectedDatabases = getSelectedDatabasesForWidget()
        var cacheInfo: [String: Any] = [:]
        
        for database in selectedDatabases {
            let cacheKey = "widget_tasks_\(database.id)"
            
            guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId),
                  let data = sharedDefaults.data(forKey: cacheKey) else {
                cacheInfo[database.id] = "No cache"
                continue
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let cache = try decoder.decode(WidgetTasksCache.self, from: data)
                
                let cacheAge = Date().timeIntervalSince(cache.cachedAt)
                cacheInfo[database.id] = [
                    "taskCount": cache.tasks.count,
                    "cachedAt": cache.cachedAt,
                    "ageSeconds": Int(cacheAge),
                    "isStale": cacheAge > 300
                ]
            } catch {
                cacheInfo[database.id] = "Decode error: \(error.localizedDescription)"
            }
        }
        
        return cacheInfo
    }
    
    /// Helper method to update database cache timestamp
    private static func updateDatabaseCacheTimestamp(databaseId: String) {
        // This helps track when database content was last updated
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId) else { return }
        
        let timestampKey = "widget_db_timestamp_\(databaseId)"
        sharedDefaults.set(Date(), forKey: timestampKey)
    }
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