import Foundation
import CoreData

// MARK: - Sync Configuration

/// Configuration for sync operations
struct SyncConfiguration {
    /// Maximum time data can be cached before considered stale (default: 5 minutes)
    var staleFreshnessThreshold: TimeInterval = 300
    
    /// Time to wait between retry attempts
    var retryInterval: TimeInterval = 2.0
    
    /// Maximum number of retry attempts
    var maxRetryAttempts: Int = 3
    
    /// Number of items to sync in a single batch
    var batchSize: Int = 100
    
    /// Whether to use incremental sync
    var enableIncrementalSync: Bool = true
    
    /// Network timeout for sync operations
    var syncTimeout: TimeInterval = 30.0
    
    /// Minimum interval between automatic syncs
    var minimumSyncInterval: TimeInterval = 60.0
}

// MARK: - Sync Strategy

/// Defines the synchronization strategy for a database
struct SyncStrategy {
    let databaseID: String
    let lastSyncTimestamp: Date?
    let incrementalSync: Bool
    let conflictResolution: ConflictResolutionPolicy
    let priority: SyncPriority
    let batchSize: Int
    
    init(
        databaseID: String,
        lastSyncTimestamp: Date? = nil,
        incrementalSync: Bool = true,
        conflictResolution: ConflictResolutionPolicy = .notionWins,
        priority: SyncPriority = .background,
        batchSize: Int = 100
    ) {
        self.databaseID = databaseID
        self.lastSyncTimestamp = lastSyncTimestamp
        self.incrementalSync = incrementalSync
        self.conflictResolution = conflictResolution
        self.priority = priority
        self.batchSize = batchSize
    }
}

// MARK: - Conflict Resolution

/// Policy for resolving conflicts between local and remote data
enum ConflictResolutionPolicy {
    /// Remote (Notion) data always wins
    case notionWins
    
    /// Local data always wins
    case localWins
    
    /// Merge based on last modified time
    case latestWins
    
    /// Custom merge strategy
    case merge(MergeStrategy)
}

/// Custom merge strategy for conflicts
struct MergeStrategy {
    let mergeFields: Set<String>
    let preferLocal: Set<String>
    let preferRemote: Set<String>
}

// MARK: - Sync Priority

/// Priority levels for sync operations
enum SyncPriority: Int, Comparable {
    case immediate = 3
    case high = 2
    case normal = 1
    case background = 0
    
    static func < (lhs: SyncPriority, rhs: SyncPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Sync Status

/// Status of a sync operation
enum SyncStatus: Equatable {
    case idle
    case syncing(progress: Double)
    case completed(at: Date)
    case failed(error: Error, retryCount: Int)
    case cancelled
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case let (.syncing(progress1), .syncing(progress2)):
            return progress1 == progress2
        case let (.completed(date1), .completed(date2)):
            return date1 == date2
        case let (.failed(_, retryCount1), .failed(_, retryCount2)):
            return retryCount1 == retryCount2
        case (.cancelled, .cancelled):
            return true
        default:
            return false
        }
    }
}

// MARK: - Sync Result

/// Result of a sync operation
struct SyncResult {
    let databaseID: String
    let startTime: Date
    let endTime: Date
    let itemsSynced: Int
    let itemsCreated: Int
    let itemsUpdated: Int
    let itemsDeleted: Int
    let conflicts: [SyncConflict]
    let errors: [SyncError]
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var isSuccess: Bool {
        errors.isEmpty
    }
}

/// Represents a sync conflict
struct SyncConflict {
    let itemID: String
    let localValue: Any
    let remoteValue: Any
    let resolution: ConflictResolution
    let timestamp: Date
}

/// How a conflict was resolved
enum ConflictResolution {
    case localWins
    case remoteWins
    case merged
    case deferred
}

/// Sync-specific error
struct SyncError: Error {
    let itemID: String?
    let operation: SyncOperation
    let underlyingError: Error
    let timestamp: Date
    
