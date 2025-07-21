import Foundation

// MARK: - Basic Models

/// Simplified NotionUser model without circular references
struct NotionUser: Identifiable, Codable {
    let id: String
    let name: String?
    let avatarUrl: String?
    let type: UserType
    let email: String?
    
    enum UserType: String, Codable {
        case person = "person"
        case bot = "bot"
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, type, email
        case avatarUrl = "avatar_url"
    }
}

/// Simplified date value for properties
struct DateValue: Codable {
    let start: Date
    let end: Date?
    let timeZone: String?
    
    private enum CodingKeys: String, CodingKey {
        case start, end
        case timeZone = "time_zone"
    }
}

/// Rich text model without circular references
struct RichText: Codable {
    let type: RichTextType
    let text: TextContent?
    let annotations: Annotations
    let plainText: String
    let href: String?
    
    enum RichTextType: String, Codable {
        case text = "text"
        case mention = "mention"
        case equation = "equation"
    }
    
    struct TextContent: Codable {
        let content: String
        let link: Link?
        
        struct Link: Codable {
            let url: String
        }
    }
    
    struct Annotations: Codable {
        let bold: Bool
        let italic: Bool
        let strikethrough: Bool
        let underline: Bool
        let code: Bool
        let color: TextColor
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, text, annotations, href
        case plainText = "plain_text"
    }
}

// MARK: - Database Models

struct NotionDatabase: Identifiable, Codable {
    let id: String
    let title: [RichText]
    let description: [RichText]?
    let url: String
    let archived: Bool
    let createdTime: Date
    let lastEditedTime: Date
    
    private enum CodingKeys: String, CodingKey {
        case id, title, description, url, archived
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
    }
}

// MARK: - Page Models

struct NotionPage: Identifiable, Codable {
    let id: String
    let title: [RichText]?
    let url: String
    let archived: Bool
    let createdTime: Date
    let lastEditedTime: Date
    
    private enum CodingKeys: String, CodingKey {
        case id, title, url, archived
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
    }
}

// MARK: - Block Models

struct NotionBlock: Identifiable, Codable {
    let id: String
    let type: BlockType
    let hasChildren: Bool
    let archived: Bool
    
    enum BlockType: String, Codable {
        case paragraph = "paragraph"
        case heading1 = "heading_1"
        case heading2 = "heading_2"
        case heading3 = "heading_3"
        case bulletedListItem = "bulleted_list_item"
        case numberedListItem = "numbered_list_item"
        case todo = "to_do"
        case toggle = "toggle"
        case childPage = "child_page"
        case childDatabase = "child_database"
        case unsupported = "unsupported"
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, type, archived
        case hasChildren = "has_children"
    }
}

// MARK: - Property Models

/// Simplified property enum without circular references
enum Property: Codable {
    case title(String)
    case richText(String)
    case number(String)
    case select(String)
    case date(String)
    case checkbox(String)
    case url(String)
    case email(String)
    case other(String)
}

/// Simplified property values without circular references
enum PropertyValue: Codable {
    case title([RichText])
    case richText([RichText])
    case number(Double?)
    case select(SelectOption?)
    case date(DateValue?)
    case checkbox(Bool)
    case url(String?)
    case email(String?)
    case other(String?)
    
    struct SelectOption: Codable {
        let id: String?
        let name: String
        let color: SelectColor
    }
}

// MARK: - File Models

struct File: Codable {
    let name: String
    let url: String
}

enum FileOrEmoji: Codable {
    case file(File)
    case emoji(String)
}

// MARK: - Parent Models

enum Parent: Codable {
    case database(String)
    case page(String)
    case workspace
    case block(String)
}

// MARK: - Color Enums

enum TextColor: String, Codable {
    case `default` = "default"
    case gray = "gray"
    case brown = "brown"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case red = "red"
}

enum SelectColor: String, Codable {
    case `default` = "default"
    case gray = "gray"
    case brown = "brown"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case red = "red"
}

// MARK: - Response Models

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

enum SearchResult: Codable {
    case page(NotionPage)
    case database(NotionDatabase)
}

struct DatabaseQueryResponse: Codable {
    let object: String
    let results: [NotionPage]
    let nextCursor: String?
    let hasMore: Bool
    
    private enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

struct BlockListResponse: Codable {
    let object: String
    let results: [NotionBlock]
    let nextCursor: String?
    let hasMore: Bool
    
    private enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
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

// MARK: - Helper Types

struct EmptyObject: Codable {
    // Empty struct for API compatibility
}
