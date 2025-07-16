import Foundation

// MARK: - Common Notion Types

struct NotionUser: Codable, Identifiable {
    let id: String
    let type: UserType
    let name: String?
    let avatarUrl: String?
    
    enum UserType: String, Codable {
        case person = "person"
        case bot = "bot"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, name
        case avatarUrl = "avatar_url"
    }
}

struct NotionParent: Codable {
    let type: ParentType
    let databaseId: String?
    let pageId: String?
    let workspaceId: String?
    
    enum ParentType: String, Codable {
        case database = "database_id"
        case page = "page_id"
        case workspace = "workspace"
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case databaseId = "database_id"
        case pageId = "page_id"
        case workspaceId = "workspace_id"
    }
}

// MARK: - Database Models

struct NotionDatabase: Codable, Identifiable {
    let id: String
    let createdTime: Date
    let lastEditedTime: Date
    let title: [RichText]
    let description: [RichText]
    let icon: NotionIcon?
    let cover: NotionCover?
    let properties: [String: DatabaseProperty]
    let parent: NotionParent
    let url: String
    let archived: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case title, description, icon, cover, properties, parent, url, archived
    }
}

struct DatabaseProperty: Codable {
    let id: String
    let name: String
    let type: PropertyType
    let description: String?
    
    enum PropertyType: String, Codable {
        case title, richText = "rich_text", number, select, multiSelect = "multi_select"
        case date, people, files, checkbox, url, email, phoneNumber = "phone_number"
        case formula, relation, rollup, createdTime = "created_time"
        case createdBy = "created_by", lastEditedTime = "last_edited_time"
        case lastEditedBy = "last_edited_by"
    }
}

// MARK: - Page Models

struct NotionPage: Codable, Identifiable {
    let id: String
    let createdTime: Date
    let lastEditedTime: Date
    let cover: NotionCover?
    let icon: NotionIcon?
    let parent: NotionParent
    let archived: Bool
    let properties: [String: PageProperty]
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case cover, icon, parent, archived, properties, url
    }
}

enum PageProperty: Codable {
    case title([RichText])
    case richText([RichText])
    case number(Double?)
    case select(SelectOption?)
    case multiSelect([SelectOption])
    case date(DateProperty?)
    case checkbox(Bool)
    case url(String?)
    case email(String?)
    case phoneNumber(String?)
    case people([NotionUser])
    case files([FileProperty])
    
    enum CodingKeys: String, CodingKey {
        case type, title, richText = "rich_text", number, select
        case multiSelect = "multi_select", date, checkbox, url, email
        case phoneNumber = "phone_number", people, files
    }
}

// MARK: - Block Models

struct NotionBlock: Codable, Identifiable {
    let id: String
    let type: BlockType
    let createdTime: Date
    let lastEditedTime: Date
    let hasChildren: Bool
    let archived: Bool
    let content: BlockContent
    
    enum BlockType: String, Codable {
        case paragraph, heading1 = "heading_1", heading2 = "heading_2", heading3 = "heading_3"
        case bulletedListItem = "bulleted_list_item", numberedListItem = "numbered_list_item"
        case toDo = "to_do", toggle, code, quote, divider, bookmark, image, video, file
        case pdf, table, tableRow = "table_row", embed, callout, synced_block
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case hasChildren = "has_children"
        case archived
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(BlockType.self, forKey: .type)
        createdTime = try container.decode(Date.self, forKey: .createdTime)
        lastEditedTime = try container.decode(Date.self, forKey: .lastEditedTime)
        hasChildren = try container.decode(Bool.self, forKey: .hasChildren)
        archived = try container.decode(Bool.self, forKey: .archived)
        
        // Decode content based on block type
        content = try BlockContent.decode(from: decoder, blockType: type)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(createdTime, forKey: .createdTime)
        try container.encode(lastEditedTime, forKey: .lastEditedTime)
        try container.encode(hasChildren, forKey: .hasChildren)
        try container.encode(archived, forKey: .archived)
        
        try content.encode(to: encoder, blockType: type)
    }
}

enum BlockContent: Codable {
    case paragraph([RichText])
    case heading([RichText])
    case listItem([RichText])
    case toDo([RichText], checked: Bool)
    case code(String, language: String?)
    case quote([RichText])
    case divider
    case bookmark(String)
    case callout([RichText], icon: NotionIcon?)
    
