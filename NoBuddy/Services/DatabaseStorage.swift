import Foundation
import WidgetKit

/// Simple storage for database selections using UserDefaults
class DatabaseStorage {
    private let userDefaults = UserDefaults.standard
    private let sharedDefaults = UserDefaults(suiteName: "group.com.nobuddy.app")
    private let selectedDatabasesKey = "selected_database_ids"
    private let configKey = "database_selection_config"
    
    /// Current databases for widget updates
    private var currentDatabases: [NotionDatabase] = []
    private var currentTokenId: UUID?
    private var currentWorkspaceName: String?
    
    /// Set current context for widget updates
    func setContext(databases: [NotionDatabase], tokenId: UUID?, workspaceName: String?) {
        self.currentDatabases = databases
        self.currentTokenId = tokenId
        self.currentWorkspaceName = workspaceName
    }
    
    /// Save selected database IDs
    func saveSelectedDatabases(_ databaseIds: [String]) {
        userDefaults.set(databaseIds, forKey: selectedDatabasesKey)
        print("✅ Saved \(databaseIds.count) database selections")
        
        // Update widget data if we have context
        if let tokenId = currentTokenId {
            updateWidgetData(selectedIds: databaseIds, tokenId: tokenId)
        }
    }
    
    /// Update widget data with selected databases
    private func updateWidgetData(selectedIds: [String], tokenId: UUID) {
        // Convert selected databases for widget using the SimpleDatabase model
        let selectedDatabases = currentDatabases
            .filter { selectedIds.contains($0.id) }
            .map { database in
                SimpleDatabase(
                    id: database.id,
                    name: database.displayTitle,
                    icon: database.icon?.displayIcon ?? "📋",
                    isSelected: true,
                    selectedAt: Date(),
                    workspaceName: currentWorkspaceName
                )
            }
        
        // Create configuration for widget
        let config = SimpleConfig(
            tokenId: tokenId.uuidString,
            workspaceName: currentWorkspaceName,
            selectedDatabases: selectedDatabases,
            lastUpdated: Date()
        )
        
        // Save to shared UserDefaults for widget access
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(config)
            
            if let sharedDefaults = sharedDefaults {
                sharedDefaults.set(data, forKey: configKey)
                print("✅ Updated widget configuration with \(selectedDatabases.count) selected databases")
            }
        } catch {
            print("❌ Failed to update widget configuration: \(error)")
        }
        
        // Reload widget timelines
        WidgetCenter.shared.reloadAllTimelines()
        
        print("🔄 Reloaded widget timelines")
    }
    
    /// Load selected database IDs
    func loadSelectedDatabases() -> [String] {
        let ids = userDefaults.array(forKey: selectedDatabasesKey) as? [String] ?? []
        print("📖 Loaded \(ids.count) saved database selections")
        return ids
    }
    
    /// Check if a database is selected
    func isDatabaseSelected(_ databaseId: String) -> Bool {
        let selectedIds = loadSelectedDatabases()
        return selectedIds.contains(databaseId)
    }
    
    /// Clear all selections
    func clearAllSelections() {
        userDefaults.removeObject(forKey: selectedDatabasesKey)
        print("🗑️ Cleared all database selections")
    }
    
    /// Toggle selection for a database
    func toggleDatabase(_ databaseId: String) {
        var selectedIds = loadSelectedDatabases()
        
        if let index = selectedIds.firstIndex(of: databaseId) {
            selectedIds.remove(at: index)
        } else {
            selectedIds.append(databaseId)
        }
        
        saveSelectedDatabases(selectedIds)
    }
}

// MARK: - Models for Widget Communication

/// Simplified database model for widget use
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
