import Foundation
import CoreData

#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Type Definitions
// Local definitions to avoid dependency on Shared folder

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
}

/// Cache structure for storing tasks in UserDefaults
private struct WidgetTasksCache: Codable {
    let databaseId: String
    let databaseName: String
    let tasks: [WidgetTask]
    let cachedAt: Date
    let version: Int
    
    /// Check if cache is stale
    func isStale(maxAge: TimeInterval = 300) -> Bool {
        return Date().timeIntervalSince(cachedAt) > maxAge
    }
}

/// Minimal database model for widget access
private struct WidgetDatabase: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let iconURL: String?
    let isSelected: Bool
    let selectedAt: Date
    let workspaceName: String?
}

/// Widget database configuration
private struct WidgetDatabaseConfig: Codable {
    let tokenId: UUID
    let workspaceName: String?
    let selectedDatabases: [WidgetDatabase]
    let lastUpdated: Date
}

/// Simplified WidgetDataManager methods for internal use
private struct InternalWidgetDataManager {
    private static let sharedGroupId = "group.com.nobuddy.app"
    
    static func cacheTasksForDatabase(databaseId: String, databaseName: String, tasks: [WidgetTask]) {
        let cacheKey = "widget_tasks_\(databaseId)"
        
        print("[WidgetDataManager] 📦 Caching \(tasks.count) tasks for database: \(databaseName)")
        
        let cache = WidgetTasksCache(
            databaseId: databaseId,
            databaseName: databaseName,
            tasks: tasks,
            cachedAt: Date(),
            version: 1
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            
            guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId) else {
                print("[WidgetDataManager] ❌ Failed to access shared UserDefaults")
                return
            }
            
            sharedDefaults.set(data, forKey: cacheKey)
            print("[WidgetDataManager] ✅ Successfully cached \(tasks.count) tasks for \(databaseId)")
            
        } catch {
            print("[WidgetDataManager] ❌ Failed to cache tasks: \(error)")
        }
    }
    
    static func getSelectedDatabasesForWidget() -> [WidgetDatabase] {
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId),
              let data = sharedDefaults.data(forKey: "database_selection_config") else {
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
    
    static func getCachedTasks(for databaseId: String, maxAge: TimeInterval = 300) -> [WidgetTask]? {
        let cacheKey = "widget_tasks_\(databaseId)"
        
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId),
              let data = sharedDefaults.data(forKey: cacheKey) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cache = try decoder.decode(WidgetTasksCache.self, from: data)
            
            let cacheAge = Date().timeIntervalSince(cache.cachedAt)
            if cacheAge > maxAge {
                return nil
            }
            
            return cache.tasks
            
        } catch {
            print("[WidgetDataManager] ❌ Failed to decode cached tasks: \(error)")
            return nil
        }
    }
    
    static func clearCachedTasks(for databaseId: String) {
        let cacheKey = "widget_tasks_\(databaseId)"
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId) else { return }
        sharedDefaults.removeObject(forKey: cacheKey)
    }
    
    static func clearAllCachedTasks() {
        let selectedDatabases = getSelectedDatabasesForWidget()
        guard let sharedDefaults = UserDefaults(suiteName: sharedGroupId) else { return }
        
        for database in selectedDatabases {
            let cacheKey = "widget_tasks_\(database.id)"
            sharedDefaults.removeObject(forKey: cacheKey)
        }
    }
    
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
}

/// Service for caching task data specifically for widget consumption
/// This bridges the gap between Core Data (TaskCache) and shared UserDefaults
class WidgetTaskCaching {
    
    // MARK: - Public Interface
    
    /// Cache tasks for widget access from a Core Data database
    /// This method should be called whenever task data is updated in the main app
    /// - Parameters:
    ///   - databaseId: The Notion database ID
    ///   - databaseName: Human-readable database name  
    ///   - tasks: Array of TaskCache objects from Core Data
    ///   - limit: Maximum number of tasks to cache (default: 10)
    static func cacheTasksForWidget(databaseId: String, databaseName: String, tasks: [TaskCache], limit: Int = 10) {
        print("[WidgetTaskCaching] 📦 Caching \(min(tasks.count, limit)) tasks for database: \(databaseName)")
        
        // Convert TaskCache objects to WidgetTask for serialization
        let widgetTasks = tasks.prefix(limit).map { taskCache in
            WidgetTask(
                id: taskCache.notionPageID,
                title: taskCache.title,
                isComplete: taskCache.taskStatus == .done,
                dueDate: taskCache.dueDate,
                priority: taskCache.priorityLevel,
                status: taskCache.taskStatus,
                lastUpdated: taskCache.lastEditedTime,
                isOverdue: taskCache.isOverdue,
                isDueToday: taskCache.isDueToday
            )
        }
        
        // Use InternalWidgetDataManager to handle the actual caching
        InternalWidgetDataManager.cacheTasksForDatabase(
            databaseId: databaseId, 
            databaseName: databaseName, 
            tasks: Array(widgetTasks)
        )
    }
    
