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
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId),
              let data = sharedDefaults.data(forKey: configKey) else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let config = try decoder.decode(SimpleConfig.self, from: data)
            return config.selectedDatabases.filter(\.isSelected)
        } catch {
            print("[WidgetSupport] Failed to decode config: \(error)")
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