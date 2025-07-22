import Foundation

/// Simple widget support for database selection
/// This file is specifically for the widget target to avoid compilation issues
struct WidgetSupport {
    
    // MARK: - Constants
    
    private static let sharedGroupId = "group.com.nobuddy.app"
    private static let configKey = "database_selection_config"
    
    // MARK: - Widget Database Access
    
    /// Get selected databases for widget display
    static func getSelectedDatabasesForWidget() -> [SimpleDatabase] {
        print("[WidgetSupport] Getting selected databases for widget")
        print("[WidgetSupport] Using App Group ID: \(sharedGroupId)")
        print("[WidgetSupport] Using config key: \(configKey)")
        
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId) else {
            print("[WidgetSupport] ❌ Failed to create UserDefaults with suite: \(sharedGroupId)")
            return []
        }
        
        guard let data = sharedDefaults.data(forKey: configKey) else {
            print("[WidgetSupport] ❌ No data found for key: \(configKey)")
            // Let's check what keys exist
            let allKeys = sharedDefaults.dictionaryRepresentation().keys
            print("[WidgetSupport] Available keys: \(Array(allKeys))")
            
            // Also check for other possible keys that might be used
            let possibleKeys = [
                "database_selection_config",
                "selected_database_ids", 
                "available_databases_cache",
                "widget_config",
                "databases_config"
            ]
            
            for key in possibleKeys {
                if let testData = sharedDefaults.data(forKey: key) {
                    print("[WidgetSupport] ✅ Found data for key '\(key)': \(testData.count) bytes")
                } else if let testObject = sharedDefaults.object(forKey: key) {
                    print("[WidgetSupport] ✅ Found object for key '\(key)': \(type(of: testObject))")
                } else {
                    print("[WidgetSupport] ❌ No data for key '\(key)'")
                }
            }
            return []
        }
        
        print("[WidgetSupport] ✅ Found config data, size: \(data.count) bytes")
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Try decoding as SimpleConfig first (new format from main app)
            if let simpleConfig = try? decoder.decode(SimpleConfig.self, from: data) {
                print("[WidgetSupport] ✅ Successfully decoded SimpleConfig")
                print("[WidgetSupport] Total databases: \(simpleConfig.selectedDatabases.count)")
                
                let selected = simpleConfig.selectedDatabases.filter(\.isSelected)
                print("[WidgetSupport] Selected databases: \(selected.count)")
                
                for db in selected {
                    print("[WidgetSupport]   - \(db.name) (ID: \(db.id))")
                }
                return selected
            }
            
            // Fallback to WidgetDatabaseConfig format (legacy)
            let config = try decoder.decode(WidgetDatabaseConfig.self, from: data)
            print("[WidgetSupport] ✅ Successfully decoded WidgetDatabaseConfig")
            print("[WidgetSupport] Total databases: \(config.selectedDatabases.count)")
            
            let selected = config.selectedDatabases.filter(\.isSelected)
            print("[WidgetSupport] Selected databases: \(selected.count)")
            
            // Convert WidgetDatabase to SimpleDatabase for backward compatibility
            let simpleDatabases = selected.map { widgetDB in
                SimpleDatabase(
                    id: widgetDB.id,
                    name: widgetDB.name,
                    icon: widgetDB.icon,
                    isSelected: widgetDB.isSelected,
                    selectedAt: widgetDB.selectedAt,
                    workspaceName: widgetDB.workspaceName
                )
            }
            
            for db in simpleDatabases {
                print("[WidgetSupport]   - \(db.name) (ID: \(db.id))")
            }
            return simpleDatabases
        } catch {
            print("[WidgetSupport] ❌ Failed to decode config: \(error)")
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
}

// MARK: - Simple Models for Widget

/// Simplified database model for widget use only
struct SimpleDatabase: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let isSelected: Bool
    let selectedAt: Date
    let workspaceName: String?
}

/// Simple configuration for widget
struct SimpleConfig: Codable {
    let tokenId: String
    let workspaceName: String?
    let selectedDatabases: [SimpleDatabase]
    let lastUpdated: Date
}

/// Widget-specific database configuration (matches main app's WidgetDataManager)
struct WidgetDatabaseConfig: Codable {
    let tokenId: UUID
    let workspaceName: String?
    let selectedDatabases: [WidgetDatabase]
    let lastUpdated: Date
}

/// Widget database model (matches main app's WidgetDataManager)
struct WidgetDatabase: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let iconURL: String?
    let isSelected: Bool
    let selectedAt: Date
    let workspaceName: String?
}