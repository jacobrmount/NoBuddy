import Foundation

// MARK: - Base Notion Objects

/// Base protocol for all Notion objects
protocol NotionObject: Codable, Identifiable {
    var id: String { get }
    var object: String { get }
    var createdTime: Date { get }
    var lastEditedTime: Date { get }
}

/// Notion User object
struct NotionUser: NotionObject {
    let id: String
    let object: String
    let type: UserType
    let name: String?
    let avatarUrl: String?
    let createdTime: Date
    let lastEditedTime: Date
    
    enum UserType: String, Codable {
        case person
        case bot
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, object, type, name
        case avatarUrl = "avatar_url"
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
    }
}

/// Notion Parent object
struct NotionParent: Codable {
    let type: ParentType
    let pageId: String?
    let databaseId: String?
    let workspaceId: String?
    
    enum ParentType: String, Codable {
        case database_id
        case page_id
        case workspace
        case block_id
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case pageId = "page_id"
        case databaseId = "database_id"
        case workspaceId = "workspace_id"
    }
}

// MARK: - Database Models

/// Notion Database object
struct NotionDatabase: NotionObject {
    let id: String
    let object: String
    let createdTime: Date
    let lastEditedTime: Date
    let createdBy: NotionUser
    let lastEditedBy: NotionUser
    let cover: NotionFile?
    let icon: NotionIcon?
    let parent: NotionParent
    let archived: Bool
    let properties: [String: DatabaseProperty]
    let title: [RichText]
    let description: [RichText]
    let isInline: Bool
    let publicUrl: String?
    let url: String
    
    private enum CodingKeys: String, CodingKey {
        case id, object, cover, icon, parent, archived, properties, title, description, url
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case createdBy = "created_by"
        case lastEditedBy = "last_edited_by"
        case isInline = "is_inline"
        case publicUrl = "public_url"
    }
}

/// Database Property types
enum DatabaseProperty: Codable {
    case title(TitleProperty)
    case richText(RichTextProperty)
    case number(NumberProperty)
    case select(SelectProperty)
    case multiSelect(MultiSelectProperty)
    case date(DateProperty)
    case people(PeopleProperty)
    case files(FilesProperty)
    case checkbox(CheckboxProperty)
    case url(URLProperty)
    case email(EmailProperty)
    case phoneNumber(PhoneNumberProperty)
    case formula(FormulaProperty)
    case relation(RelationProperty)
    case rollup(RollupProperty)
    case createdTime(CreatedTimeProperty)
    case createdBy(CreatedByProperty)
    case lastEditedTime(LastEditedTimeProperty)
    case lastEditedBy(LastEditedByProperty)
    
    struct TitleProperty: Codable {
        let id: String
        let name: String
        let type: String
    }
    
    struct RichTextProperty: Codable {
        let id: String
        let name: String
        let type: String
    }
    
    struct NumberProperty: Codable {
        let id: String
        let name: String
        let type: String
        let format: String?
    }
    
    struct SelectProperty: Codable {
        let id: String
        let name: String
        let type: String
        let options: [SelectOption]
    }
    
    struct MultiSelectProperty: Codable {
        let id: String
        let name: String
        let type: String
        let options: [SelectOption]
    }
    
    struct DateProperty: Codable {
        let id: String
        let name: String
        let type: String
    }
    
    struct PeopleProperty: Codable {
        let id: String
        let name: String
        let type: String
    }
    
    struct FilesProperty: Codable {
        let id: String
        let name: String
        let type: String
    }
    
    struct CheckboxProperty: Codable {
        let id: String
        let name: String
        let type: String
    }
    
    struct URLProperty: Codable {
        let id: String
        let name: String
        let type: String
    }
    
    struct EmailProperty: Codable {
        let id: String
        let name: String
        let type: String
    }
    
    struct PhoneNumberProperty: Codable {
        let id: String
        let name: String
        let type: String
    }
    
    struct FormulaProperty: Codable {
        let id: String
        let name: String
        let type: String
        let expression: String
    }
    
    struct RelationProperty: Codable {
        let id: String
        let name: String
        let type: String
        let databaseId: String
        
