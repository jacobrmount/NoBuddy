import Foundation
import CoreData
import Combine

/// Manages Core Data stack for NoBuddy with shared App Group container support
/// Provides thread-safe access to Core Data across main app and widget extension
@MainActor
class CoreDataManager: ObservableObject {
    
    // MARK: - Properties
    
    static let shared = CoreDataManager()
    
    @Published private(set) var isLoading = false
    @Published private(set) var error: CoreDataError?
    
    private let appGroupIdentifier = "group.com.nobuddy.app"
    private let modelName = "NoBuddy"
    private let storeFileName = "NoBuddy.sqlite"
    
    // Concurrent queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.nobuddy.coredata.queue", attributes: .concurrent)
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: modelName)
        
        // Configure for shared App Group container
        guard let storeURL = containerURL else {
            print("[CoreDataManager] ❌ Failed to create shared container URL")
            fatalError("Unable to create shared container URL for App Group: \(appGroupIdentifier)")
        }
        
        print("[CoreDataManager] 📁 Core Data store location: \(storeURL.path)")
        
        // Configure store description
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.shouldInferMappingModelAutomatically = true
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.type = NSSQLiteStoreType
        
        // Set options for better performance
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.persistentStoreDescriptions = [storeDescription]
        
        // Load persistent stores
        container.loadPersistentStores { [weak self] (storeDescription, error) in
            if let error = error as NSError? {
                print("[CoreDataManager] ❌ Failed to load persistent stores: \(error)")
                Task { @MainActor in
                    self?.error = .persistentStoreLoadFailed(error)
                }
                
                // In production, you might want to handle this more gracefully
                #if DEBUG
                fatalError("Unresolved error \(error), \(error.userInfo)")
                #endif
            } else {
                print("[CoreDataManager] ✅ Successfully loaded persistent store")
                print("[CoreDataManager] Store URL: \(storeDescription.url?.absoluteString ?? "Unknown")")
                print("[CoreDataManager] Store Type: \(storeDescription.type)")
            }
        }
        
        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Computed Properties
    
    /// Main view context for UI operations
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    /// Shared container URL for the App Group
    private var containerURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(storeFileName)
    }
    
    // MARK: - Initialization
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Create a new background context for batch operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// Perform batch operation in background context
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: CoreDataError.backgroundTaskFailed(error))
                }
            }
        }
    }
    
    /// Save changes in the specified context
    func save(context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            print("[CoreDataManager] ✅ Successfully saved context")
        } catch {
            print("[CoreDataManager] ❌ Failed to save context: \(error)")
            context.rollback()
            throw CoreDataError.saveFailed(error)
        }
    }
    
    /// Save view context changes
    func saveViewContext() async throws {
        guard viewContext.hasChanges else { return }
        
        try await MainActor.run {
            try save(context: viewContext)
        }
    }
    
    /// Reset Core Data stack (useful for testing or data corruption recovery)
    func resetCoreDataStack() async throws {
        print("[CoreDataManager] ⚠️ Resetting Core Data stack...")
        
        // Get store URL before destroying coordinator
        guard let storeURL = containerURL else {
            throw CoreDataError.storeNotFound
        }
        
        // Remove persistent store
        let coordinator = persistentContainer.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
        
        // Delete store files
        let fileManager = FileManager.default
        let storeFiles = [
            storeURL,
            storeURL.appendingPathExtension("shm"),
            storeURL.appendingPathExtension("wal")
        ]
        
        for file in storeFiles {
            if fileManager.fileExists(atPath: file.path) {
                try fileManager.removeItem(at: file)
            }
        }
        
        print("[CoreDataManager] ✅ Core Data stack reset complete")
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        // Listen for remote changes from widget or other app instances
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
    }
    
    @objc private func storeRemoteChange(_ notification: Notification) {
        print("[CoreDataManager] 📨 Received remote change notification")
        
        // Merge changes into view context
        Task { @MainActor in
            viewContext.performAndWait {
                viewContext.refreshAllObjects()
            }
        }
    }
    
    // MARK: - Migration Support
    
    /// Check if migration is needed
    func checkMigrationStatus() -> Bool {
        guard let storeURL = containerURL else { return false }
        
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                type: NSPersistentStore.StoreType(rawValue: NSSQLiteStoreType),
                at: storeURL
            )
            
            let model = persistentContainer.managedObjectModel
            return !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        } catch {
            print("[CoreDataManager] ⚠️ Could not check migration status: \(error)")
            return false
        }
    }
}

// MARK: - Error Types

enum CoreDataError: LocalizedError {
    case persistentStoreLoadFailed(Error)
    case saveFailed(Error)
    case backgroundTaskFailed(Error)
    case migrationFailed(Error)
    case storeNotFound
    case invalidContext
    
    var errorDescription: String? {
        switch self {
        case .persistentStoreLoadFailed(let error):
            return "Failed to load data store: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save changes: \(error.localizedDescription)"
        case .backgroundTaskFailed(let error):
            return "Background operation failed: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Data migration failed: \(error.localizedDescription)"
        case .storeNotFound:
            return "Data store not found"
        case .invalidContext:
            return "Invalid data context"
        }
    }
}

// MARK: - Core Data Helpers

extension NSManagedObject {
    /// Convenience method to check if object exists in context
    var exists: Bool {
        return !isDeleted && managedObjectContext != nil
    }
}
