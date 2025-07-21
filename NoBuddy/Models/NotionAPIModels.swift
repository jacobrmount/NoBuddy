import Foundation

// MARK: - Page Models

/// Represents a Notion page
struct Page: Identifiable, Codable {
    let object: String
    let id: String
    let createdTime: Date
    let lastEditedTime: Date
    let createdBy: PartialUser
    let lastEditedBy: PartialUser
    let cover: PageCover?
    let icon: PageIcon?
    let parent: PageParent
    let archived: Bool
    let properties: [String: PropertyValue]
    let url: String
    
    private enum CodingKeys: String, CodingKey {
        case object, id, cover, icon, parent, archived, properties, url
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case createdBy = "created_by"
        case lastEditedBy = "last_edited_by"
    }
}

/// Partial user information
struct PartialUser: Codable {
    let object: String
    let id: String
}

/// Page parent (database or page)
enum PageParent: Codable {
    case database(String)
    case page(String)
    case workspace
    
    func toDictionary() -> [String: Any] {
        switch self {
        case .database(let id):
            return ["type": "database_id", "database_id": id]
        case .page(let id):
            return ["type": "page_id", "page_id": id]
        case .workspace:
            return ["type": "workspace", "workspace": true]
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "database_id":
            let id = try container.decode(String.self, forKey: .databaseId)
            self = .database(id)
        case "page_id":
            let id = try container.decode(String.self, forKey: .pageId)
            self = .page(id)
        case "workspace":
            self = .workspace
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown parent type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .database(let id):
            try container.encode("database_id", forKey: .type)
            try container.encode(id, forKey: .databaseId)
        case .page(let id):
            try container.encode("page_id", forKey: .type)
            try container.encode(id, forKey: .pageId)
        case .workspace:
            try container.encode("workspace", forKey: .type)
            try container.encode(true, forKey: .workspace)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case databaseId = "database_id"
        case pageId = "page_id"
        case workspace
    }
}

/// Page icon
enum PageIcon: Codable {
    case emoji(String)
    case external(String)
    case file(String)
    
    func toDictionary() -> [String: Any] {
        switch self {
        case .emoji(let emoji):
            return ["type": "emoji", "emoji": emoji]
        case .external(let url):
            return ["type": "external", "external": ["url": url]]
        case .file(let url):
            return ["type": "file", "file": ["url": url]]
        }
    }
}

/// Page cover
enum PageCover: Codable {
    case external(String)
    case file(String)
    
    func toDictionary() -> [String: Any] {
        switch self {
        case .external(let url):
            return ["type": "external", "external": ["url": url]]
        case .file(let url):
            return ["type": "file", "file": ["url": url]]
        }
    }
}

// MARK: - Property Value Models

/// Represents a property value that can be of various types
enum PropertyValue: Codable {
    case title([RichTextElement])
    case richText([RichTextElement])
    case number(Double?)
    case select(SelectOption?)
    case multiSelect([SelectOption])
    case date(DateValue?)
    case checkbox(Bool)
    case url(String?)
    case email(String?)
    case phoneNumber(String?)
    case formula(FormulaValue)
    case relation([Relation])
    case rollup(RollupValue)
    case people([PartialUser])
    case files([FileValue])
    case createdTime(Date)
    case createdBy(PartialUser)
    case lastEditedTime(Date)
    case lastEditedBy(PartialUser)
    case status(SelectOption?)
    
    func toDictionary() -> [String: Any] {
        switch self {
        case .title(let texts):
            return ["title": texts.map { $0.toDictionary() }]
        case .richText(let texts):
            return ["rich_text": texts.map { $0.toDictionary() }]
        case .number(let value):
            return ["number": value as Any]
        case .select(let option):
            if let option = option {
                return ["select": ["name": option.name]]
            }
            return ["select": NSNull()]
        case .multiSelect(let options):
            return ["multi_select": options.map { ["name": $0.name] }]
        case .date(let dateValue):
            if let dateValue = dateValue {
                return ["date": dateValue.toDictionary()]
            }
            return ["date": NSNull()]
        case .checkbox(let checked):
            return ["checkbox": checked]
        case .url(let url):
            return ["url": url as Any]
        case .email(let email):
            return ["email": email as Any]
        case .phoneNumber(let phone):
            return ["phone_number": phone as Any]
        case .people(let users):
            return ["people": users.map { ["id": $0.id] }]
        case .files(let files):
            return ["files": files.map { $0.toDictionary() }]
        case .status(let option):
            if let option = option {
                return ["status": ["name": option.name]]
            }
            return ["status": NSNull()]
        default:
            // Read-only properties don't have update dictionaries
            return [:]
        }
    }
}

/// Rich text element
struct RichTextElement: Codable {
    let type: String
    let text: TextContent?
    let annotations: Annotations?
    let plainText: String
    let href: String?
    
