import Foundation

// MARK: - JSON Value Helper

/// Helper enum to handle dynamic JSON values
enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode JSONValue")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
    
    /// Convert JSONValue to Any
    var value: Any {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .bool(let value):
            return value
        case .array(let values):
            return values.map { $0.value }
        case .object(let dict):
            return dict.mapValues { $0.value }
        case .null:
            return NSNull()
        }
    }
    
    /// Create JSONValue from Any
    init(from value: Any) {
        if let string = value as? String {
            self = .string(string)
        } else if let int = value as? Int {
            self = .int(int)
        } else if let double = value as? Double {
            self = .double(double)
        } else if let bool = value as? Bool {
            self = .bool(bool)
        } else if let array = value as? [Any] {
            self = .array(array.map { JSONValue(from: $0) })
        } else if let dict = value as? [String: Any] {
            self = .object(dict.mapValues { JSONValue(from: $0) })
        } else {
            self = .null
        }
    }
}

// MARK: - Database Info Model

/// Essential metadata for a Notion database
struct DatabaseInfo: Identifiable, Codable {
    let id: String
    let title: String
    let icon: String?
    let properties: [String: PropertyType]
    let lastEditedTime: Date
    let createdTime: Date
    let url: String?
    
    /// Cache metadata
    let cachedAt: Date
    
    init(id: String, title: String, icon: String? = nil, properties: [String: PropertyType] = [:], 
         lastEditedTime: Date = Date(), createdTime: Date = Date(), url: String? = nil, cachedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.icon = icon
        self.properties = properties
        self.lastEditedTime = lastEditedTime
        self.createdTime = createdTime
        self.url = url
        self.cachedAt = cachedAt
    }
    
    /// Check if cache is expired (default: 5 minutes)
    func isCacheExpired(expirationInterval: TimeInterval = 300) -> Bool {
        return Date().timeIntervalSince(cachedAt) > expirationInterval
    }
}

// MARK: - Property Type

/// Represents different Notion property types
enum PropertyType: String, Codable {
    case title = "title"
    case richText = "rich_text"
    case number = "number"
    case select = "select"
    case multiSelect = "multi_select"
    case date = "date"
    case people = "people"
    case files = "files"
    case checkbox = "checkbox"
    case url = "url"
    case email = "email"
    case phoneNumber = "phone_number"
    case formula = "formula"
    case relation = "relation"
    case rollup = "rollup"
    case createdTime = "created_time"
    case createdBy = "created_by"
    case lastEditedTime = "last_edited_time"
    case lastEditedBy = "last_edited_by"
    case status = "status"
    
    /// User-friendly display name
    var displayName: String {
        switch self {
        case .title: return "Title"
        case .richText: return "Text"
        case .number: return "Number"
        case .select: return "Select"
        case .multiSelect: return "Multi-select"
        case .date: return "Date"
        case .people: return "Person"
        case .files: return "Files"
        case .checkbox: return "Checkbox"
        case .url: return "URL"
        case .email: return "Email"
        case .phoneNumber: return "Phone"
        case .formula: return "Formula"
        case .relation: return "Relation"
        case .rollup: return "Rollup"
        case .createdTime: return "Created time"
        case .createdBy: return "Created by"
        case .lastEditedTime: return "Last edited time"
        case .lastEditedBy: return "Last edited by"
        case .status: return "Status"
        }
    }
    
    /// Icon for property type
    var icon: String {
        switch self {
        case .title: return "📝"
        case .richText: return "📄"
        case .number: return "🔢"
        case .select: return "🔽"
        case .multiSelect: return "🏷️"
        case .date: return "📅"
        case .people: return "👤"
        case .files: return "📎"
        case .checkbox: return "☑️"
        case .url: return "🔗"
        case .email: return "📧"
        case .phoneNumber: return "📞"
        case .formula: return "🧮"
        case .relation: return "🔗"
        case .rollup: return "📊"
        case .createdTime: return "🕐"
        case .createdBy: return "👤"
        case .lastEditedTime: return "🕐"
        case .lastEditedBy: return "👤"
        case .status: return "🏷️"
        }
    }
}

// MARK: - Database Cache

