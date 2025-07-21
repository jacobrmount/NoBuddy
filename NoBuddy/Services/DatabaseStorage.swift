import Foundation

/// Simple storage for database selections using UserDefaults
class DatabaseStorage {
    private let userDefaults = UserDefaults.standard
    private let selectedDatabasesKey = "selected_database_ids"
    
    /// Save selected database IDs
    func saveSelectedDatabases(_ databaseIds: [String]) {
        userDefaults.set(databaseIds, forKey: selectedDatabasesKey)
        print("✅ Saved \(databaseIds.count) database selections")
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