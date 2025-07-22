import Foundation

// MARK: - Basic Models for Token Validation

/// Simplified NotionUser model for token validation
struct NotionUser: Identifiable, Codable {
    let object: String
    let id: String
    let name: String?
    let avatarUrl: String?
    let type: UserType?
    let email: String?
    
    enum UserType: String, Codable {
        case person = "person"
        case bot = "bot"
    }
    
    private enum CodingKeys: String, CodingKey {
        case object, id, name, type, email
        case avatarUrl = "avatar_url"
    }
}

// MARK: - Search Models (Minimal for API compatibility)

struct SearchResponse: Codable {
    let object: String
    let results: [SearchResult]
    let nextCursor: String?
    let hasMore: Bool
    
    private enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

struct SearchResult: Codable {
    let object: String
    let id: String
    
    // Only keeping minimal fields needed for counting
    init(object: String, id: String) {
        self.object = object
        self.id = id
    }
}

// MARK: - Database Models (Complete for API retrieval)

/// Complete Notion database model with all metadata fields
struct NotionDatabase: Identifiable, Codable {
    let object: String
    let id: String
    let createdTime: Date?
    let createdBy: DatabaseUser?
    let lastEditedTime: Date?
    let lastEditedBy: DatabaseUser?
    let title: [DatabaseRichText]?
    let description: [DatabaseRichText]?
    let icon: DatabaseIcon?
    let cover: DatabaseCover?
    let properties: [String: DatabaseProperty]?
    let parent: DatabaseParent?
    let url: String?
    let archived: Bool?
    let isInline: Bool?
    let publicUrl: String?
    let inTrash: Bool?
    
    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title.compactMap { $0.plainText }.joined()
        }
        return "Untitled Database"
    }
    
    var displayDescription: String? {
        if let description = description, !description.isEmpty {
            return description.compactMap { $0.plainText }.joined()
        }
        return nil
    }
    
    var safeLastEditedTime: Date {
        return lastEditedTime ?? Date()
    }
    
    var safeCreatedTime: Date {
        return createdTime ?? Date()
    }
    
    /// Get property types for easier access
    var propertyTypes: [String: String] {
        guard let properties = properties else { return [:] }
        return properties.compactMapValues { $0.type }
    }
    
    private enum CodingKeys: String, CodingKey {
        case object, id, title, description, icon, cover, properties, parent, url, archived
        case createdTime = "created_time"
        case createdBy = "created_by"
        case lastEditedTime = "last_edited_time"
        case lastEditedBy = "last_edited_by"
        case isInline = "is_inline"
        case publicUrl = "public_url"
        case inTrash = "in_trash"
    }
}

/// Database-specific rich text model
struct DatabaseRichText: Codable {
    let type: String
    let plainText: String
    let text: DatabaseTextContent?
    let annotations: DatabaseTextAnnotations?
    let href: String?
    
    private enum CodingKeys: String, CodingKey {
        case type, text, annotations, href
        case plainText = "plain_text"
    }
}

/// Text content for database rich text
struct DatabaseTextContent: Codable {
    let content: String
    let link: DatabaseTextLink?
}

/// Text link for database rich text
struct DatabaseTextLink: Codable {
    let url: String
}

/// Text annotations for database rich text
struct DatabaseTextAnnotations: Codable {
    let bold: Bool
    let italic: Bool
    let strikethrough: Bool
    let underline: Bool
    let code: Bool
    let color: String
}

/// Database icon model supporting emoji, external, and file types
struct DatabaseIcon: Codable {
    let type: String
    let emoji: String?
    let external: ExternalIconFile?
    let file: InternalIconFile?
    
    var displayIcon: String {
        switch type {
        case "emoji":
            return emoji ?? "📋"
        case "external", "file":
            return "🖼️"  // Generic icon for image-based icons
        default:
            return "📋"
        }
    }
    
    var iconUrl: String? {
        switch type {
        case "external":
            return external?.url
        case "file":
            return file?.url
        default:
            return nil
        }
    }
}

/// External icon file reference
struct ExternalIconFile: Codable {
    let url: String
}

/// Internal icon file reference
struct InternalIconFile: Codable {
    let url: String
    let expiryTime: Date?
    
    private enum CodingKeys: String, CodingKey {
        case url
        case expiryTime = "expiry_time"
    }
}

/// Database cover model
struct DatabaseCover: Codable {
    let type: String
    let external: ExternalCoverFile?
    let file: InternalCoverFile?
    
    var coverUrl: String? {
        switch type {
        case "external":
            return external?.url
        case "file":
            return file?.url
        default:
            return nil
        }
    }
}

/// External cover file reference
struct ExternalCoverFile: Codable {
    let url: String
}

/// Internal cover file reference
struct InternalCoverFile: Codable {
    let url: String
    let expiryTime: Date?
    
    private enum CodingKeys: String, CodingKey {
        case url
        case expiryTime = "expiry_time"
    }
}

/// Database parent (page or workspace)
struct DatabaseParent: Codable {
    let type: String
    let pageId: String?
    let workspace: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case type
        case pageId = "page_id"
        case workspace
    }
}

/// Database property definition with complete schema information
struct DatabaseProperty: Codable {
    let id: String
    let name: String?
    let type: String
    let description: String?
    
