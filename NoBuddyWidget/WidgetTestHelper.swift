//
//  WidgetTestHelper.swift
//  NoBuddyWidget
//
//  Created by Assistant on 7/28/25.
//

import Foundation

/// Helper to populate test data for widget testing
struct WidgetTestHelper {
    
    static let sharedGroupId = "group.com.nobuddy.app"
    
    /// Populate sample databases in the cache for testing
    static func populateSampleDatabases() {
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId) else {
            print("[WidgetTestHelper] ❌ Failed to access shared UserDefaults")
            return
        }
        
        // Create sample databases
        let sampleDatabases = [
            WidgetDatabase(
                id: "db1",
                name: "My Tasks",
                icon: "✅",
                iconURL: nil,
                isSelected: false,
                selectedAt: Date(),
                workspaceName: "Personal Workspace"
            ),
            WidgetDatabase(
                id: "db2",
                name: "Project Tracker",
                icon: "📊",
                iconURL: nil,
                isSelected: false,
                selectedAt: Date(),
                workspaceName: "Personal Workspace"
            ),
            WidgetDatabase(
                id: "db3",
                name: "Meeting Notes",
                icon: "📝",
                iconURL: nil,
                isSelected: false,
                selectedAt: Date(),
                workspaceName: "Work Workspace"
            ),
            WidgetDatabase(
                id: "db4",
                name: "Reading List",
                icon: "📚",
                iconURL: nil,
                isSelected: false,
                selectedAt: Date(),
                workspaceName: "Personal Workspace"
            )
        ]
        
        // Create cache object
        let cache = AvailableDatabasesCache(
            version: 1,
            databases: sampleDatabases,
            cachedAt: Date()
        )
        
        // Encode and save
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            
            sharedDefaults.set(data, forKey: "available_databases_cache")
            print("[WidgetTestHelper] ✅ Populated \(sampleDatabases.count) sample databases")
            
            // Also set a sample selected database configuration
            let selectedConfig = SimpleConfig(
                tokenId: UUID().uuidString,
                workspaceName: "Personal Workspace",
                selectedDatabases: [
                    SimpleDatabase(
                        id: "db1",
                        name: "My Tasks",
                        icon: "✅",
                        isSelected: true,
                        selectedAt: Date(),
                        workspaceName: "Personal Workspace"
                    )
                ],
                lastUpdated: Date()
            )
            
            let configData = try encoder.encode(selectedConfig)
            sharedDefaults.set(configData, forKey: "database_selection_config")
            print("[WidgetTestHelper] ✅ Set default selected database")
            
        } catch {
            print("[WidgetTestHelper] ❌ Failed to populate sample data: \(error)")
        }
    }
    
    /// Clear all widget-related data from UserDefaults
    static func clearAllData() {
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId) else {
            print("[WidgetTestHelper] ❌ Failed to access shared UserDefaults")
            return
        }
        
        sharedDefaults.removeObject(forKey: "available_databases_cache")
        sharedDefaults.removeObject(forKey: "database_selection_config")
        
        print("[WidgetTestHelper] ✅ Cleared all widget data")
    }
    
    /// Check current state of widget data
    static func printCurrentState() {
        print("\n[WidgetTestHelper] Current Widget Data State:")
        print("================================================")
        
        // Check available databases
        let availableDatabases = WidgetSupport.getAvailableDatabasesFromCache()
        print("Available Databases: \(availableDatabases.count)")
        for db in availableDatabases {
            print("  - \(db.icon) \(db.name) (ID: \(db.id))")
        }
        
        // Check selected databases
        let selectedDatabases = WidgetSupport.getSelectedDatabasesForWidget()
        print("\nSelected Databases: \(selectedDatabases.count)")
        for db in selectedDatabases {
            print("  - \(db.icon) \(db.name) (ID: \(db.id))")
        }
        
        print("================================================\n")
    }
}

// Models are now available from WidgetSupport.swift
