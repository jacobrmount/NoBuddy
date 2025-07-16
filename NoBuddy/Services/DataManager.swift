import Foundation
import CoreData
import Combine

/// Manages Core Data stack and data synchronization for the app
@MainActor
class DataManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    /// Main context for UI operations
    lazy var viewContext: NSManagedObjectContext = {
        persistentContainer.viewContext
    }()
    
    /// Background context for data operations
    private lazy var backgroundContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }()
    
    // MARK: - Core Data Stack
    
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "NoBuddyDataModel")
        
        // Configure for app group sharing (for widgets)
        let appGroupIdentifier = "group.com.nobuddy.shared"
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            let storeURL = url.appendingPathComponent("NoBuddyDataModel.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            container.persistentStoreDescriptions = [description]
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // In production, you would want to handle this error appropriately
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        // Automatically merge changes from parent
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    // MARK: - Initialization
    
    init() {
        // Set up Core Data change notifications
        setupChangeNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Save the main view context
    func save() {
        guard viewContext.hasChanges else { return }
        
        do {
            try viewContext.save()
        } catch {
            self.errorMessage = "Failed to save data: \(error.localizedDescription)"
        }
    }
    
    /// Save a background context
    func saveBackground(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        
        context.perform {
            do {
                try context.save()
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to save background data: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Perform background operation
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let result = try block(self.backgroundContext)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Token Entity Management
    
    /// Create a TokenEntity from SafeNotionToken
    func createTokenEntity(from safeToken: SafeNotionToken) -> TokenEntity {
        let entity = TokenEntity(context: viewContext)
        entity.id = safeToken.id
        entity.name = safeToken.name
        entity.workspaceName = safeToken.workspaceName
        entity.workspaceIcon = safeToken.workspaceIcon
        entity.createdAt = safeToken.createdAt
        entity.lastValidated = safeToken.lastValidated
        entity.isValid = safeToken.isValid
        return entity
    }
    
    /// Update TokenEntity with SafeNotionToken data
    func updateTokenEntity(_ entity: TokenEntity, with safeToken: SafeNotionToken) {
        entity.name = safeToken.name
        entity.workspaceName = safeToken.workspaceName
        entity.workspaceIcon = safeToken.workspaceIcon
        entity.lastValidated = safeToken.lastValidated
        entity.isValid = safeToken.isValid
    }
    
    // MARK: - Database Caching
    
    /// Cache a Notion database
    func cacheDatabase(_ database: NotionDatabase, tokenId: UUID) async throws {
        try await performBackgroundTask { context in
            // Check if database already exists
            let fetchRequest: NSFetchRequest<CachedDatabase> = CachedDatabase.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", database.id)
            
            let existingDatabases = try context.fetch(fetchRequest)
            let cachedDatabase: CachedDatabase
            
            if let existing = existingDatabases.first {
                cachedDatabase = existing
            } else {
                cachedDatabase = CachedDatabase(context: context)
                cachedDatabase.id = database.id
            }
            
            // Update cached database properties
            self.updateCachedDatabase(cachedDatabase, with: database, tokenId: tokenId)
            
            try context.save()
        }
    }
    
    /// Cache a Notion page
    func cachePage(_ page: NotionPage, tokenId: UUID) async throws {
        try await performBackgroundTask { context in
            // Check if page already exists
            let fetchRequest: NSFetchRequest<CachedPage> = CachedPage.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", page.id)
            
            let existingPages = try context.fetch(fetchRequest)
            let cachedPage: CachedPage
            
            if let existing = existingPages.first {
                cachedPage = existing
            } else {
                cachedPage = CachedPage(context: context)
                cachedPage.id = page.id
            }
            
            // Update cached page properties
            self.updateCachedPage(cachedPage, with: page, tokenId: tokenId)
            
            try context.save()
        }
    }
    
    /// Get cached databases for a token
    func getCachedDatabases(for tokenId: UUID) -> [CachedDatabase] {
        let fetchRequest: NSFetchRequest<CachedDatabase> = CachedDatabase.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tokenId == %@", tokenId as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CachedDatabase.lastEditedTime, ascending: false)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            self.errorMessage = "Failed to fetch cached databases: \(error.localizedDescription)"
            return []
        }
    }
    
    /// Get cached pages for a database
    func getCachedPages(for databaseId: String, tokenId: UUID) -> [CachedPage] {
        let fetchRequest: NSFetchRequest<CachedPage> = CachedPage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "parentDatabaseId == %@ AND tokenId == %@", databaseId, tokenId as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CachedPage.lastEditedTime, ascending: false)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            self.errorMessage = "Failed to fetch cached pages: \(error.localizedDescription)"
            return []
        }
    }
    
    // MARK: - Widget Configuration
    
    /// Save widget configuration
    func saveWidgetConfiguration(_ config: WidgetConfigurationData) async throws {
        try await performBackgroundTask { context in
            let widgetConfig = WidgetConfiguration(context: context)
            widgetConfig.id = config.id
            widgetConfig.widgetType = config.widgetType
            widgetConfig.tokenId = config.tokenId
            widgetConfig.databaseId = config.databaseId
            widgetConfig.displayName = config.displayName
            widgetConfig.configurationData = config.configurationData
            widgetConfig.createdAt = Date()
            widgetConfig.updatedAt = Date()
            
            try context.save()
        }
    }
    
    /// Get widget configurations
    func getWidgetConfigurations() -> [WidgetConfiguration] {
        let fetchRequest: NSFetchRequest<WidgetConfiguration> = WidgetConfiguration.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \WidgetConfiguration.updatedAt, ascending: false)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            self.errorMessage = "Failed to fetch widget configurations: \(error.localizedDescription)"
            return []
        }
    }
    
    // MARK: - Data Cleanup
    
    /// Clean up expired cache entries
    func cleanupExpiredCache() async {
        let expirationDate = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago
        
        try? await performBackgroundTask { context in
            // Clean up databases
            let databaseFetch: NSFetchRequest<NSFetchRequestResult> = CachedDatabase.fetchRequest()
            databaseFetch.predicate = NSPredicate(format: "cachedAt < %@", expirationDate as NSDate)
            let databaseDelete = NSBatchDeleteRequest(fetchRequest: databaseFetch)
            try context.execute(databaseDelete)
            
            // Clean up pages
            let pageFetch: NSFetchRequest<NSFetchRequestResult> = CachedPage.fetchRequest()
            pageFetch.predicate = NSPredicate(format: "cachedAt < %@", expirationDate as NSDate)
            let pageDelete = NSBatchDeleteRequest(fetchRequest: pageFetch)
            try context.execute(pageDelete)
            
            try context.save()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupChangeNotifications() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator,
            queue: .main
        ) { _ in
            // Handle remote changes (for widget data sharing)
            self.viewContext.refresh(self.viewContext.registeredObjects.first { _ in true } ?? NSManagedObject(), mergeChanges: true)
        }
    }
    
    private func updateCachedDatabase(_ cached: CachedDatabase, with database: NotionDatabase, tokenId: UUID) {
        cached.tokenId = tokenId
        cached.title = database.title.first?.plainText ?? ""
        cached.url = database.url
        cached.archived = database.archived
        cached.createdTime = database.createdTime
        cached.lastEditedTime = database.lastEditedTime
        cached.cachedAt = Date()
        
        // Store icon and cover as JSON
        if let icon = database.icon {
            cached.iconData = try? JSONEncoder().encode(icon)
        }
        if let cover = database.cover {
            cached.coverData = try? JSONEncoder().encode(cover)
        }
    }
    
    private func updateCachedPage(_ cached: CachedPage, with page: NotionPage, tokenId: UUID) {
        cached.tokenId = tokenId
        cached.url = page.url
        cached.archived = page.archived
        cached.createdTime = page.createdTime
        cached.lastEditedTime = page.lastEditedTime
        cached.cachedAt = Date()
        
        // Extract parent database ID if it's a database page
        if case .database = page.parent.type {
            cached.parentDatabaseId = page.parent.databaseId
        }
        
        // Store properties as JSON
        cached.propertiesData = try? JSONEncoder().encode(page.properties)
        
        // Store icon and cover as JSON
        if let icon = page.icon {
            cached.iconData = try? JSONEncoder().encode(icon)
        }
        if let cover = page.cover {
            cached.coverData = try? JSONEncoder().encode(cover)
        }
    }
}

// MARK: - Widget Configuration Data

struct WidgetConfigurationData {
    let id: UUID
    let widgetType: String
    let tokenId: UUID
    let databaseId: String?
    let displayName: String
    let configurationData: Data?
}