        private enum CodingKeys: String, CodingKey {
            case id, name, type
            case databaseId = "database_id"
        }
    }
    
    struct RollupProperty: Codable {
        let id: String
        let name: String
        let type: String
        let relationPropertyName: String
        let relationPropertyId: String
        let rollupPropertyName: String
        let rollupPropertyId: String
        let function: String
        
        private enum CodingKeys: String, CodingKey {
            case id, name, type, function
            case relationPropertyName = "relation_property_name"
            case relationPropertyId = "relation_property_id"
            case rollupPropertyName = "rollup_property_name"
            case rollupPropertyId = "rollup_property_id"
        }
    }
    
    struct CreatedTimeProperty: Codable {
        let id: String
        let name: String
        let type: String
    }
    
    struct CreatedByProperty: Codable {
        let id: String
        let name: String
        let type: String
    }
    
    struct LastEditedTimeProperty: Codable {
        let id: String
        let name: String
        let type: String
    }
    
    struct LastEditedByProperty: Codable {
        let id: String
        let name: String
        let type: String
    }
}

/// Select option for select and multi-select properties
struct SelectOption: Codable {
    let id: String?
    let name: String
    let color: String
}

// MARK: - Page Models

/// Notion Page object
struct NotionPage: NotionObject {
    let id: String
    let object: String
    let createdTime: Date
    let lastEditedTime: Date
    let createdBy: NotionUser
    let lastEditedBy: NotionUser
    let cover: NotionFile?
    let icon: NotionIcon?
    let parent: NotionParent
    let archived: Bool
    let properties: [String: PageProperty]
    let url: String
    let publicUrl: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, object, cover, icon, parent, archived, properties, url
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case createdBy = "created_by"
        case lastEditedBy = "last_edited_by"
        case publicUrl = "public_url"
    }
}

/// Page Property values
enum PageProperty: Codable {
    case title([RichText])
    case richText([RichText])
    case number(Double?)
    case select(SelectOption?)
    case multiSelect([SelectOption])
    case date(DateValue?)
    case people([NotionUser])
    case files([NotionFile])
    case checkbox(Bool)
    case url(String?)
    case email(String?)
    case phoneNumber(String?)
    case formula(FormulaResult)
    case relation([Relation])
    case rollup(RollupResult)
    case createdTime(Date)
    case createdBy(NotionUser)
    case lastEditedTime(Date)
    case lastEditedBy(NotionUser)
}

/// Date value structure
struct DateValue: Codable {
    let start: String
    let end: String?
    let timeZone: String?
    
    private enum CodingKeys: String, CodingKey {
        case start, end
        case timeZone = "time_zone"
    }
}

/// Formula result
enum FormulaResult: Codable {
    case string(String?)
    case number(Double?)
    case boolean(Bool?)
    case date(DateValue?)
}

/// Relation object
struct Relation: Codable {
    let id: String
}

/// Rollup result
enum RollupResult: Codable {
    case number(Double?)
    case date(DateValue?)
    case array([RollupArrayItem])
    case unsupported
}

enum RollupArrayItem: Codable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case date(DateValue)
}

// MARK: - Block Models

/// Notion Block object
struct NotionBlock: NotionObject {
    let id: String
    let object: String
    let createdTime: Date
    let lastEditedTime: Date
    let createdBy: NotionUser
    let lastEditedBy: NotionUser
    let hasChildren: Bool
    let archived: Bool
    let type: String
    let content: BlockContent
    
    private enum CodingKeys: String, CodingKey {
        case id, object, archived, type
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case createdBy = "created_by"
        case lastEditedBy = "last_edited_by"
        case hasChildren = "has_children"
        case content
    }
}

/// Block content types
enum BlockContent: Codable {
    case paragraph([RichText])
    case heading1([RichText])
    case heading2([RichText])
    case heading3([RichText])
    case bulletedListItem([RichText])
    case numberedListItem([RichText])
    case toDo([RichText], Bool) // text, checked
    case toggle([RichText])
    case code([RichText], String?) // text, language
    case quote([RichText])
    case callout([RichText], NotionIcon?)
    case divider
    case unsupported
}

