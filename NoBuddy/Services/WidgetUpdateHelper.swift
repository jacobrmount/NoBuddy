import Foundation
import WidgetKit

/// Helper class to handle widget updates from the main app
/// This encapsulates widget-related functionality that requires access to shared modules
@MainActor
class WidgetUpdateHelper {
    
    // MARK: - Constants
    private static let sharedGroupId = "group.com.nobuddy.app"
    private static let availableDatabasesKey = "available_databases_cache"
    private static let cacheVersion = 1
    
    /// Clear the databases cache for widgets
    static func clearDatabasesCache() {
        // Clear the cache directly from UserDefaults
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId) else { return }
        sharedDefaults.removeObject(forKey: availableDatabasesKey)
        print("[WidgetUpdateHelper] ✅ Cleared databases cache")
    }
    
    /// Cache databases from API for widget use
    static func cacheDatabasesFromAPI(_ databases: [NotionDatabase], workspaceName: String?) {
        // Convert NotionDatabase to simplified format for widgets
        let widgetDatabases = databases.map { database in
            WidgetDatabase(
                id: database.id,
                name: database.displayTitle,
                icon: database.icon?.displayIcon ?? "📋",
                iconURL: nil,
                isSelected: false,
                selectedAt: Date(),
                workspaceName: workspaceName
            )
        }
        
        // Create cache object
        let cache = AvailableDatabasesCache(
            version: cacheVersion,
            databases: widgetDatabases,
            cachedAt: Date()
        )
        
        // Save to shared UserDefaults
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            
            if let sharedDefaults = UserDefaults(suiteName: sharedGroupId) {
                sharedDefaults.set(data, forKey: availableDatabasesKey)
                print("[WidgetUpdateHelper] ✅ Cached \(databases.count) databases for widgets")
            }
        } catch {
            print("[WidgetUpdateHelper] ❌ Failed to cache databases: \(error)")
        }
    }
    
    /// Reload all widget timelines
    static func reloadAllWidgets() async {
        await MainActor.run {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

// MARK: - Widget-Specific Models (Duplicated here to avoid dependency issues)

/// Simplified database model for widget use
fileprivate struct WidgetDatabase: Codable {
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

/// Cache structure for available databases
fileprivate struct AvailableDatabasesCache: Codable {
    let version: Int
    let databases: [WidgetDatabase]
    let cachedAt: Date
}

// MARK: - Extension for SecureTokenManager compatibility

extension SecureTokenManager {
    /// Helper method to handle widget updates when refreshing databases
    func updateWidgetsAfterDatabaseRefresh(_ databases: [NotionDatabase], workspaceName: String?) async {
        // Clear cache
        WidgetUpdateHelper.clearDatabasesCache()
        
        // Cache new databases (will be a no-op if WidgetDataManager isn't available)
        WidgetUpdateHelper.cacheDatabasesFromAPI(databases, workspaceName: workspaceName)
        
        // Reload widgets
        await WidgetUpdateHelper.reloadAllWidgets()
    }
}