    // Type-specific configurations
    let title: PropertyConfiguration?
    let richText: PropertyConfiguration?
    let number: NumberPropertyConfiguration?
    let select: SelectPropertyConfiguration?
    let multiSelect: MultiSelectPropertyConfiguration?
    let date: PropertyConfiguration?
    let people: PropertyConfiguration?
    let files: PropertyConfiguration?
    let checkbox: PropertyConfiguration?
    let url: PropertyConfiguration?
    let email: PropertyConfiguration?
    let phoneNumber: PropertyConfiguration?
    let formula: FormulaPropertyConfiguration?
    let relation: RelationPropertyConfiguration?
    let rollup: RollupPropertyConfiguration?
    let createdTime: PropertyConfiguration?
    let createdBy: PropertyConfiguration?
    let lastEditedTime: PropertyConfiguration?
    let lastEditedBy: PropertyConfiguration?
    let status: StatusPropertyConfiguration?
    
    private enum CodingKeys: String, CodingKey {
        case id, name, type, description
        case title, richText = "rich_text", number, select
        case multiSelect = "multi_select", date, people, files
        case checkbox, url, email, phoneNumber = "phone_number"
        case formula, relation, rollup
        case createdTime = "created_time"
        case createdBy = "created_by"
        case lastEditedTime = "last_edited_time"
        case lastEditedBy = "last_edited_by"
        case status
    }
}

/// Basic property configuration (for simple types)
struct PropertyConfiguration: Codable {
    // Most properties don't have additional configuration
}

/// Number property configuration
struct NumberPropertyConfiguration: Codable {
    let format: String?
}

/// Select property configuration
struct SelectPropertyConfiguration: Codable {
    let options: [SelectOptionConfiguration]
}

/// Multi-select property configuration
struct MultiSelectPropertyConfiguration: Codable {
    let options: [SelectOptionConfiguration]
}

/// Select option configuration
struct SelectOptionConfiguration: Codable {
    let id: String?
    let name: String
    let color: String
    let description: String?
}

/// Formula property configuration
struct FormulaPropertyConfiguration: Codable {
    let expression: String
}

/// Relation property configuration
struct RelationPropertyConfiguration: Codable {
    let databaseId: String
    let type: String?
    let singleProperty: [String: String]?
    let dualProperty: DualProperty?
    
    private enum CodingKeys: String, CodingKey {
        case databaseId = "database_id"
        case type
        case singleProperty = "single_property"
        case dualProperty = "dual_property"
    }
}

/// Dual property configuration for relations
struct DualProperty: Codable {
    let synced_property_name: String
    let synced_property_id: String
}

/// Rollup property configuration
struct RollupPropertyConfiguration: Codable {
    let relationPropertyName: String
    let relationPropertyId: String
    let rollupPropertyName: String
    let rollupPropertyId: String
    let function: String
    
    private enum CodingKeys: String, CodingKey {
        case relationPropertyName = "relation_property_name"
        case relationPropertyId = "relation_property_id"
        case rollupPropertyName = "rollup_property_name"
        case rollupPropertyId = "rollup_property_id"
        case function
    }
}

/// Status property configuration
struct StatusPropertyConfiguration: Codable {
    let options: [StatusOptionConfiguration]
    let groups: [StatusGroupConfiguration]
}

/// Status option configuration
struct StatusOptionConfiguration: Codable {
    let id: String?
    let name: String
    let color: String
    let description: String?
}

/// Status group configuration
struct StatusGroupConfiguration: Codable {
    let id: String
    let name: String
    let color: String
    let optionIds: [String]
    
    private enum CodingKeys: String, CodingKey {
        case id, name, color
        case optionIds = "option_ids"
    }
}

/// Database-specific user model to avoid conflicts
struct DatabaseUser: Codable {
    let object: String
    let id: String
    let name: String?
    let avatarUrl: String?
    let type: String?
    let person: DatabasePersonDetails?
    let bot: DatabaseBotDetails?
    
    private enum CodingKeys: String, CodingKey {
        case object, id, name, type, person, bot
        case avatarUrl = "avatar_url"
    }
}

/// Person details for database user
struct DatabasePersonDetails: Codable {
    let email: String?
}

/// Bot details for database bot users
struct DatabaseBotDetails: Codable {
    let owner: DatabaseBotOwner?
    let workspaceName: String?
    
    private enum CodingKeys: String, CodingKey {
        case owner
        case workspaceName = "workspace_name"
    }
}

/// Bot owner information (simplified to break recursion)
struct DatabaseBotOwner: Codable {
    let type: String
    let userId: String?  // Just store the ID to break recursion
    let workspace: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case type, workspace
        case userId = "user"
    }
    
    // Custom decoding to handle the user object
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        workspace = try container.decodeIfPresent(Bool.self, forKey: .workspace)
        
        // Try to decode user as an object and extract just the ID
        if let userDict = try? container.decodeIfPresent([String: String].self, forKey: .userId) {
            userId = userDict["id"]
        } else {
            userId = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(workspace, forKey: .workspace)
        
        if let userId = userId {
            try container.encode(["id": userId], forKey: .userId)
        }
    }
}

// MARK: - Error Models

struct NotionAPIError: Codable, Error {
    let object: String
    let status: Int
    let code: String
    let message: String
    
    private enum CodingKeys: String, CodingKey {
        case object, status, code, message
    }
}
