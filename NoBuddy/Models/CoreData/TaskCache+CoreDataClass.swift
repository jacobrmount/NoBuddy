import Foundation
import CoreData

@objc(TaskCache)
public class TaskCache: NSManagedObject {
    
}

// MARK: - Core Data Properties
extension TaskCache {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TaskCache> {
        return NSFetchRequest<TaskCache>(entityName: "TaskCache")
    }
    
    // MARK: - Notion Properties
    @NSManaged public var notionPageID: String
    @NSManaged public var title: String
    @NSManaged public var status: String?
    @NSManaged public var priority: Int16
    @NSManaged public var dueDate: Date?
    @NSManaged public var assignee: String?
    @NSManaged public var assigneeID: String?
    
    // MARK: - Notion Metadata
    @NSManaged public var createdTime: Date
    @NSManaged public var lastEditedTime: Date
    @NSManaged public var createdBy: String?
    @NSManaged public var lastEditedBy: String?
    @NSManaged public var url: String?
    
    // MARK: - Cache Metadata
    @NSManaged public var lastFetched: Date
    @NSManaged public var isStale: Bool
    @NSManaged public var syncStatus: String
    
    // MARK: - Relationships
    @NSManaged public var database: CDDatabase?
}

// MARK: - Computed Properties
extension TaskCache {
    
    /// Check if cache is stale based on time elapsed since last fetch
    var isCacheStale: Bool {
        Date().timeIntervalSince(lastFetched) > 300 // 5 minutes
    }
    
    /// Priority as an enum for easier handling
    var priorityLevel: Priority {
        get {
            return Priority(rawValue: Int(priority)) ?? .none
        }
        set {
            priority = Int16(newValue.rawValue)
        }
    }
    
    /// Status as an enum for easier handling
    var taskStatus: TaskStatus {
        get {
            return TaskStatus(rawValue: status ?? "") ?? .notStarted
        }
        set {
            status = newValue.rawValue
        }
    }
    
    /// Sync status as an enum
    var taskSyncStatus: SyncStatus {
        get {
            return SyncStatus(rawValue: syncStatus) ?? .synced
        }
        set {
            syncStatus = newValue.rawValue
        }
    }
    
    /// Check if task is overdue
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date() && taskStatus != .done
    }
    
    /// Check if task is due today
    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }
    
    /// Check if task is due this week
    var isDueThisWeek: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDate(dueDate, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

// MARK: - Enums
extension TaskCache {
    
    enum Priority: Int, Codable {
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
        
        var emoji: String {
            switch self {
            case .none: return "⚪️"
            case .low: return "🟢"
            case .medium: return "🟡"
            case .high: return "🟠"
            case .urgent: return "🔴"
            }
        }
    }
    
    enum TaskStatus: String, Codable {
        case notStarted = "Not Started"
        case inProgress = "In Progress"
        case blocked = "Blocked"
        case done = "Done"
        case archived = "Archived"
        
        var emoji: String {
            switch self {
            case .notStarted: return "⭕️"
            case .inProgress: return "🔄"
            case .blocked: return "🚫"
            case .done: return "✅"
            case .archived: return "📦"
            }
        }
    }
    
    enum SyncStatus: String, Codable {
        case synced = "synced"
        case pending = "pending"
        case syncing = "syncing"
        case failed = "failed"
        case conflict = "conflict"
    }
}

// MARK: - Update Methods
extension TaskCache {
    
    /// Update from Notion Page model
    func update(from page: Page, databaseID: String) {
        self.notionPageID = page.id
        self.createdTime = page.createdTime
        self.lastEditedTime = page.lastEditedTime
        self.url = page.url
        self.lastFetched = Date()
        self.isStale = false
        self.taskSyncStatus = .synced
        
        // Extract properties from page.properties
        if case .title(let titleElements) = page.properties["Name"] {
            self.title = titleElements.map { $0.plainText }.joined()
        }
        
        if case .select(let statusOption) = page.properties["Status"] {
            self.status = statusOption?.name
        }
        
        if case .select(let priorityOption) = page.properties["Priority"] {
            switch priorityOption?.name {
            case "Low": self.priority = 1
            case "Medium": self.priority = 2
            case "High": self.priority = 3
            case "Urgent": self.priority = 4
            default: self.priority = 0
            }
        }
        
        if case .date(let dateValue) = page.properties["Due Date"] {
            if let dateString = dateValue?.start {
                // Parse ISO 8601 date string
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) {
                    self.dueDate = date
                } else {
                    // Try without fractional seconds
                    formatter.formatOptions = [.withInternetDateTime]
                    self.dueDate = formatter.date(from: dateString)
                }
            }
        }
        
        if case .people(let people) = page.properties["Assignee"], let firstPerson = people.first {
            self.assigneeID = firstPerson.id
            // Note: We'd need to fetch the actual user name separately
            // For now, we'll store the ID
        }
    }
    
    /// Mark as needing sync
    func markForSync() {
        self.taskSyncStatus = .pending
    }
    
    /// Update cache timestamp
    func refreshCache() {
        self.lastFetched = Date()
        self.isStale = false
    }
}