// MARK: - Rich Text Models

/// Rich text object
struct RichText: Codable {
    let type: RichTextType
    let text: TextContent?
    let mention: Mention?
    let equation: Equation?
    let annotations: Annotations
    let plainText: String
    let href: String?
    
    private enum CodingKeys: String, CodingKey {
        case type, text, mention, equation, annotations, href
        case plainText = "plain_text"
    }
}

enum RichTextType: String, Codable {
    case text
    case mention
    case equation
}

struct TextContent: Codable {
    let content: String
    let link: Link?
}

struct Link: Codable {
    let url: String
}

struct Mention: Codable {
    let type: MentionType
    let user: NotionUser?
    let page: PageReference?
    let database: DatabaseReference?
    let date: DateValue?
    
    enum MentionType: String, Codable {
        case user
        case page
        case database
        case date
        case linkPreview = "link_preview"
        case templateMention = "template_mention"
    }
}

struct PageReference: Codable {
    let id: String
}

struct DatabaseReference: Codable {
    let id: String
}

struct Equation: Codable {
    let expression: String
}

struct Annotations: Codable {
    let bold: Bool
    let italic: Bool
    let strikethrough: Bool
    let underline: Bool
    let code: Bool
    let color: String
}

// MARK: - File and Icon Models

/// Notion File object
struct NotionFile: Codable {
    let type: FileType
    let file: FileDetails?
    let external: ExternalFile?
    let name: String?
    let caption: [RichText]?
    
    enum FileType: String, Codable {
        case file
        case external
    }
}

struct FileDetails: Codable {
    let url: String
    let expiryTime: Date
    
    private enum CodingKeys: String, CodingKey {
        case url
        case expiryTime = "expiry_time"
    }
}

struct ExternalFile: Codable {
    let url: String
}

/// Notion Icon object
enum NotionIcon: Codable {
    case emoji(String)
    case external(String) // URL
    case file(String) // URL
}

// MARK: - Search Models

/// Search request
struct SearchRequest: Codable {
    let query: String?
    let sort: SearchSort?
    let filter: SearchFilter?
    let startCursor: String?
    let pageSize: Int?
    
    private enum CodingKeys: String, CodingKey {
        case query, sort, filter
        case startCursor = "start_cursor"
        case pageSize = "page_size"
    }
}

struct SearchSort: Codable {
    let direction: SortDirection
    let timestamp: SortTimestamp
    
    enum SortDirection: String, Codable {
        case ascending
        case descending
    }
    
    enum SortTimestamp: String, Codable {
        case lastEditedTime = "last_edited_time"
    }
}

struct SearchFilter: Codable {
    let value: FilterValue
    let property: String
    
    enum FilterValue: String, Codable {
        case page
        case database
    }
}

/// Search response
struct SearchResponse: Codable {
    let object: String
    let results: [SearchResult]
    let nextCursor: String?
    let hasMore: Bool
    let type: String
    let page: PageInfo
    let developer_survey: String?
    
    private enum CodingKeys: String, CodingKey {
        case object, results, type, page, developer_survey
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

enum SearchResult: Codable {
    case page(NotionPage)
    case database(NotionDatabase)
}

struct PageInfo: Codable {
    // Add page info properties as needed
}

// MARK: - Response Models

/// Generic paginated response
struct PaginatedResponse<T: Codable>: Codable {
    let object: String
    let results: [T]
    let nextCursor: String?
    let hasMore: Bool
    let type: String?
    let page: PageInfo?
    let developerSurvey: String?
    
    private enum CodingKeys: String, CodingKey {
        case object, results, type, page
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
        case developerSurvey = "developer_survey"
    }
}

/// Error response from Notion API
struct NotionAPIError: Codable, Error, LocalizedError {
    let object: String
    let status: Int
    let code: String
    let message: String
    let developerSurvey: String?
    
    private enum CodingKeys: String, CodingKey {
        case object, status, code, message
        case developerSurvey = "developer_survey"
    }
    
    var errorDescription: String? {
        return message
    }
}