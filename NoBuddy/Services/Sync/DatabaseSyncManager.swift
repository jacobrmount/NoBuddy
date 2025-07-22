import Foundation
import CoreData
import Combine

// MARK: - Database Sync Manager

/// Main sync manager implementation handling all sync operations
@MainActor
final class DatabaseSyncManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DatabaseSyncManager()
    
    // MARK: - Published Properties
    
    @Published var syncStatuses = [String: SyncStatus]()
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0.0
    
    // MARK: - Properties
    
    private var _configuration = SyncConfiguration()
    var configuration: SyncConfiguration {
        get { _configuration }
        set { _configuration = newValue }
    }
    
    private let coreDataManager = CoreDataManager.shared
    private var apiClient: NotionAPIClient?
    private var syncMetrics = [String: [SyncResult]]()
    private var offlineChangeQueue = [OfflineChange]()
    private var syncTasks = [String: Task<SyncResult, Error>]()
    private nonisolated(unsafe) var lastSyncTimestamps = [String: Date]()
    private var cancellables = Set<AnyCancellable>()
    private let syncQueue = OperationQueue()
    private var automaticSyncTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        configureSyncQueue()
        loadLastSyncTimestamps()
    }
    
    private func configureSyncQueue() {
        syncQueue.name = "com.nobuddy.sync"
        syncQueue.maxConcurrentOperationCount = 2
        syncQueue.qualityOfService = .background
    }
    
    private func loadLastSyncTimestamps() {
        // Load from UserDefaults or Core Data
        if let data = UserDefaults.standard.data(forKey: "LastSyncTimestamps"),
           let timestamps = try? JSONDecoder().decode([String: Date].self, from: data) {
            lastSyncTimestamps = timestamps
        }
    }
    
    private func saveLastSyncTimestamps() {
        if let data = try? JSONEncoder().encode(lastSyncTimestamps) {
            UserDefaults.standard.set(data, forKey: "LastSyncTimestamps")
        }
    }
    
    // MARK: - API Client Setup
    
    func setAPIClient(_ client: NotionAPIClient) {
        self.apiClient = client
    }
    
    // MARK: - Sync Operations
    
    /// Sync a specific database with given strategy
    func syncDatabase(_ databaseID: String, strategy: SyncStrategy) async throws -> SyncResult {
        guard let apiClient = apiClient else {
            throw SyncError(itemID: nil, operation: .fetch, underlyingError: NSError(domain: "SyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "API client not configured"]), timestamp: Date())
        }
        
        let syncStrategy = strategy
        
        // Check if already syncing
        if case .syncing = syncStatuses[databaseID] {
            throw SyncError(itemID: nil, operation: .fetch, underlyingError: NSError(domain: "SyncManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Sync already in progress"]), timestamp: Date())
        }
        
        // Update status
        syncStatuses[databaseID] = .syncing(progress: 0.0)
        isSyncing = true
        
        // Create sync task
        let task = Task<SyncResult, Error> {
            do {
                let result = try await performSync(databaseID: databaseID, strategy: syncStrategy, apiClient: apiClient)
                
                // Update status on success
                await MainActor.run {
                    self.syncStatuses[databaseID] = .completed(at: Date())
                    self.lastSyncTimestamps[databaseID] = Date()
                    self.saveLastSyncTimestamps()
                    self.recordSyncResult(result)
                    self.updateSyncingStatus()
                }
                
                return result
            } catch {
                // Update status on failure
                await MainActor.run {
                    self.syncStatuses[databaseID] = .failed(error: error, retryCount: 0)
                    self.updateSyncingStatus()
                }
                throw error
            }
        }
        
        syncTasks[databaseID] = task
        return try await task.value
    }
    
    /// Perform the actual sync operation
    private func performSync(databaseID: String, strategy: SyncStrategy, apiClient: NotionAPIClient) async throws -> SyncResult {
        let startTime = Date()
        var itemsCreated = 0
        var itemsUpdated = 0
        var itemsDeleted = 0
        var conflicts = [SyncConflict]()
        var errors = [SyncError]()
        
        do {
            // Get the database from Core Data
            let context = coreDataManager.viewContext
            guard let database = try await context.perform({
                try self.fetchDatabase(with: databaseID, in: context)
            }) else {
                throw SyncError(itemID: nil, operation: .fetch, underlyingError: NSError(domain: "SyncManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Database not found"]), timestamp: Date())
            }
            
            // Determine sync approach
            let pages: [Page]
            if strategy.incrementalSync, let lastSync = strategy.lastSyncTimestamp {
                pages = try await fetchIncrementalChanges(databaseID: databaseID, since: lastSync, apiClient: apiClient)
            } else {
                pages = try await fetchAllPages(databaseID: databaseID, apiClient: apiClient)
            }
            
            // Update progress
            await MainActor.run {
                self.syncStatuses[databaseID] = .syncing(progress: 0.5)
            }
            
            // Apply changes in background context
            try await coreDataManager.performBackgroundTask { bgContext in
                // Get database in background context
                guard let bgDatabase = try bgContext.existingObject(with: database.objectID) as? CDDatabase else {
                    throw SyncError(itemID: nil, operation: .fetch, underlyingError: NSError(domain: "SyncManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "Database not found in background context"]), timestamp: Date())
                }
                
                // Fetch existing tasks
                let existingTasks = try TaskCache.fetchTasks(for: bgDatabase, context: bgContext)
                let existingTasksMap = Dictionary(uniqueKeysWithValues: existingTasks.map { ($0.notionPageID, $0) })
                let fetchedIDs = Set(pages.map { $0.id })
                
                // Process each page
                for (index, page) in pages.enumerated() {
                    autoreleasepool {
                        if let existingTask = existingTasksMap[page.id] {
                            // Check for conflicts and update
                            let hasConflict = self.detectConflict(local: existingTask, remote: page)
                            if hasConflict {
                                let resolution = self.resolveConflictInternal(existingTask, page, policy: strategy.conflictResolution)
                                conflicts.append(SyncConflict(
                                    itemID: page.id,
                                    localValue: existingTask,
                                    remoteValue: page,
                                    resolution: resolution,
                                    timestamp: Date()
                                ))
                            }
                            existingTask.update(from: page, databaseID: databaseID)
                            itemsUpdated += 1
                        } else {
                            // Create new task
                            let newTask = TaskCache(context: bgContext)
                            newTask.update(from: page, databaseID: databaseID)
                            newTask.database = bgDatabase
                            itemsCreated += 1
                        }
                    }
                    
                    // Update progress
                    let progress = 0.5 + (Double(index) / Double(pages.count)) * 0.4
                    Task { @MainActor in
                        self.syncStatuses[databaseID] = .syncing(progress: progress)
                    }
                }
                
                // Handle deletions (only in full sync mode)
                if !strategy.incrementalSync {
                    let existingIDs = Set(existingTasks.map { $0.notionPageID })
                    let deletedIDs = existingIDs.subtracting(fetchedIDs)
                    
                    for deletedID in deletedIDs {
                        if let taskToDelete = existingTasksMap[deletedID] {
                            bgContext.delete(taskToDelete)
                            itemsDeleted += 1
                        }
                    }
                }
                
                // Update database cache timestamp
                bgDatabase.cachedAt = Date()
                
                // Save changes
                try self.coreDataManager.save(context: bgContext)
            }
            
            // Final progress update
            await MainActor.run {
                self.syncStatuses[databaseID] = .syncing(progress: 1.0)
            }
            
            let endTime = Date()
            return SyncResult(
                databaseID: databaseID,
                startTime: startTime,
                endTime: endTime,
                itemsSynced: itemsCreated + itemsUpdated,
                itemsCreated: itemsCreated,
                itemsUpdated: itemsUpdated,
                itemsDeleted: itemsDeleted,
                conflicts: conflicts,
                errors: errors
            )
            
        } catch {
            errors.append(SyncError(
                itemID: nil,
                operation: .fetch,
                underlyingError: error,
                timestamp: Date()
            ))
            
            let endTime = Date()
            return SyncResult(
                databaseID: databaseID,
                startTime: startTime,
                endTime: endTime,
                itemsSynced: itemsCreated + itemsUpdated,
                itemsCreated: itemsCreated,
                itemsUpdated: itemsUpdated,
                itemsDeleted: itemsDeleted,
                conflicts: conflicts,
                errors: errors
            )
        }
    }
    
    // MARK: - Fetch Operations
    
    private func fetchDatabase(with id: String, in context: NSManagedObjectContext) throws -> CDDatabase? {
        let request = CDDatabase.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
    
    private func fetchAllPages(databaseID: String, apiClient: NotionAPIClient) async throws -> [Page] {
        var allPages = [Page]()
        var cursor: String? = nil
        var hasMore = true
        
        while hasMore {
            let response = try await apiClient.queryDatabase(
                databaseId: databaseID,
                sorts: [
                    DatabaseSort(property: nil, timestamp: .lastEditedTime, direction: .descending)
                ],
                startCursor: cursor,
                pageSize: configuration.batchSize
            )
            
            allPages.append(contentsOf: response.results)
            cursor = response.nextCursor
            hasMore = response.hasMore
        }
        
        return allPages
    }
    
    private func fetchIncrementalChanges(databaseID: String, since timestamp: Date, apiClient: NotionAPIClient) async throws -> [Page] {
        // Create filter for last edited time
        let isoFormatter = ISO8601DateFormatter()
        let timestampString = isoFormatter.string(from: timestamp)
        
        let filter = DatabaseFilter(
            property: "",
            condition: .and([
                DatabaseFilter(
                    property: "last_edited_time",
                    condition: .dateAfter(timestampString)
                )
            ])
        )
        
        var allPages = [Page]()
        var cursor: String? = nil
        var hasMore = true
        
        while hasMore {
            let response = try await apiClient.queryDatabase(
                databaseId: databaseID,
                filter: filter,
                sorts: [
                    DatabaseSort(property: nil, timestamp: .lastEditedTime, direction: .descending)
                ],
                startCursor: cursor,
                pageSize: configuration.batchSize
            )
            
            allPages.append(contentsOf: response.results)
            cursor = response.nextCursor
            hasMore = response.hasMore
        }
        
        return allPages
    }
    
    // MARK: - Conflict Detection & Resolution
    
    private func detectConflict(local: TaskCache, remote: Page) -> Bool {
        // If local has been modified after last sync, we have a potential conflict
        guard local.taskSyncStatus == .pending else {
            return false
        }
        
        // Compare last edited times
        return local.lastEditedTime > remote.lastEditedTime
    }
    
    private func resolveConflictInternal(_ local: TaskCache, _ remote: Page, policy: ConflictResolutionPolicy) -> ConflictResolution {
        switch policy {
        case .notionWins:
            // Remote data wins - update local with remote
            local.update(from: remote, databaseID: local.database?.id ?? "")
            return .remoteWins
            
        case .localWins:
            // Local data wins - mark for upload to Notion
            local.markForSync()
            return .localWins
            
        case .latestWins:
            // Compare timestamps
            if remote.lastEditedTime > local.lastEditedTime {
                local.update(from: remote, databaseID: local.database?.id ?? "")
                return .remoteWins
            } else {
                local.markForSync()
                return .localWins
            }
            
        case .merge(_):
            // Custom merge logic based on strategy
            // This is a simplified implementation
            local.update(from: remote, databaseID: local.database?.id ?? "")
            return .merged
        }
    }
    
    // MARK: - Sync All Databases
    
    func syncAllDatabases() async throws -> [SyncResult] {
        let context = coreDataManager.viewContext
        let databases = try await context.perform {
            let request = CDDatabase.fetchRequest()
            return try context.fetch(request)
        }
        
        var results = [SyncResult]()
        
        for database in databases {
            do {
                let result = try await syncDatabase(database.id, strategy: SyncStrategy(
                    databaseID: database.id,
                    lastSyncTimestamp: lastSyncTimestamps[database.id],
                    incrementalSync: configuration.enableIncrementalSync
                ))
                results.append(result)
            } catch {
                // Continue with other databases even if one fails
                let errorResult = SyncResult(
                    databaseID: database.id,
                    startTime: Date(),
                    endTime: Date(),
                    itemsSynced: 0,
                    itemsCreated: 0,
                    itemsUpdated: 0,
                    itemsDeleted: 0,
                    conflicts: [],
                    errors: [SyncError(itemID: nil, operation: .fetch, underlyingError: error, timestamp: Date())]
                )
                results.append(errorResult)
            }
        }
        
        return results
    }
    
    // MARK: - Staleness Check
    
    nonisolated func isDataStale(for databaseID: String) -> Bool {
        guard let lastSync = lastSyncTimestamps[databaseID] else {
            return true // Never synced
        }
        
        // Use a default threshold of 5 minutes (300 seconds)
        return Date().timeIntervalSince(lastSync) > 300
    }
    
    nonisolated func lastSyncTimestamp(for databaseID: String) -> Date? {
        return lastSyncTimestamps[databaseID]
    }
    
    // MARK: - Sync Control
    
    func cancelSync(for databaseID: String? = nil) {
        if let databaseID = databaseID {
            syncTasks[databaseID]?.cancel()
            syncTasks[databaseID] = nil
            syncStatuses[databaseID] = .cancelled
        } else {
            // Cancel all syncs
            for (_, task) in syncTasks {
                task.cancel()
            }
            syncTasks.removeAll()
            syncStatuses = syncStatuses.mapValues { _ in .cancelled }
        }
        updateSyncingStatus()
    }
    
    func syncStatus(for databaseID: String) -> SyncStatus {
        return syncStatuses[databaseID] ?? .idle
    }
    
    private func updateSyncingStatus() {
        isSyncing = syncStatuses.values.contains { status in
            if case .syncing = status {
                return true
            }
            return false
        }
    }
    
    // MARK: - Automatic Sync
    
    func startAutomaticSync() {
        stopAutomaticSync()
        
        automaticSyncTimer = Timer.scheduledTimer(withTimeInterval: configuration.minimumSyncInterval, repeats: true) { _ in
            Task {
                await self.performAutomaticSync()
            }
        }
    }
    
    func stopAutomaticSync() {
        automaticSyncTimer?.invalidate()
        automaticSyncTimer = nil
    }
    
    private func performAutomaticSync() async {
        let context = coreDataManager.viewContext
        
        do {
            let staleDatabases = try await context.perform {
                let request = CDDatabase.fetchRequest()
                let databases = try context.fetch(request)
                return databases.filter { self.isDataStale(for: $0.id) }
            }
            
            for database in staleDatabases {
                // Only sync if not already syncing
                if self.syncStatuses[database.id] == nil || self.syncStatuses[database.id] == SyncStatus.idle {
                    Task {
                        try? await self.syncDatabase(database.id, strategy: SyncStrategy(
                            databaseID: database.id,
                            lastSyncTimestamp: self.lastSyncTimestamps[database.id],
                            incrementalSync: true,
                            conflictResolution: .notionWins,
                            priority: .background
                        ))
                    }
                }
            }
        } catch {
            print("[SyncManager] Error in automatic sync: \(error)")
        }
    }
    
    // MARK: - Metrics
    
    private func recordSyncResult(_ result: SyncResult) {
        if syncMetrics[result.databaseID] == nil {
            syncMetrics[result.databaseID] = []
        }
        syncMetrics[result.databaseID]?.append(result)
        
        // Keep only last 100 results per database
        if let count = syncMetrics[result.databaseID]?.count, count > 100 {
            syncMetrics[result.databaseID] = Array(syncMetrics[result.databaseID]?.suffix(100) ?? [])
        }
    }
    
    func averageSyncDuration(for databaseID: String) -> TimeInterval? {
        guard let metrics = syncMetrics[databaseID], !metrics.isEmpty else {
            return nil
        }
        let totalDuration = metrics.map { $0.duration }.reduce(0, +)
        return totalDuration / Double(metrics.count)
    }
    
    func syncSuccessRate(for databaseID: String) -> Double? {
        guard let metrics = syncMetrics[databaseID], !metrics.isEmpty else {
            return nil
        }
        let successCount = metrics.filter { $0.isSuccess }.count
        return Double(successCount) / Double(metrics.count)
    }
    
    // MARK: - Offline Support
    
    func queueOfflineChange(_ change: OfflineChange) {
        offlineChangeQueue.append(change)
        saveOfflineQueue()
    }
    
    func syncOfflineChanges() async throws -> [OfflineChangeResult] {
        guard let apiClient = apiClient else {
            throw SyncError(itemID: nil, operation: .update, underlyingError: NSError(domain: "SyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "API client not configured"]), timestamp: Date())
        }
        
        var results = [OfflineChangeResult]()
        let changesToSync = offlineChangeQueue
        offlineChangeQueue.removeAll()
        
        for change in changesToSync {
            do {
                // Process each offline change
                switch change.changeType {
                case .create:
                    // Create new page in Notion
                    let properties = change.data["properties"] as? [String: PropertyValue] ?? [:]
                    _ = try await apiClient.createPage(
                        parent: .database(change.databaseID),
                        properties: properties
                    )
                    
                case .update:
                    // Update existing page
                    let properties = change.data["properties"] as? [String: PropertyValue] ?? [:]
                    _ = try await apiClient.updatePage(
                        pageId: change.itemID,
                        properties: properties
                    )
                    
                case .delete:
                    // Archive page in Notion
                    _ = try await apiClient.updatePage(
                        pageId: change.itemID,
                        archived: true
                    )
                }
                
                results.append(OfflineChangeResult(
                    change: change,
                    success: true,
                    error: nil,
                    syncedAt: Date()
                ))
                
            } catch {
                // Re-queue failed change
                offlineChangeQueue.append(change)
                results.append(OfflineChangeResult(
                    change: change,
                    success: false,
                    error: error,
                    syncedAt: Date()
                ))
            }
        }
        
        saveOfflineQueue()
        return results
    }
    
    private func saveOfflineQueue() {
        // Save to UserDefaults or Core Data for persistence
        if let data = try? JSONEncoder().encode(offlineChangeQueue) {
            UserDefaults.standard.set(data, forKey: "OfflineChangeQueue")
        }
    }
    
    private func loadOfflineQueue() {
        if let data = UserDefaults.standard.data(forKey: "OfflineChangeQueue"),
           let queue = try? JSONDecoder().decode([OfflineChange].self, from: data) {
            offlineChangeQueue = queue
        }
    }
}

// MARK: - SyncManager Protocol Conformance

extension DatabaseSyncManager: SyncManager {
    func resolveConflict(_ local: TaskCache, _ remote: Page, policy: ConflictResolutionPolicy) -> TaskCache {
        _ = resolveConflictInternal(local, remote, policy: policy)
        return local
    }
}

// MARK: - SyncCoordinator Protocol Conformance

extension DatabaseSyncManager: SyncCoordinator {
    func scheduleSync(for databaseID: String, priority: SyncPriority) {
        let strategy = SyncStrategy(
            databaseID: databaseID,
            lastSyncTimestamp: lastSyncTimestamps[databaseID],
            incrementalSync: configuration.enableIncrementalSync,
            conflictResolution: .notionWins,
            priority: priority
        )
        
        Task(priority: priority.taskPriority) {
            try? await syncDatabase(databaseID, strategy: strategy)
        }
    }
    
    func scheduleAllDatabaseSync(priority: SyncPriority) {
        Task(priority: priority.taskPriority) {
            _ = try? await syncAllDatabases()
        }
    }
    
    var pendingSyncCount: Int {
        syncTasks.count
    }
    
    var activeSyncOperations: [String] {
        Array(syncTasks.keys)
    }
}

// MARK: - Extensions

extension SyncStatus {
    var completedTime: Date? {
        if case .completed(let date) = self {
            return date
        }
        return nil
    }
}

extension SyncPriority {
    var taskPriority: TaskPriority {
        switch self {
        case .immediate:
            return .high
        case .high:
            return .medium
        case .normal:
            return .low
        case .background:
            return .background
        }
    }
}

// MARK: - Codable Conformance for Offline Support

extension OfflineChange: Codable {
    enum CodingKeys: String, CodingKey {
        case id, itemID, databaseID, changeType, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        itemID = try container.decode(String.self, forKey: .itemID)
        databaseID = try container.decode(String.self, forKey: .databaseID)
        changeType = try container.decode(ChangeType.self, forKey: .changeType)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        data = [:] // Data serialization would need custom implementation
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(itemID, forKey: .itemID)
        try container.encode(databaseID, forKey: .databaseID)
        try container.encode(changeType, forKey: .changeType)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