// MARK: - Fetch Helpers
extension TaskCache {
    
    /// Fetch all tasks for a specific database
    static func fetchTasks(for database: CDDatabase, context: NSManagedObjectContext) throws -> [TaskCache] {
        let request: NSFetchRequest<TaskCache> = TaskCache.fetchRequest()
        request.predicate = NSPredicate(format: "database == %@", database)
        request.sortDescriptors = [
            NSSortDescriptor(key: "priority", ascending: false),
            NSSortDescriptor(key: "dueDate", ascending: true)
        ]
        return try context.fetch(request)
    }
    
    /// Fetch tasks that need refresh
    static func fetchStaleTasks(context: NSManagedObjectContext) throws -> [TaskCache] {
        let request: NSFetchRequest<TaskCache> = TaskCache.fetchRequest()
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        request.predicate = NSPredicate(format: "lastFetched < %@ OR isStale == YES", fiveMinutesAgo as NSDate)
        return try context.fetch(request)
    }
    
    /// Fetch tasks by status
    static func fetchTasks(withStatus status: TaskStatus, context: NSManagedObjectContext) throws -> [TaskCache] {
        let request: NSFetchRequest<TaskCache> = TaskCache.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", status.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(key: "priority", ascending: false),
            NSSortDescriptor(key: "dueDate", ascending: true)
        ]
        return try context.fetch(request)
    }
    
    /// Fetch overdue tasks
    static func fetchOverdueTasks(context: NSManagedObjectContext) throws -> [TaskCache] {
        let request: NSFetchRequest<TaskCache> = TaskCache.fetchRequest()
        request.predicate = NSPredicate(format: "dueDate < %@ AND status != %@", 
                                      Date() as NSDate, 
                                      TaskStatus.done.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(key: "dueDate", ascending: true),
            NSSortDescriptor(key: "priority", ascending: false)
        ]
        return try context.fetch(request)
    }
    
    /// Fetch today's tasks
    static func fetchTodaysTasks(context: NSManagedObjectContext) throws -> [TaskCache] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<TaskCache> = TaskCache.fetchRequest()
        request.predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@", 
                                      startOfDay as NSDate, 
                                      endOfDay as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(key: "priority", ascending: false),
            NSSortDescriptor(key: "title", ascending: true)
        ]
        return try context.fetch(request)
    }
}

// MARK: - Widget Support
extension TaskCache {
    
    /// Convert to a widget-friendly data structure  
    /// Note: This method is now handled by WidgetTaskCaching.swift
    /// Use WidgetTaskCaching.cacheTasksForWidget() instead of calling this directly
    @available(*, deprecated, message: "Use WidgetTaskCaching.cacheTasksForWidget() instead")
    func toWidgetTask() -> [String: Any] {
        return [
            "id": notionPageID,
            "title": title,
            "isComplete": taskStatus == .done,
            "dueDate": dueDate as Any,
            "priority": priorityLevel.rawValue,
            "status": taskStatus.rawValue,
            "lastUpdated": lastEditedTime,
            "isOverdue": isOverdue,
            "isDueToday": isDueToday
        ]
    }
}
