import Foundation

/// Debug helper for checking widget cache state
class WidgetDebugHelper {
    
    private static let sharedGroupId = "group.com.nobuddy.app"
    
    /// Print the current state of widget caches
    static func printWidgetCacheState() {
        print("\n=== WIDGET CACHE STATE ===")
        
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId) else {
            print("❌ Failed to access shared UserDefaults")
            return
        }
        
        // Check available databases cache
        if let availableData = sharedDefaults.data(forKey: "available_databases_cache") {
            print("\n📦 Available Databases Cache:")
            print("  - Size: \(availableData.count) bytes")
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let cache = try decoder.decode(DebugAvailableDatabasesCache.self, from: availableData)
                print("  - Version: \(cache.version)")
                print("  - Database count: \(cache.databases.count)")
                print("  - Cached at: \(cache.cachedAt)")
                print("  - Databases:")
                for db in cache.databases {
                    print("    • \(db.name) (ID: \(db.id))")
                }
            } catch {
                print("  ❌ Failed to decode: \(error)")
            }
        } else {
            print("\n❌ No available databases cache found")
        }
        
        // Check selected databases config
        if let configData = sharedDefaults.data(forKey: "database_selection_config") {
            print("\n✅ Selected Databases Config:")
            print("  - Size: \(configData.count) bytes")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            // Try SimpleConfig format first
            if let simpleConfig = try? decoder.decode(DebugSimpleConfig.self, from: configData) {
                print("  - Format: SimpleConfig")
                print("  - Token ID: \(simpleConfig.tokenId)")
                print("  - Workspace: \(simpleConfig.workspaceName ?? "none")")
                print("  - Selected count: \(simpleConfig.selectedDatabases.filter(\.isSelected).count)")
                print("  - Selected databases:")
                for db in simpleConfig.selectedDatabases.filter(\.isSelected) {
                    print("    • \(db.name) (ID: \(db.id))")
                }
            } else {
                print("  ❌ Failed to decode as SimpleConfig")
            }
        } else {
            print("\n❌ No selected databases config found")
        }
        
        // List all keys in shared defaults
        print("\n🔑 All keys in shared UserDefaults:")
        let allKeys = sharedDefaults.dictionaryRepresentation().keys.sorted()
        for key in allKeys {
            if let data = sharedDefaults.data(forKey: key) {
                print("  - \(key): \(data.count) bytes")
            } else if let value = sharedDefaults.object(forKey: key) {
                print("  - \(key): \(type(of: value))")
            }
        }
        
        print("\n=========================\n")
    }
    
    /// Call this method from somewhere in your app to debug
    static func debugWidgetSetup() {
        print("\n🔍 DEBUGGING WIDGET SETUP")
        printWidgetCacheState()
        
        // Check if databases need to be cached
        if !hasCachedDatabases() {
            print("⚠️ No databases cached for widget. Please:")
            print("1. Open Edit Token view")
            print("2. Ensure databases are loaded")
            print("3. Or tap Refresh in the database selection")
        }
    }
    
    private static func hasCachedDatabases() -> Bool {
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId),
              let _ = sharedDefaults.data(forKey: "available_databases_cache") else {
            return false
        }
        return true
    }
}

// MARK: - Models (duplicated for debug helper)

private struct DebugAvailableDatabasesCache: Codable {
    let version: Int
    let databases: [DebugWidgetDatabase]
    let cachedAt: Date
}

private struct DebugWidgetDatabase: Codable {
    let id: String
    let name: String
    let icon: String
    let iconURL: String?
    let isSelected: Bool
    let selectedAt: Date
    let workspaceName: String?
}

private struct DebugSimpleConfig: Codable {
    let tokenId: String
    let workspaceName: String?
    let selectedDatabases: [DebugSimpleDatabase]
    let lastUpdated: Date
}

private struct DebugSimpleDatabase: Codable {
    let id: String
    let name: String
    let icon: String
    let isSelected: Bool
    let selectedAt: Date
    let workspaceName: String?
}