    private enum CodingKeys: String, CodingKey {
        case type, text, annotations, href
        case plainText = "plain_text"
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type,
            "text": [
                "content": text?.content ?? ""
            ]
        ]
        
        if let annotations = annotations {
            dict["annotations"] = annotations.toDictionary()
        }
        
        return dict
    }
}

struct TextContent: Codable {
    let content: String
    let link: Link?
}

struct Link: Codable {
    let url: String
}

struct Annotations: Codable {
    let bold: Bool
    let italic: Bool
    let strikethrough: Bool
    let underline: Bool
    let code: Bool
    let color: String
    
    func toDictionary() -> [String: Any] {
        return [
            "bold": bold,
            "italic": italic,
            "strikethrough": strikethrough,
            "underline": underline,
            "code": code,
            "color": color
        ]
    }
}

/// Select option
struct SelectOption: Codable {
    let id: String?
    let name: String
    let color: String?
}

/// Date value
struct DateValue: Codable {
    let start: String
    let end: String?
    let timeZone: String?
    
    private enum CodingKeys: String, CodingKey {
        case start, end
        case timeZone = "time_zone"
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["start": start]
        if let end = end {
            dict["end"] = end
        }
        if let timeZone = timeZone {
            dict["time_zone"] = timeZone
        }
        return dict
    }
}

/// Formula value
enum FormulaValue: Codable {
    case string(String?)
    case number(Double?)
    case boolean(Bool)
    case date(DateValue?)
}

/// Relation
struct Relation: Codable {
    let id: String
}

/// Rollup value
enum RollupValue: Codable {
    case number(Double?)
    case date(DateValue?)
    case array([PropertyValue])
}

/// File value
struct FileValue: Codable {
    let name: String
    let type: String
    let file: FileObject?
    let external: ExternalFile?
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "type": type
        ]
        
        if let external = external {
            dict["external"] = ["url": external.url]
        }
        
        return dict
    }
}

struct FileObject: Codable {
    let url: String
    let expiryTime: Date?
    
    private enum CodingKeys: String, CodingKey {
        case url
        case expiryTime = "expiry_time"
    }
}

struct ExternalFile: Codable {
    let url: String
}

// MARK: - Block Models

/// Represents a block (for page content)
enum Block: Codable {
    case paragraph(ParagraphBlock)
    case heading1(HeadingBlock)
    case heading2(HeadingBlock)
    case heading3(HeadingBlock)
    case bulletedListItem(ListItemBlock)
    case numberedListItem(ListItemBlock)
    case todo(TodoBlock)
    case toggle(ToggleBlock)
    case code(CodeBlock)
    case quote(QuoteBlock)
    case callout(CalloutBlock)
    case divider
    
    func toDictionary() -> [String: Any] {
        switch self {
        case .paragraph(let block):
            return [
                "object": "block",
                "type": "paragraph",
                "paragraph": block.toDictionary()
            ]
        case .heading1(let block):
            return [
                "object": "block",
                "type": "heading_1",
                "heading_1": block.toDictionary()
            ]
        case .heading2(let block):
            return [
                "object": "block",
                "type": "heading_2",
                "heading_2": block.toDictionary()
            ]
        case .heading3(let block):
            return [
                "object": "block",
                "type": "heading_3",
                "heading_3": block.toDictionary()
            ]
        case .bulletedListItem(let block):
            return [
                "object": "block",
                "type": "bulleted_list_item",
                "bulleted_list_item": block.toDictionary()
            ]
        case .numberedListItem(let block):
            return [
                "object": "block",
                "type": "numbered_list_item",
                "numbered_list_item": block.toDictionary()
            ]
        case .todo(let block):
            return [
                "object": "block",
                "type": "to_do",
                "to_do": block.toDictionary()
            ]
        case .toggle(let block):
            return [
                "object": "block",
                "type": "toggle",
                "toggle": block.toDictionary()
            ]
        case .code(let block):
            return [
                "object": "block",
                "type": "code",
                "code": block.toDictionary()
            ]
        case .quote(let block):
            return [
                "object": "block",
                "type": "quote",
                "quote": block.toDictionary()
            ]
        case .callout(let block):
            return [
                "object": "block",
                "type": "callout",
                "callout": block.toDictionary()
            ]
        case .divider:
            return [
                "object": "block",
                "type": "divider",
                "divider": [:]
            ]
        }
    }
}

struct ParagraphBlock: Codable {
    let richText: [RichTextElement]
    let color: String?
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "rich_text": richText.map { $0.toDictionary() }
        ]
        if let color = color {
            dict["color"] = color
        }
        return dict
    }
}

