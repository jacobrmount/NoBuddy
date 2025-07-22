import Foundation
import CoreData

// MARK: - Widget Task Models

/// Widget-friendly task structure (legacy - use WidgetTask from WidgetDataManager instead)
struct LegacyWidgetTask: Identifiable, Codable {
    let id: String
    let title: String
    let isCompleted: Bool
    let priority: WidgetTaskPriority
    let dueDate: Date?
    let isOverdue: Bool
    let isDueToday: Bool
}

enum WidgetTaskPriority: Int, Codable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    case urgent = 4
    
    var displayName: String {
        switch self {
        case .none: return "No Priority"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
}

enum WidgetTaskStatus: String, Codable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case blocked = "Blocked"
    case done = "Done"
    case archived = "Archived"
}

/// Task loader specifically designed for widget extensions
/// Handles Core Data access with widget-specific constraints and error handling
class WidgetTaskLoader {
    
    // MARK: - Properties
    
    static let shared = WidgetTaskLoader()
    
    private let appGroupIdentifier = "group.com.nobuddy.app"
    private let modelName = "NoBuddy"
    private let storeFileName = "NoBuddy.sqlite"
    
    // MARK: - Core Data Stack
    
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: modelName)
        
        // Configure for shared App Group container
        guard let storeURL = containerURL else {
            print("[WidgetTaskLoader] ❌ Failed to create shared container URL")
            fatalError("Unable to create shared container URL for App Group: \(appGroupIdentifier)")
        }
        
        print("[WidgetTaskLoader] 📁 Core Data store location: \(storeURL.path)")
        
        // Configure store description
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.shouldInferMappingModelAutomatically = true
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.type = NSSQLiteStoreType
        
        // Widget-specific options for read-only access
        storeDescription.setOption(true as NSNumber, forKey: NSReadOnlyPersistentStoreOption)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        container.persistentStoreDescriptions = [storeDescription]
        
        // Load persistent stores
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("[WidgetTaskLoader] ❌ Failed to load persistent stores: \(error)")
                // Widget extensions can't show alerts, so we'll handle this gracefully
            } else {
                print("[WidgetTaskLoader] ✅ Successfully loaded persistent store for widget")
            }
        }
        
        // Configure view context for widget use
        container.viewContext.automaticallyMergesChangesFromParent = false
        
        return container
    }()
    
    // MARK: - Computed Properties
    
    private var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private var containerURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(storeFileName)
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Load cached tasks for widget display
    func loadCachedTasks(limit: Int = 10) async throws -> [LegacyWidgetTask] {
        print("[WidgetTaskLoader] loadCachedTasks called with limit: \(limit)")
        
        // Check if store is accessible first
        guard isDataAvailable() else {
            print("[WidgetTaskLoader] Core Data store not accessible")
            throw WidgetError.storeNotAccessible
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    let tasks = try self.fetchTasksFromCache(limit: limit)
                    print("[WidgetTaskLoader] Successfully fetched \(tasks.count) tasks")
                    continuation.resume(returning: tasks)
                } catch {
                    print("[WidgetTaskLoader] Error fetching tasks: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Check if Core Data store exists and is accessible
    func isDataAvailable() -> Bool {
        guard let storeURL = containerURL else { 
            print("[WidgetTaskLoader] ❌ Cannot create container URL")
            return false 
        }
        
        let exists = FileManager.default.fileExists(atPath: storeURL.path)
        print("[WidgetTaskLoader] Core Data store exists: \(exists) at: \(storeURL.path)")
        
        // Check App Group container directory
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            print("[WidgetTaskLoader] ✅ App Group container accessible at: \(containerURL.path)")
            
            // List files in the container
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: containerURL.path)
                print("[WidgetTaskLoader] Files in App Group container: \(files)")
                
                // Check if any Core Data files exist
                let coreDataFiles = files.filter { $0.contains("NoBuddy") && ($0.contains(".sqlite") || $0.contains(".db")) }
                print("[WidgetTaskLoader] Core Data related files: \(coreDataFiles)")
            } catch {
                print("[WidgetTaskLoader] ❌ Error listing container contents: \(error)")
            }
        } else {
            print("[WidgetTaskLoader] ❌ Cannot access App Group container")
        }
        
        // Also test App Group access
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            sharedDefaults.set("widget-test", forKey: "test-key")
            let testValue = sharedDefaults.string(forKey: "test-key")
            print("[WidgetTaskLoader] App Group access test: \(testValue == "widget-test" ? "✅ SUCCESS" : "❌ FAILED")")
        } else {
            print("[WidgetTaskLoader] ❌ Cannot access App Group UserDefaults")
        }
        
        return exists
    }
    
    // MARK: - Private Methods
    
    private func fetchTasksFromCache(limit: Int) throws -> [LegacyWidgetTask] {
        print("[WidgetTaskLoader] fetchTasksFromCache called")
        
        // Create a generic fetch request since we can't access TaskCache directly in widget extension
        let request = NSFetchRequest<NSManagedObject>(entityName: "TaskCache")
        
        // Filter out completed tasks for widget display
        request.predicate = NSPredicate(format: "status != %@", "Done")
        
        // Sort by priority and due date for optimal widget display
        request.sortDescriptors = [
            NSSortDescriptor(key: "priority", ascending: false),
            NSSortDescriptor(key: "dueDate", ascending: true),
            NSSortDescriptor(key: "lastEditedTime", ascending: false)
        ]
        
        request.fetchLimit = limit * 2 // Fetch extra to account for filtering
        
        print("[WidgetTaskLoader] Executing fetch request")
        let taskObjects = try viewContext.fetch(request)
        print("[WidgetTaskLoader] Fetched \(taskObjects.count) raw task objects")
        
        // Convert NSManagedObjects to LegacyWidgetTasks
        print("[WidgetTaskLoader] Converting \(taskObjects.count) objects to LegacyWidgetTasks")
        let tasks: [LegacyWidgetTask] = taskObjects.compactMap { object in
            guard let title = object.value(forKey: "title") as? String,
                  let notionPageID = object.value(forKey: "notionPageID") as? String else {
                return nil
            }
            
            let status = object.value(forKey: "status") as? String ?? "Not Started"
            let priority = object.value(forKey: "priority") as? Int16 ?? 0
            let dueDate = object.value(forKey: "dueDate") as? Date
            
            let isCompleted = status == "Done"
            let isOverdue = checkIsOverdue(dueDate: dueDate, status: status)
            let isDueToday = checkIsDueToday(dueDate: dueDate)
            
            return LegacyWidgetTask(
                id: notionPageID,
                title: title,
                isCompleted: isCompleted,
                priority: WidgetTaskPriority(rawValue: Int(priority)) ?? .none,
                dueDate: dueDate,
                isOverdue: isOverdue,
                isDueToday: isDueToday
            )
        }
        
        // Sort by computed properties in memory for better widget display
        let sortedTasks = tasks.sorted { task1, task2 in
            // First priority: overdue tasks
            if task1.isOverdue != task2.isOverdue {
                return task1.isOverdue
            }
            // Second priority: due today
            if task1.isDueToday != task2.isDueToday {
                return task1.isDueToday
            }
            // Third priority: priority level
            if task1.priority.rawValue != task2.priority.rawValue {
                return task1.priority.rawValue > task2.priority.rawValue
            }
            // Fourth priority: due date
            if let date1 = task1.dueDate, let date2 = task2.dueDate {
                return date1 < date2
            }
            return false
        }
        
        // Take only the requested limit
        return Array(sortedTasks.prefix(limit))
    }
    
    private func checkIsOverdue(dueDate: Date?, status: String) -> Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date() && status != "Done"
    }
    
    private func checkIsDueToday(dueDate: Date?) -> Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }
}

// MARK: - Error Handling

extension WidgetTaskLoader {
    
    enum WidgetError: LocalizedError {
        case storeNotAccessible
        case noDataAvailable
        case loadFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .storeNotAccessible:
                return "Core Data store not accessible from widget"
            case .noDataAvailable:
                return "No task data available"
            case .loadFailed(let error):
                return "Failed to load tasks: \(error.localizedDescription)"
            }
        }
    }
}