    enum SyncOperation {
        case fetch
        case create
        case update
        case delete
        case conflict
    }
}

// MARK: - Sync Manager Protocol

/// Main protocol for sync operations
protocol SyncManager: AnyObject {
    /// Current sync configuration
    var configuration: SyncConfiguration { get set }
    
    /// Sync a specific database
    func syncDatabase(_ databaseID: String, strategy: SyncStrategy) async throws -> SyncResult
    
    /// Sync all selected databases
    func syncAllDatabases() async throws -> [SyncResult]
    
    /// Check if data is stale for a database
    func isDataStale(for databaseID: String) -> Bool
    
    /// Get last sync timestamp for a database
    func lastSyncTimestamp(for databaseID: String) -> Date?
    
    /// Cancel ongoing sync operations
    func cancelSync(for databaseID: String?)
    
    /// Get current sync status
    func syncStatus(for databaseID: String) -> SyncStatus
    
    /// Resolve conflict between local and remote data
    func resolveConflict(_ local: TaskCache, _ remote: Page, policy: ConflictResolutionPolicy) -> TaskCache
}

// MARK: - Sync Coordinator Protocol

/// Coordinates sync operations across multiple databases
protocol SyncCoordinator: AnyObject {
    /// Schedule a sync operation
    func scheduleSync(for databaseID: String, priority: SyncPriority)
    
    /// Schedule sync for all databases
    func scheduleAllDatabaseSync(priority: SyncPriority)
    
    /// Start automatic sync based on staleness
    func startAutomaticSync()
    
    /// Stop automatic sync
    func stopAutomaticSync()
    
    /// Get sync queue status
    var pendingSyncCount: Int { get }
    
    /// Get active sync operations
    var activeSyncOperations: [String] { get }
}

// MARK: - Sync Metrics Protocol

/// Protocol for tracking sync performance metrics
protocol SyncMetricsTracker {
    /// Record sync result
    func recordSyncResult(_ result: SyncResult)
    
    /// Get average sync duration for a database
    func averageSyncDuration(for databaseID: String) -> TimeInterval?
    
    /// Get sync success rate
    func syncSuccessRate(for databaseID: String) -> Double?
    
    /// Get total items synced
    func totalItemsSynced(for databaseID: String) -> Int
    
    /// Clear metrics data
    func clearMetrics(for databaseID: String?)
}

// MARK: - Incremental Sync Protocol

/// Protocol for incremental sync support
protocol IncrementalSyncSupport {
    /// Get changes since last sync
    func getChangesSince(_ timestamp: Date, for databaseID: String) async throws -> [Page]
    
    /// Apply incremental changes
    func applyIncrementalChanges(_ changes: [Page], to database: CDDatabase, in context: NSManagedObjectContext) throws
    
    /// Mark items for deletion
    func markDeletedItems(existingIDs: Set<String>, fetchedIDs: Set<String>, in database: CDDatabase) throws
}

// MARK: - Offline Sync Protocol

/// Protocol for offline sync support
protocol OfflineSyncSupport {
    /// Queue changes for sync when online
    func queueOfflineChange(_ change: OfflineChange)
    
    /// Get pending offline changes
    func pendingOfflineChanges() -> [OfflineChange]
    
    /// Apply offline changes when online
    func syncOfflineChanges() async throws -> [OfflineChangeResult]
    
    /// Clear offline change queue
    func clearOfflineQueue()
}

/// Represents an offline change to be synced
struct OfflineChange {
    let id: UUID
    let itemID: String
    let databaseID: String
    let changeType: ChangeType
    let timestamp: Date
    let data: [String: Any]
    
    enum ChangeType: Codable {
        case create
        case update
        case delete
    }
}

/// Result of syncing an offline change
struct OfflineChangeResult {
    let change: OfflineChange
    let success: Bool
    let error: Error?
    let syncedAt: Date
}