struct HeadingBlock: Codable {
    let richText: [RichTextElement]
    let color: String?
    let isToggleable: Bool
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
        case isToggleable = "is_toggleable"
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "rich_text": richText.map { $0.toDictionary() },
            "color": color ?? "default",
            "is_toggleable": isToggleable
        ]
    }
}

struct ListItemBlock: Codable {
    let richText: [RichTextElement]
    let color: String?
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "rich_text": richText.map { $0.toDictionary() }
        ]
        if let color = color {
            dict["color"] = color
        }
        return dict
    }
}

struct TodoBlock: Codable {
    let richText: [RichTextElement]
    let checked: Bool
    let color: String?
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case checked
        case color
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "rich_text": richText.map { $0.toDictionary() },
            "checked": checked
        ]
        if let color = color {
            dict["color"] = color
        }
        return dict
    }
}

struct ToggleBlock: Codable {
    let richText: [RichTextElement]
    let color: String?
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "rich_text": richText.map { $0.toDictionary() }
        ]
        if let color = color {
            dict["color"] = color
        }
        return dict
    }
}

struct CodeBlock: Codable {
    let richText: [RichTextElement]
    let caption: [RichTextElement]
    let language: String
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case caption
        case language
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "rich_text": richText.map { $0.toDictionary() },
            "caption": caption.map { $0.toDictionary() },
            "language": language
        ]
    }
}

struct QuoteBlock: Codable {
    let richText: [RichTextElement]
    let color: String?
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "rich_text": richText.map { $0.toDictionary() }
        ]
        if let color = color {
            dict["color"] = color
        }
        return dict
    }
}

struct CalloutBlock: Codable {
    let richText: [RichTextElement]
    let icon: PageIcon
    let color: String?
    
    private enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case icon
        case color
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "rich_text": richText.map { $0.toDictionary() },
            "icon": icon.toDictionary()
        ]
        if let color = color {
            dict["color"] = color
        }
        return dict
    }
}

// MARK: - Database Query Models

/// Database query response
struct DatabaseQueryResponse: Codable {
    let object: String
    let results: [Page]
    let nextCursor: String?
    let hasMore: Bool
    
    private enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

/// Database filter
struct DatabaseFilter {
    let property: String
    let condition: FilterCondition
    
    func toDictionary() -> [String: Any] {
        return condition.toDictionary(property: property)
    }
}

/// Filter conditions
enum FilterCondition {
    // Text filters
    case equals(String)
    case doesNotEqual(String)
    case contains(String)
    case doesNotContain(String)
    case startsWith(String)
    case endsWith(String)
    case isEmpty
    case isNotEmpty
    
    // Number filters
    case numberEquals(Double)
    case numberDoesNotEqual(Double)
    case greaterThan(Double)
    case lessThan(Double)
    case greaterThanOrEqualTo(Double)
    case lessThanOrEqualTo(Double)
    
    // Checkbox filters
    case checkboxEquals(Bool)
    
    // Select filters
    case selectEquals(String)
    case selectDoesNotEqual(String)
    
    // Multi-select filters
    case multiSelectContains(String)
    case multiSelectDoesNotContain(String)
    
    // Date filters
    case dateEquals(String)
    case dateBefore(String)
    case dateAfter(String)
    case dateOnOrBefore(String)
    case dateOnOrAfter(String)
    case dateIsEmpty
    case dateIsNotEmpty
    case datePastWeek
    case datePastMonth
    case datePastYear
    case dateNextWeek
    case dateNextMonth
    case dateNextYear
    
    // Compound filters
    case and([DatabaseFilter])
    case or([DatabaseFilter])
    
