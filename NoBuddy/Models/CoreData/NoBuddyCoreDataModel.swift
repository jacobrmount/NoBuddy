import Foundation
import CoreData

/// Core Data model definitions and extensions for NoBuddy
/// The actual model is defined in NoBuddy.xcdatamodeld

// MARK: - Managed Object Subclasses

@objc(CDToken)
public class CDToken: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var token: String
    @NSManaged public var workspaceName: String?
    @NSManaged public var workspaceIcon: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var lastValidated: Date?
    @NSManaged public var isValid: Bool
    @NSManaged public var databases: Set<CDDatabase>?
    @NSManaged public var selectedDatabases: Set<CDSelectedDatabase>?
}

@objc(CDDatabase)
public class CDDatabase: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var title: String
    @NSManaged public var icon: String?
    @NSManaged public var url: String?
    @NSManaged public var lastEditedTime: Date
    @NSManaged public var createdTime: Date
    @NSManaged public var cachedAt: Date
    @NSManaged public var token: CDToken
    @NSManaged public var selections: Set<CDSelectedDatabase>?
    @NSManaged public var tasks: Set<TaskCache>?
}

@objc(CDSelectedDatabase)
public class CDSelectedDatabase: NSManagedObject {
    @NSManaged public var databaseId: String
    @NSManaged public var selectedAt: Date
    @NSManaged public var isSelected: Bool
    @NSManaged public var database: CDDatabase?
    @NSManaged public var token: CDToken
}

// MARK: - Core Data Extensions

extension CDToken {
    /// Convert to NotionToken model
    func toNotionToken() -> NotionToken {
        var notionToken = NotionToken(
            name: name,
            token: token,
            workspaceName: workspaceName,
            workspaceIcon: workspaceIcon
        )
        notionToken.lastValidated = lastValidated
        notionToken.isValid = isValid
        return notionToken
    }
    
    /// Update from NotionToken model
    func update(from notionToken: NotionToken) {
        self.name = notionToken.name
        self.token = notionToken.token
        self.workspaceName = notionToken.workspaceName
        self.workspaceIcon = notionToken.workspaceIcon
        self.lastValidated = notionToken.lastValidated
        self.isValid = notionToken.isValid
    }
}

extension CDDatabase {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CDDatabase> {
        return NSFetchRequest<CDDatabase>(entityName: "CDDatabase")
    }
    
    /// Convert to DatabaseInfo model
    func toDatabaseInfo() -> DatabaseInfo {
        return DatabaseInfo(
            id: id,
            title: title,
            icon: icon,
            lastEditedTime: lastEditedTime,
            createdTime: createdTime,
            url: url,
            cachedAt: cachedAt
        )
    }
    
    /// Update from DatabaseInfo model
    func update(from databaseInfo: DatabaseInfo) {
        self.title = databaseInfo.title
        self.icon = databaseInfo.icon
        self.lastEditedTime = databaseInfo.lastEditedTime
        self.createdTime = databaseInfo.createdTime
        self.url = databaseInfo.url
        self.cachedAt = databaseInfo.cachedAt
    }
}