    static func decode(from decoder: Decoder, blockType: NotionBlock.BlockType) throws -> BlockContent {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        
        switch blockType {
        case .paragraph:
            let content = try container.decode([RichText].self, forKey: DynamicCodingKey(stringValue: "paragraph")!)
            return .paragraph(content)
        case .heading1, .heading2, .heading3:
            let content = try container.decode([RichText].self, forKey: DynamicCodingKey(stringValue: blockType.rawValue)!)
            return .heading(content)
        case .bulletedListItem, .numberedListItem:
            let content = try container.decode([RichText].self, forKey: DynamicCodingKey(stringValue: blockType.rawValue)!)
            return .listItem(content)
        case .toDo:
            let todoContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: DynamicCodingKey(stringValue: "to_do")!)
            let content = try todoContainer.decode([RichText].self, forKey: DynamicCodingKey(stringValue: "rich_text")!)
            let checked = try todoContainer.decode(Bool.self, forKey: DynamicCodingKey(stringValue: "checked")!)
            return .toDo(content, checked: checked)
        case .divider:
            return .divider
        default:
            return .paragraph([])
        }
    }
    
    func encode(to encoder: Encoder, blockType: NotionBlock.BlockType) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        
        switch self {
        case .paragraph(let content):
            try container.encode(content, forKey: DynamicCodingKey(stringValue: "paragraph")!)
        case .heading(let content):
            try container.encode(content, forKey: DynamicCodingKey(stringValue: blockType.rawValue)!)
        case .listItem(let content):
            try container.encode(content, forKey: DynamicCodingKey(stringValue: blockType.rawValue)!)
        case .toDo(let content, let checked):
            var todoContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: DynamicCodingKey(stringValue: "to_do")!)
            try todoContainer.encode(content, forKey: DynamicCodingKey(stringValue: "rich_text")!)
            try todoContainer.encode(checked, forKey: DynamicCodingKey(stringValue: "checked")!)
        case .divider:
            var dividerContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: DynamicCodingKey(stringValue: "divider")!)
            try dividerContainer.encode([:] as [String: String], forKey: DynamicCodingKey(stringValue: "divider")!)
        default:
            break
        }
    }
}

// MARK: - Rich Text Models

struct RichText: Codable {
    let type: RichTextType
    let annotations: Annotations
    let plainText: String
    let href: String?
    let content: RichTextContent
    
    enum RichTextType: String, Codable {
        case text, mention, equation
    }
    
    struct Annotations: Codable {
        let bold: Bool
        let italic: Bool
        let strikethrough: Bool
        let underline: Bool
        let code: Bool
        let color: String
    }
    
    enum CodingKeys: String, CodingKey {
        case type, annotations
        case plainText = "plain_text"
        case href
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(RichTextType.self, forKey: .type)
        annotations = try container.decode(Annotations.self, forKey: .annotations)
        plainText = try container.decode(String.self, forKey: .plainText)
        href = try container.decodeIfPresent(String.self, forKey: .href)
        
        content = try RichTextContent.decode(from: decoder, type: type)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(annotations, forKey: .annotations)
        try container.encode(plainText, forKey: .plainText)
        try container.encodeIfPresent(href, forKey: .href)
        
        try content.encode(to: encoder, type: type)
    }
}

enum RichTextContent: Codable {
    case text(String)
    case mention(String)
    case equation(String)
    
    static func decode(from decoder: Decoder, type: RichText.RichTextType) throws -> RichTextContent {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        
        switch type {
        case .text:
            let textContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: DynamicCodingKey(stringValue: "text")!)
            let content = try textContainer.decode(String.self, forKey: DynamicCodingKey(stringValue: "content")!)
            return .text(content)
        case .mention:
            return .mention("")
        case .equation:
            let equationContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: DynamicCodingKey(stringValue: "equation")!)
            let expression = try equationContainer.decode(String.self, forKey: DynamicCodingKey(stringValue: "expression")!)
            return .equation(expression)
        }
    }
    
    func encode(to encoder: Encoder, type: RichText.RichTextType) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        
        switch self {
        case .text(let content):
            var textContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: DynamicCodingKey(stringValue: "text")!)
            try textContainer.encode(content, forKey: DynamicCodingKey(stringValue: "content")!)
        case .equation(let expression):
            var equationContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: DynamicCodingKey(stringValue: "equation")!)
            try equationContainer.encode(expression, forKey: DynamicCodingKey(stringValue: "expression")!)
        default:
            break
        }
    }
}

// MARK: - Supporting Types

struct NotionIcon: Codable {
    let type: IconType
    let emoji: String?
    let file: FileProperty?
    let external: ExternalFile?
    
    enum IconType: String, Codable {
        case emoji, file, external
    }
}

struct NotionCover: Codable {
    let type: CoverType
    let file: FileProperty?
    let external: ExternalFile?
    
    enum CoverType: String, Codable {
        case file, external
    }
}

struct FileProperty: Codable {
    let url: String
    let expiryTime: Date?
    
    enum CodingKeys: String, CodingKey {
        case url
        case expiryTime = "expiry_time"
    }
}

struct ExternalFile: Codable {
    let url: String
}

struct SelectOption: Codable {
    let id: String
    let name: String
    let color: String
}

struct DateProperty: Codable {
    let start: Date
    let end: Date?
    let timeZone: String?
    
    enum CodingKeys: String, CodingKey {
        case start, end
        case timeZone = "time_zone"
    }
}

// MARK: - API Response Models

struct NotionListResponse<T: Codable>: Codable {
    let results: [T]
    let nextCursor: String?
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

struct NotionError: Codable, Error {
    let code: String
    let message: String
}

// MARK: - Helper Types

struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}