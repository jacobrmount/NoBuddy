import Foundation
import CoreData
import Combine

/// Manages task caching operations for NoBuddy
@MainActor
class TaskCacheManager: ObservableObject {
    
    // MARK: - Properties
    
    static let shared = TaskCacheManager()
    
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: Error?
    
    private let coreDataManager = CoreDataManager.shared
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupAutoRefresh()
    }
    
    // MARK: - Public Methods
    
    /// Fetch cached tasks for a database
    func fetchTasks(for database: CDDatabase) async throws -> [TaskCache] {
        let context = coreDataManager.viewContext
        return try await context.perform {
            try TaskCache.fetchTasks(for: database, context: context)
        }
    }
    
    /// Fetch tasks with specific status
    func fetchTasks(withStatus status: TaskCache.TaskStatus) async throws -> [TaskCache] {
        let context = coreDataManager.viewContext
        return try await context.perform {
            try TaskCache.fetchTasks(withStatus: status, context: context)
        }
    }
    
    /// Fetch today's tasks
    func fetchTodaysTasks() async throws -> [TaskCache] {
        let context = coreDataManager.viewContext
        return try await context.perform {
            try TaskCache.fetchTodaysTasks(context: context)
        }
    }
    
    /// Fetch overdue tasks
    func fetchOverdueTasks() async throws -> [TaskCache] {
        let context = coreDataManager.viewContext
        return try await context.perform {
            try TaskCache.fetchOverdueTasks(context: context)
        }
    }
    
    /// Refresh tasks from Notion for a specific database
    func refreshTasks(for database: CDDatabase, using apiClient: NotionAPIClient) async throws {
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            // Query tasks from Notion
            let pages = try await apiClient.queryDatabase(
                databaseId: database.id,
                filter: nil,
                sorts: [
                    DatabaseSort(property: "Priority", timestamp: nil, direction: .descending),
                    DatabaseSort(property: "Due Date", timestamp: nil, direction: .ascending)
                ]
            )
            
            // Update cache in background context
            try await coreDataManager.performBackgroundTask { context in
                // Fetch the database in this context
                guard let bgDatabase = try context.existingObject(with: database.objectID) as? CDDatabase else {
                    throw TaskCacheError.databaseNotFound
                }
                
                // Fetch existing tasks for this database
                let existingTasks = try TaskCache.fetchTasks(for: bgDatabase, context: context)
                
                // Process each page
                for page in pages.results {
                    if let existingTask = existingTasks.first(where: { $0.notionPageID == page.id }) {
                        // Update existing task
                        existingTask.update(from: page, databaseID: database.id)
                    } else {
                        // Create new task
                        let newTask = TaskCache(context: context)
                        newTask.update(from: page, databaseID: database.id)
                        newTask.database = bgDatabase
                    }
                }
                
                // Remove tasks that no longer exist in Notion
                let fetchedIDs = Set(pages.results.map { $0.id })
                let tasksToDelete = existingTasks.filter { !fetchedIDs.contains($0.notionPageID) }
                tasksToDelete.forEach { context.delete($0) }
                
                // Save changes
                try self.coreDataManager.save(context: context)
            }
            
            // Update database cache timestamp
            database.cachedAt = Date()
            try await coreDataManager.saveViewContext()
            
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// Refresh all stale tasks
    func refreshStaleTasks(using apiClient: NotionAPIClient) async throws {
        let staleTasks = try await fetchStaleTasks()
        
        // Group tasks by database
        let tasksByDatabase = Dictionary(grouping: staleTasks) { $0.database }
        
        // Refresh each database's tasks
        for (database, _) in tasksByDatabase {
            guard let database = database else { continue }
            try await refreshTasks(for: database, using: apiClient)
        }
    }
    
    /// Mark task as needing sync
    func markTaskForSync(_ task: TaskCache) async throws {
        task.markForSync()
        try await coreDataManager.saveViewContext()
    }
    
    /// Update task status locally
    func updateTaskStatus(_ task: TaskCache, status: TaskCache.TaskStatus) async throws {
        task.taskStatus = status
        task.markForSync()
        try await coreDataManager.saveViewContext()
    }
    
    /// Update task priority locally
    func updateTaskPriority(_ task: TaskCache, priority: TaskCache.Priority) async throws {
        task.priorityLevel = priority
        task.markForSync()
        try await coreDataManager.saveViewContext()
    }
    
    /// Clear all cached tasks
    func clearAllTasks() async throws {
        try await coreDataManager.performBackgroundTask { context in
            let request: NSFetchRequest<NSFetchRequestResult> = TaskCache.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            let objectIDs = result?.result as? [NSManagedObjectID] ?? []
            
            // Merge changes to view context
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                into: [self.coreDataManager.viewContext]
            )
        }
    }
    
    /// Fetch tasks for widget display
    func fetchTasksForWidget(limit: Int = 5) async throws -> [WidgetTask] {
        let context = coreDataManager.viewContext
        return try await context.perform {
            let request: NSFetchRequest<TaskCache> = TaskCache.fetchRequest()
            request.predicate = NSPredicate(format: "status != %@", TaskCache.TaskStatus.done.rawValue)
            request.sortDescriptors = [
                NSSortDescriptor(key: "priority", ascending: false),
                NSSortDescriptor(key: "dueDate", ascending: true)
            ]
            request.fetchLimit = limit * 2 // Fetch more than needed to account for filtering
            
            let tasks = try context.fetch(request)
            // Sort by computed properties in memory
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
                if task1.priority != task2.priority {
                    return task1.priority > task2.priority
                }
                // Fourth priority: due date
                if let date1 = task1.dueDate, let date2 = task2.dueDate {
                    return date1 < date2
                }
                return false
            }
            
            // Take only the requested limit
            let limitedTasks = Array(sortedTasks.prefix(limit))
            return limitedTasks.map { taskCache in
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
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchStaleTasks() async throws -> [TaskCache] {
        let context = coreDataManager.viewContext
        return try await context.perform {
            try TaskCache.fetchStaleTasks(context: context)
        }
    }
    
    private func setupAutoRefresh() {
        // Set up a timer to check for stale tasks every minute
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.checkAndRefreshStaleTasks()
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkAndRefreshStaleTasks() async {
        do {
            let staleTasks = try await fetchStaleTasks()
            if !staleTasks.isEmpty {
                print("[TaskCacheManager] Found \(staleTasks.count) stale tasks")
                // Note: We would need access to the API client here
                // This would typically be handled by a higher-level coordinator
            }
        } catch {
            print("[TaskCacheManager] Error checking stale tasks: \(error)")
        }
    }
}


// MARK: - Error Types

enum TaskCacheError: LocalizedError {
    case databaseNotFound
    case taskNotFound
    case syncFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            return "Database not found in cache"
        case .taskNotFound:
            return "Task not found in cache"
        case .syncFailed(let error):
            return "Failed to sync tasks: \(error.localizedDescription)"
        }
    }
}