    func toDictionary(property: String? = nil) -> [String: Any] {
        switch self {
        // Text filters
        case .equals(let value):
            return ["property": property!, "rich_text": ["equals": value]]
        case .doesNotEqual(let value):
            return ["property": property!, "rich_text": ["does_not_equal": value]]
        case .contains(let value):
            return ["property": property!, "rich_text": ["contains": value]]
        case .doesNotContain(let value):
            return ["property": property!, "rich_text": ["does_not_contain": value]]
        case .startsWith(let value):
            return ["property": property!, "rich_text": ["starts_with": value]]
        case .endsWith(let value):
            return ["property": property!, "rich_text": ["ends_with": value]]
        case .isEmpty:
            return ["property": property!, "rich_text": ["is_empty": true]]
        case .isNotEmpty:
            return ["property": property!, "rich_text": ["is_not_empty": true]]
            
        // Number filters
        case .numberEquals(let value):
            return ["property": property!, "number": ["equals": value]]
        case .numberDoesNotEqual(let value):
            return ["property": property!, "number": ["does_not_equal": value]]
        case .greaterThan(let value):
            return ["property": property!, "number": ["greater_than": value]]
        case .lessThan(let value):
            return ["property": property!, "number": ["less_than": value]]
        case .greaterThanOrEqualTo(let value):
            return ["property": property!, "number": ["greater_than_or_equal_to": value]]
        case .lessThanOrEqualTo(let value):
            return ["property": property!, "number": ["less_than_or_equal_to": value]]
            
        // Checkbox filters
        case .checkboxEquals(let value):
            return ["property": property!, "checkbox": ["equals": value]]
            
        // Select filters
        case .selectEquals(let value):
            return ["property": property!, "select": ["equals": value]]
        case .selectDoesNotEqual(let value):
            return ["property": property!, "select": ["does_not_equal": value]]
            
        // Multi-select filters
        case .multiSelectContains(let value):
            return ["property": property!, "multi_select": ["contains": value]]
        case .multiSelectDoesNotContain(let value):
            return ["property": property!, "multi_select": ["does_not_contain": value]]
            
        // Date filters
        case .dateEquals(let value):
            return ["property": property!, "date": ["equals": value]]
        case .dateBefore(let value):
            return ["property": property!, "date": ["before": value]]
        case .dateAfter(let value):
            return ["property": property!, "date": ["after": value]]
        case .dateOnOrBefore(let value):
            return ["property": property!, "date": ["on_or_before": value]]
        case .dateOnOrAfter(let value):
            return ["property": property!, "date": ["on_or_after": value]]
        case .dateIsEmpty:
            return ["property": property!, "date": ["is_empty": true]]
        case .dateIsNotEmpty:
            return ["property": property!, "date": ["is_not_empty": true]]
        case .datePastWeek:
            return ["property": property!, "date": ["past_week": [:]]]
        case .datePastMonth:
            return ["property": property!, "date": ["past_month": [:]]]
        case .datePastYear:
            return ["property": property!, "date": ["past_year": [:]]]
        case .dateNextWeek:
            return ["property": property!, "date": ["next_week": [:]]]
        case .dateNextMonth:
            return ["property": property!, "date": ["next_month": [:]]]
        case .dateNextYear:
            return ["property": property!, "date": ["next_year": [:]]]
            
        // Compound filters
        case .and(let filters):
            return ["and": filters.map { $0.toDictionary() }]
        case .or(let filters):
            return ["or": filters.map { $0.toDictionary() }]
        }
    }
}

/// Database sort
struct DatabaseSort {
    let property: String?
    let timestamp: DatabaseTimestamp?
    let direction: SortDirection
    
    enum DatabaseTimestamp: String {
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
    }
    
    enum SortDirection: String {
        case ascending
        case descending
    }
    
    func toDictionary() -> [String: Any] {
        if let property = property {
            return ["property": property, "direction": direction.rawValue]
        } else if let timestamp = timestamp {
            return ["timestamp": timestamp.rawValue, "direction": direction.rawValue]
        }
        return [:]
    }
}

// MARK: - Enhanced Search Models

/// Enhanced search response with full object details

struct PageOrDatabase: Codable {
    // This would contain union type data if needed
}

// MARK: - Error Extensions

extension NotionAPIError: LocalizedError {
    var errorDescription: String? {
        return message
    }
    
    var failureReason: String? {
        return "Notion API error: \(code)"
    }
}

// MARK: - Convenience Initializers

extension PropertyValue {
    /// Create a title property value from a string
    static func title(_ text: String) -> PropertyValue {
        let richText = RichTextElement(
            type: "text",
            text: TextContent(content: text, link: nil),
            annotations: Annotations(
                bold: false,
                italic: false,
                strikethrough: false,
                underline: false,
                code: false,
                color: "default"
            ),
            plainText: text,
            href: nil
        )
        return .title([richText])
    }
    
    /// Create a rich text property value from a string
    static func text(_ text: String) -> PropertyValue {
        let richText = RichTextElement(
            type: "text",
            text: TextContent(content: text, link: nil),
            annotations: Annotations(
                bold: false,
                italic: false,
                strikethrough: false,
                underline: false,
                code: false,
                color: "default"
            ),
            plainText: text,
            href: nil
        )
        return .richText([richText])
    }
}

// MARK: - Helper Functions

extension RichTextElement {
    /// Create a simple text element
    static func text(_ content: String) -> RichTextElement {
        return RichTextElement(
            type: "text",
            text: TextContent(content: content, link: nil),
            annotations: Annotations(
                bold: false,
                italic: false,
                strikethrough: false,
                underline: false,
                code: false,
                color: "default"
            ),
            plainText: content,
            href: nil
        )
    }
}
