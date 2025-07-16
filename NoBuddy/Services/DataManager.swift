import Foundation
import CoreData
import Combine

/// Data manager for handling Core Data operations and local caching
@MainActor
class DataManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var error: DataError?
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "NoBuddyDataModel")
        
        // Configure for App Groups (for widget data sharing)
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.nobuddy.shared") {
            let storeURL = appGroupURL.appendingPathComponent("NoBuddy.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            container.persistentStoreDescriptions = [description]
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // In production, you would handle this error appropriately
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Background Context
    
    private lazy var backgroundContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }()
    
    // MARK: - Initialization
    
    func initialize() {
        setupCoreData()
        isInitialized = true
    }
    
    private func setupCoreData() {
        // Initialize persistent container
        _ = persistentContainer
        
        // Setup remote change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidChange),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }
    
    @objc private func contextDidChange(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext else { return }
        
        if context === backgroundContext {
            Task { @MainActor in
                viewContext.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
    
    // MARK: - Save Operations
    
    func saveContext() {
        let context = viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                self.error = DataError.saveFailed(error.localizedDescription)
            }
        }
    }
    
    func saveBackgroundContext() async {
        await backgroundContext.perform {
            if self.backgroundContext.hasChanges {
                do {
                    try self.backgroundContext.save()
                } catch {
                    Task { @MainActor in
                        self.error = DataError.saveFailed(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    // MARK: - Database Operations
    
    func cacheDatabase(_ database: NotionDatabase, token: NotionToken) async {
        await backgroundContext.perform {
            // Check if database already exists
            let request: NSFetchRequest<CachedDatabase> = CachedDatabase.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", database.id)
            
            do {
                let existing = try self.backgroundContext.fetch(request)
                let cachedDB = existing.first ?? CachedDatabase(context: self.backgroundContext)
                
                // Update database properties
                cachedDB.id = database.id
                cachedDB.title = database.title.first?.plainText ?? "Untitled"
                cachedDB.url = database.url
                cachedDB.lastEditedTime = database.lastEditedTime
                cachedDB.createdTime = database.createdTime
                cachedDB.isArchived = database.archived
                cachedDB.tokenId = token.id.uuidString
                cachedDB.lastCached = Date()
                
                // Cache properties as JSON
                if let propertiesData = try? JSONEncoder().encode(database.properties) {
                    cachedDB.propertiesData = propertiesData
                }
                
                try self.backgroundContext.save()
            } catch {
                Task { @MainActor in
                    self.error = DataError.cacheFailed(error.localizedDescription)
                }
            }
        }
    }
    
    func cachePage(_ page: NotionPage, token: NotionToken) async {
        await backgroundContext.perform {
            // Check if page already exists
            let request: NSFetchRequest<CachedPage> = CachedPage.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", page.id)
            
            do {
                let existing = try self.backgroundContext.fetch(request)
                let cachedPage = existing.first ?? CachedPage(context: self.backgroundContext)
                
                // Update page properties
                cachedPage.id = page.id
                cachedPage.url = page.url
                cachedPage.lastEditedTime = page.lastEditedTime
                cachedPage.createdTime = page.createdTime
                cachedPage.isArchived = page.archived
                cachedPage.tokenId = token.id.uuidString
                cachedPage.lastCached = Date()
                
                // Extract title from properties
                if let titleProperty = page.properties.values.first(where: { 
                    if case .title(let richTexts) = $0 {
                        return !richTexts.isEmpty
                    }
                    return false
                }) {
                    if case .title(let richTexts) = titleProperty {
                        cachedPage.title = richTexts.first?.plainText ?? "Untitled"
                    }
                }
                
                // Cache properties as JSON
                if let propertiesData = try? JSONEncoder().encode(page.properties) {
                    cachedPage.propertiesData = propertiesData
                }
                
                try self.backgroundContext.save()
            } catch {
                Task { @MainActor in
                    self.error = DataError.cacheFailed(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Fetch Operations
    
    func fetchCachedDatabases(for tokenId: UUID) -> [CachedDatabase] {
        let request: NSFetchRequest<CachedDatabase> = CachedDatabase.fetchRequest()
        request.predicate = NSPredicate(format: "tokenId == %@", tokenId.uuidString)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedDatabase.lastCached, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            self.error = DataError.fetchFailed(error.localizedDescription)
            return []
        }
    }
    
    func fetchCachedPages(for tokenId: UUID, databaseId: String? = nil) -> [CachedPage] {
        let request: NSFetchRequest<CachedPage> = CachedPage.fetchRequest()
        
        var predicates = [NSPredicate(format: "tokenId == %@", tokenId.uuidString)]
        
        if let databaseId = databaseId {
            predicates.append(NSPredicate(format: "parentDatabaseId == %@", databaseId))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedPage.lastCached, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            self.error = DataError.fetchFailed(error.localizedDescription)
            return []
        }
    }
    
    // MARK: - Widget Configuration
    
    func saveWidgetConfiguration(_ config: WidgetConfiguration) {
        let context = viewContext
        
        // Check if configuration already exists
        let request: NSFetchRequest<CachedWidgetConfiguration> = CachedWidgetConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "widgetId == %@", config.widgetId)
        
        do {
            let existing = try context.fetch(request)
            let cachedConfig = existing.first ?? CachedWidgetConfiguration(context: context)
            
            cachedConfig.widgetId = config.widgetId
            cachedConfig.tokenId = config.tokenId?.uuidString
            cachedConfig.databaseId = config.databaseId
            cachedConfig.widgetType = config.widgetType.rawValue
            cachedConfig.displayName = config.displayName
            cachedConfig.lastUpdated = Date()
            
            if let settingsData = try? JSONEncoder().encode(config.settings) {
                cachedConfig.settingsData = settingsData
            }
            
            saveContext()
        } catch {
            self.error = DataError.saveFailed(error.localizedDescription)
        }
    }
    
    func fetchWidgetConfigurations() -> [WidgetConfiguration] {
        let request: NSFetchRequest<CachedWidgetConfiguration> = CachedWidgetConfiguration.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedWidgetConfiguration.lastUpdated, ascending: false)]
        
        do {
            let cached = try viewContext.fetch(request)
            return cached.compactMap { $0.toWidgetConfiguration() }
        } catch {
            self.error = DataError.fetchFailed(error.localizedDescription)
            return []
        }
    }
    
    // MARK: - Cleanup Operations
    
    func cleanOldCachedData(olderThan date: Date) async {
        await backgroundContext.perform {
            // Clean old cached databases
            let dbRequest: NSFetchRequest<NSFetchRequestResult> = CachedDatabase.fetchRequest()
            dbRequest.predicate = NSPredicate(format: "lastCached < %@", date as NSDate)
            
            let dbDeleteRequest = NSBatchDeleteRequest(fetchRequest: dbRequest)
            
            // Clean old cached pages
            let pageRequest: NSFetchRequest<NSFetchRequestResult> = CachedPage.fetchRequest()
            pageRequest.predicate = NSPredicate(format: "lastCached < %@", date as NSDate)
            
            let pageDeleteRequest = NSBatchDeleteRequest(fetchRequest: pageRequest)
            
            do {
                try self.backgroundContext.execute(dbDeleteRequest)
                try self.backgroundContext.execute(pageDeleteRequest)
                try self.backgroundContext.save()
            } catch {
                Task { @MainActor in
                    self.error = DataError.cleanupFailed(error.localizedDescription)
                }
            }
        }
    }
    
    func clearAllCachedData() async {
        await backgroundContext.perform {
            do {
                // Clear all entities
                let entities = ["CachedDatabase", "CachedPage", "CachedBlock", "CachedWidgetConfiguration"]
                
                for entityName in entities {
                    let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                    try self.backgroundContext.execute(deleteRequest)
                }
                
                try self.backgroundContext.save()
            } catch {
                Task { @MainActor in
                    self.error = DataError.cleanupFailed(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Data Models

/// Widget configuration model
struct WidgetConfiguration: Codable {
    let widgetId: String
    let tokenId: UUID?
    let databaseId: String?
    let widgetType: WidgetType
    let displayName: String
    let settings: [String: String]
    
    enum WidgetType: String, Codable, CaseIterable {
        case small = "small"
        case medium = "medium"
        case large = "large"
        
        var displayName: String {
            switch self {
            case .small:
                return "Small"
            case .medium:
                return "Medium"
            case .large:
                return "Large"
            }
        }
    }
}

/// Data error types
enum DataError: Error, LocalizedError {
    case initializationFailed(String)
    case saveFailed(String)
    case fetchFailed(String)
    case cacheFailed(String)
    case cleanupFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Failed to initialize data store: \(message)"
        case .saveFailed(let message):
            return "Failed to save data: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch data: \(message)"
        case .cacheFailed(let message):
            return "Failed to cache data: \(message)"
        case .cleanupFailed(let message):
            return "Failed to cleanup data: \(message)"
        }
    }
}

// MARK: - Core Data Extensions

extension CachedWidgetConfiguration {
    func toWidgetConfiguration() -> WidgetConfiguration? {
        guard let widgetId = widgetId,
              let widgetTypeString = widgetType,
              let widgetType = WidgetConfiguration.WidgetType(rawValue: widgetTypeString),
              let displayName = displayName else {
            return nil
        }
        
        let tokenUUID = tokenId.flatMap { UUID(uuidString: $0) }
        
        var settings: [String: String] = [:]
        if let settingsData = settingsData {
            settings = (try? JSONDecoder().decode([String: String].self, from: settingsData)) ?? [:]
        }
        
        return WidgetConfiguration(
            widgetId: widgetId,
            tokenId: tokenUUID,
            databaseId: databaseId,
            widgetType: widgetType,
            displayName: displayName,
            settings: settings
        )
    }
}