/// Cache for database information
class DatabaseCache {
    private var cache: [String: DatabaseInfo] = [:]
    private let cacheQueue = DispatchQueue(label: "com.nobuddy.databasecache", attributes: .concurrent)
    
    /// Store databases in cache
    func store(_ databases: [DatabaseInfo]) {
        cacheQueue.async(flags: .barrier) {
            for database in databases {
                self.cache[database.id] = database
            }
        }
    }
    
    /// Retrieve cached databases
    func retrieveAll() -> [DatabaseInfo] {
        cacheQueue.sync {
            Array(cache.values)
        }
    }
    
    /// Retrieve specific database
    func retrieve(id: String) -> DatabaseInfo? {
        cacheQueue.sync {
            cache[id]
        }
    }
    
    /// Clear cache
    func clear() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    /// Remove expired entries
    func removeExpired(expirationInterval: TimeInterval = 300) {
        cacheQueue.async(flags: .barrier) {
            self.cache = self.cache.filter { !$0.value.isCacheExpired(expirationInterval: expirationInterval) }
        }
    }
}

// MARK: - Database Search Response

/// Enhanced search response for databases with full metadata
struct DatabaseSearchResponse: Codable {
    let object: String
    let results: [DatabaseSearchResult]
    let nextCursor: String?
    let hasMore: Bool
    
    private enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

/// Individual database result from search
struct DatabaseSearchResult: Codable {
    let object: String
    let id: String
    let title: [[String: Any]]?
    let icon: [String: Any]?
    let properties: [String: [String: Any]]
    let lastEditedTime: Date
    let createdTime: Date
    let url: String?
    
    private enum CodingKeys: String, CodingKey {
        case object, id, title, icon, properties, url
        case lastEditedTime = "last_edited_time"
        case createdTime = "created_time"
    }
    
    // Custom decoding to handle Any types
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        object = try container.decode(String.self, forKey: .object)
        id = try container.decode(String.self, forKey: .id)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        
        // Decode dates
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let lastEditedTimeString = try container.decodeIfPresent(String.self, forKey: .lastEditedTime) {
            lastEditedTime = dateFormatter.date(from: lastEditedTimeString) ?? Date()
        } else {
            lastEditedTime = Date()
        }
        
        if let createdTimeString = try container.decodeIfPresent(String.self, forKey: .createdTime) {
            createdTime = dateFormatter.date(from: createdTimeString) ?? Date()
        } else {
            createdTime = Date()
        }
        
        // Decode dynamic JSON structures
        if let titleData = try? container.decodeIfPresent([[String: JSONValue]].self, forKey: .title) {
            title = titleData.map { dict in
                dict.mapValues { $0.value }
            }
        } else {
            title = nil
        }
        
        if let iconData = try? container.decodeIfPresent([String: JSONValue].self, forKey: .icon) {
            icon = iconData.mapValues { $0.value }
        } else {
            icon = nil
        }
        
        if let propertiesData = try? container.decode([String: [String: JSONValue]].self, forKey: .properties) {
            properties = propertiesData.mapValues { dict in
                dict.mapValues { $0.value }
            }
        } else {
            properties = [:]
        }
    }
    
    // Custom encoding to handle Any types
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(object, forKey: .object)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(url, forKey: .url)
        
        // Encode dates
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        try container.encode(dateFormatter.string(from: lastEditedTime), forKey: .lastEditedTime)
        try container.encode(dateFormatter.string(from: createdTime), forKey: .createdTime)
        
        // For now, we'll skip encoding the dynamic properties
        // This is typically fine for a response model that's only decoded
        if let titleData = title {
            let jsonTitle = titleData.map { dict in
                dict.mapValues { JSONValue(from: $0) }
            }
            try container.encode(jsonTitle, forKey: .title)
        }
        
        if let iconData = icon {
            let jsonIcon = iconData.mapValues { JSONValue(from: $0) }
            try container.encode(jsonIcon, forKey: .icon)
        }
        
        let jsonProperties = properties.mapValues { dict in
            dict.mapValues { JSONValue(from: $0) }
        }
        try container.encode(jsonProperties, forKey: .properties)
    }
}