    /// Cache tasks for all selected databases
    /// This is useful for batch updates when syncing multiple databases
    /// - Parameter context: Core Data managed object context
    static func cacheTasksForAllSelectedDatabases(context: NSManagedObjectContext) {
        let selectedDatabases = InternalWidgetDataManager.getSelectedDatabasesForWidget()
        
        print("[WidgetTaskCaching] 🔄 Updating cache for \(selectedDatabases.count) selected databases")
        
        for widgetDatabase in selectedDatabases {
            // Fetch tasks for this database from Core Data
            let fetchRequest: NSFetchRequest<TaskCache> = TaskCache.fetchRequest()
            
            // We need to match by database ID - this assumes the database relationship is set up
            // You may need to adjust this predicate based on your Core Data model
            fetchRequest.predicate = NSPredicate(format: "database.databaseID == %@", widgetDatabase.id)
            
            // Sort by priority and due date for optimal widget display
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "priority", ascending: false),
                NSSortDescriptor(key: "dueDate", ascending: true),
                NSSortDescriptor(key: "lastEditedTime", ascending: false)
            ]
            
            // Limit to top tasks to keep cache small
            fetchRequest.fetchLimit = 10
            
            do {
                let tasks = try context.fetch(fetchRequest)
                
                if !tasks.isEmpty {
                    cacheTasksForWidget(
                        databaseId: widgetDatabase.id,
                        databaseName: widgetDatabase.name,
                        tasks: tasks
                    )
                } else {
                    // Cache empty array to indicate database has no tasks
                    InternalWidgetDataManager.cacheTasksForDatabase(
                        databaseId: widgetDatabase.id,
                        databaseName: widgetDatabase.name,
                        tasks: []
                    )
                }
                
            } catch {
                print("[WidgetTaskCaching] ❌ Failed to fetch tasks for database \(widgetDatabase.name): \(error)")
            }
        }
    }
    
    /// Clear stale task caches
    /// This should be called periodically to clean up old cache data
    static func clearStaleTaskCaches(maxAge: TimeInterval = 86400) { // 24 hours default
        let selectedDatabases = InternalWidgetDataManager.getSelectedDatabasesForWidget()
        
        for database in selectedDatabases {
            if let tasks = InternalWidgetDataManager.getCachedTasks(for: database.id, maxAge: maxAge),
               tasks.isEmpty {
                // Cache exists but is stale, clear it
                InternalWidgetDataManager.clearCachedTasks(for: database.id)
                print("[WidgetTaskCaching] 🧹 Cleared stale cache for database: \(database.name)")
            }
        }
    }
    
    /// Update widget timeline after caching new data
    /// This tells iOS to refresh the widget with new data
    static func refreshWidgetTimeline() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        print("[WidgetTaskCaching] 🔄 Requested widget timeline refresh")
        #endif
    }
    
    /// Convenience method for updating a single database's tasks and refreshing widget
    /// - Parameters:
    ///   - databaseId: Notion database ID
    ///   - databaseName: Human-readable database name
    ///   - context: Core Data context to fetch from
    static func updateAndRefreshWidget(databaseId: String, databaseName: String, context: NSManagedObjectContext) {
        // Fetch latest tasks
        let fetchRequest: NSFetchRequest<TaskCache> = TaskCache.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "database.databaseID == %@", databaseId)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "priority", ascending: false),
            NSSortDescriptor(key: "dueDate", ascending: true)
        ]
        fetchRequest.fetchLimit = 10
        
        do {
            let tasks = try context.fetch(fetchRequest)
            cacheTasksForWidget(databaseId: databaseId, databaseName: databaseName, tasks: tasks)
            refreshWidgetTimeline()
        } catch {
            print("[WidgetTaskCaching] ❌ Failed to update widget cache: \(error)")
        }
    }
}

// MARK: - Integration Helpers

extension WidgetTaskCaching {
    
    /// Call this method after significant data changes in the main app
    /// For example: after sync completion, task status updates, etc.
    static func handleDataUpdate(context: NSManagedObjectContext) {
        cacheTasksForAllSelectedDatabases(context: context)
        refreshWidgetTimeline()
    }
    
    /// Call this when user changes database selection
    static func handleDatabaseSelectionChange(context: NSManagedObjectContext) {
        // Clear all existing caches since selection changed
        InternalWidgetDataManager.clearAllCachedTasks()
        
        // Cache tasks for newly selected databases
        cacheTasksForAllSelectedDatabases(context: context)
        refreshWidgetTimeline()
    }
    
    /// Debug method to print cache status
    static func printCacheStatus() {
        let cacheInfo = InternalWidgetDataManager.getCacheInfo()
        print("[WidgetTaskCaching] 📊 Cache Status:")
        for (databaseId, info) in cacheInfo {
            print("  - \(databaseId): \(info)")
        }
    }
}
