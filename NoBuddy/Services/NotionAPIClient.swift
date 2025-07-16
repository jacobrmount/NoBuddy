import Foundation
import Combine

/// Comprehensive Notion API client with rate limiting and caching
class NotionAPIClient: ObservableObject {
    
    // MARK: - Properties
    
    private let baseURL = "https://api.notion.com/v1"
    private let apiVersion = "2022-06-28"
    private let session: URLSession
    private let rateLimiter: RateLimiter
    private let cache: APICache
    
    // MARK: - Initialization
    
    init() {
        // Configure URL session with proper timeout and caching
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        
        self.session = URLSession(configuration: config)
        self.rateLimiter = RateLimiter(requestsPerSecond: 3)
        self.cache = APICache()
    }
    
    // MARK: - User Endpoints
    
    /// Get current user information
    func getCurrentUser(token: String) async throws -> NotionUser {
        let endpoint = "/users/me"
        return try await makeRequest(endpoint: endpoint, token: token, method: .GET)
    }
    
    /// Get user by ID
    func getUser(id: String, token: String) async throws -> NotionUser {
        let endpoint = "/users/\(id)"
        return try await makeRequest(endpoint: endpoint, token: token, method: .GET)
    }
    
    /// List all users
    func listUsers(token: String, startCursor: String? = nil, pageSize: Int = 100) async throws -> PaginatedResponse<NotionUser> {
        var endpoint = "/users?page_size=\(pageSize)"
        if let cursor = startCursor {
            endpoint += "&start_cursor=\(cursor)"
        }
        return try await makeRequest(endpoint: endpoint, token: token, method: .GET)
    }
    
    // MARK: - Database Endpoints
    
    /// Get database by ID
    func getDatabase(id: String, token: String) async throws -> NotionDatabase {
        let endpoint = "/databases/\(id)"
        let cacheKey = "database_\(id)"
        
        // Check cache first
        if let cached: NotionDatabase = cache.get(key: cacheKey) {
            return cached
        }
        
        let database: NotionDatabase = try await makeRequest(endpoint: endpoint, token: token, method: .GET)
        cache.set(key: cacheKey, value: database, ttl: 300) // Cache for 5 minutes
        
        return database
    }
    
    /// Query database with filters and sorting
    func queryDatabase(
        id: String,
        token: String,
        filter: DatabaseFilter? = nil,
        sorts: [DatabaseSort]? = nil,
        startCursor: String? = nil,
        pageSize: Int = 100
    ) async throws -> PaginatedResponse<NotionPage> {
        let endpoint = "/databases/\(id)/query"
        
        var body: [String: Any] = [
            "page_size": pageSize
        ]
        
        if let filter = filter {
            body["filter"] = try filter.toDictionary()
        }
        
        if let sorts = sorts {
            body["sorts"] = try sorts.map { try $0.toDictionary() }
        }
        
        if let cursor = startCursor {
            body["start_cursor"] = cursor
        }
        
        return try await makeRequest(
            endpoint: endpoint,
            token: token,
            method: .POST,
            body: body
        )
    }
    
    /// Create a new database
    func createDatabase(
        parent: NotionParent,
        title: [RichText],
        properties: [String: DatabaseProperty],
        token: String
    ) async throws -> NotionDatabase {
        let endpoint = "/databases"
        
        let body: [String: Any] = [
            "parent": try parent.toDictionary(),
            "title": try title.map { try $0.toDictionary() },
            "properties": try properties.mapValues { try $0.toDictionary() }
        ]
        
        return try await makeRequest(
            endpoint: endpoint,
            token: token,
            method: .POST,
            body: body
        )
    }
    
    /// Update database properties
    func updateDatabase(
        id: String,
        title: [RichText]? = nil,
        properties: [String: DatabaseProperty]? = nil,
        token: String
    ) async throws -> NotionDatabase {
        let endpoint = "/databases/\(id)"
        
        var body: [String: Any] = [:]
        
        if let title = title {
            body["title"] = try title.map { try $0.toDictionary() }
        }
        
        if let properties = properties {
            body["properties"] = try properties.mapValues { try $0.toDictionary() }
        }
        
        let database: NotionDatabase = try await makeRequest(
            endpoint: endpoint,
            token: token,
            method: .PATCH,
            body: body
        )
        
        // Invalidate cache
        cache.remove(key: "database_\(id)")
        
        return database
    }
    
    // MARK: - Page Endpoints
    
    /// Get page by ID
    func getPage(id: String, token: String) async throws -> NotionPage {
        let endpoint = "/pages/\(id)"
        let cacheKey = "page_\(id)"
        
        // Check cache first
        if let cached: NotionPage = cache.get(key: cacheKey) {
            return cached
        }
        
        let page: NotionPage = try await makeRequest(endpoint: endpoint, token: token, method: .GET)
        cache.set(key: cacheKey, value: page, ttl: 180) // Cache for 3 minutes
        
        return page
    }
    
    /// Create a new page
    func createPage(
        parent: NotionParent,
        properties: [String: PageProperty],
        children: [NotionBlock]? = nil,
        icon: NotionIcon? = nil,
        cover: NotionFile? = nil,
        token: String
    ) async throws -> NotionPage {
        let endpoint = "/pages"
        
        var body: [String: Any] = [
            "parent": try parent.toDictionary(),
            "properties": try properties.mapValues { try $0.toDictionary() }
        ]
        
        if let children = children {
            body["children"] = try children.map { try $0.toDictionary() }
        }
        
        if let icon = icon {
            body["icon"] = try icon.toDictionary()
        }
        
        if let cover = cover {
            body["cover"] = try cover.toDictionary()
        }
        
        return try await makeRequest(
            endpoint: endpoint,
            token: token,
            method: .POST,
            body: body
        )
    }
    
    /// Update page properties
    func updatePage(
        id: String,
        properties: [String: PageProperty]? = nil,
        archived: Bool? = nil,
        icon: NotionIcon? = nil,
        cover: NotionFile? = nil,
        token: String
    ) async throws -> NotionPage {
        let endpoint = "/pages/\(id)"
        
        var body: [String: Any] = [:]
        
        if let properties = properties {
            body["properties"] = try properties.mapValues { try $0.toDictionary() }
        }
        
        if let archived = archived {
            body["archived"] = archived
        }
        
        if let icon = icon {
            body["icon"] = try icon.toDictionary()
        }
        
        if let cover = cover {
            body["cover"] = try cover.toDictionary()
        }
        
        let page: NotionPage = try await makeRequest(
            endpoint: endpoint,
            token: token,
            method: .PATCH,
            body: body
        )
        
        // Invalidate cache
        cache.remove(key: "page_\(id)")
        
        return page
    }
    
    // MARK: - Block Endpoints
    
    /// Get block children
    func getBlockChildren(
        blockId: String,
        token: String,
        startCursor: String? = nil,
        pageSize: Int = 100
    ) async throws -> PaginatedResponse<NotionBlock> {
        var endpoint = "/blocks/\(blockId)/children?page_size=\(pageSize)"
        if let cursor = startCursor {
            endpoint += "&start_cursor=\(cursor)"
        }
        
        return try await makeRequest(endpoint: endpoint, token: token, method: .GET)
    }
    
    /// Append block children
    func appendBlockChildren(
        blockId: String,
        children: [NotionBlock],
        token: String
    ) async throws -> PaginatedResponse<NotionBlock> {
        let endpoint = "/blocks/\(blockId)/children"
        
        let body: [String: Any] = [
            "children": try children.map { try $0.toDictionary() }
        ]
        
        return try await makeRequest(
            endpoint: endpoint,
            token: token,
            method: .PATCH,
            body: body
        )
    }
    
    /// Update block
    func updateBlock(
        blockId: String,
        block: NotionBlock,
        token: String
    ) async throws -> NotionBlock {
        let endpoint = "/blocks/\(blockId)"
        
        let body = try block.toDictionary()
        
        return try await makeRequest(
            endpoint: endpoint,
            token: token,
            method: .PATCH,
            body: body
        )
    }
    
    /// Delete block
    func deleteBlock(blockId: String, token: String) async throws -> NotionBlock {
        let endpoint = "/blocks/\(blockId)"
        
        return try await makeRequest(endpoint: endpoint, token: token, method: .DELETE)
    }
    
    // MARK: - Search Endpoints
    
    /// Search across all pages and databases
    func search(
        query: String? = nil,
        filter: SearchFilter? = nil,
        sort: SearchSort? = nil,
        startCursor: String? = nil,
        pageSize: Int = 100,
        token: String
    ) async throws -> SearchResponse {
        let endpoint = "/search"
        
        var body: [String: Any] = [
            "page_size": pageSize
        ]
        
        if let query = query {
            body["query"] = query
        }
        
        if let filter = filter {
            body["filter"] = try filter.toDictionary()
        }
        
        if let sort = sort {
            body["sort"] = try sort.toDictionary()
        }
        
        if let cursor = startCursor {
            body["start_cursor"] = cursor
        }
        
        return try await makeRequest(
            endpoint: endpoint,
            token: token,
            method: .POST,
            body: body
        )
    }
    
    // MARK: - Private Methods
    
    private func makeRequest<T: Codable>(
        endpoint: String,
        token: String,
        method: HTTPMethod,
        body: [String: Any]? = nil
    ) async throws -> T {
        // Apply rate limiting
        await rateLimiter.acquirePermission()
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw NotionAPIError(
                object: "error",
                status: 400,
                code: "invalid_url",
                message: "Invalid URL: \(endpoint)",
                developerSurvey: nil
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                throw NotionAPIError(
                    object: "error",
                    status: 400,
                    code: "invalid_json",
                    message: "Failed to encode request body",
                    developerSurvey: nil
                )
            }
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NotionAPIError(
                    object: "error",
                    status: 500,
                    code: "invalid_response",
                    message: "Invalid response from server",
                    developerSurvey: nil
                )
            }
            
            // Check for API errors
            if httpResponse.statusCode >= 400 {
                let decoder = JSONDecoder()
                if let apiError = try? decoder.decode(NotionAPIError.self, from: data) {
                    throw apiError
                } else {
                    throw NotionAPIError(
                        object: "error",
                        status: httpResponse.statusCode,
                        code: "unknown_error",
                        message: "Unknown error occurred",
                        developerSurvey: nil
                    )
                }
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            return try decoder.decode(T.self, from: data)
        } catch let urlError as URLError {
            throw NotionAPIError(
                object: "error",
                status: 0,
                code: "network_error",
                message: "Network error: \(urlError.localizedDescription)",
                developerSurvey: nil
            )
        }
    }
}

// MARK: - Supporting Types

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PATCH = "PATCH"
    case DELETE = "DELETE"
}

// MARK: - Database Query Types

struct DatabaseFilter: Codable {
    // Simplified filter structure - can be expanded
    let property: String
    let condition: FilterCondition
    
    func toDictionary() throws -> [String: Any] {
        return [
            "property": property,
            condition.type: try condition.toDictionary()
        ]
    }
}

enum FilterCondition {
    case equals(String)
    case contains(String)
    case isEmpty
    case isNotEmpty
    case checkbox(Bool)
    case number(NumberCondition)
    case date(DateCondition)
    
    var type: String {
        switch self {
        case .equals: return "equals"
        case .contains: return "contains"
        case .isEmpty: return "is_empty"
        case .isNotEmpty: return "is_not_empty"
        case .checkbox: return "checkbox"
        case .number: return "number"
        case .date: return "date"
        }
    }
    
    func toDictionary() throws -> [String: Any] {
        switch self {
        case .equals(let value):
            return ["equals": value]
        case .contains(let value):
            return ["contains": value]
        case .isEmpty:
            return ["is_empty": true]
        case .isNotEmpty:
            return ["is_not_empty": true]
        case .checkbox(let value):
            return ["equals": value]
        case .number(let condition):
            return try condition.toDictionary()
        case .date(let condition):
            return try condition.toDictionary()
        }
    }
}

struct NumberCondition {
    let operation: String // "equals", "greater_than", "less_than", etc.
    let value: Double
    
    func toDictionary() throws -> [String: Any] {
        return [operation: value]
    }
}

struct DateCondition {
    let operation: String // "equals", "before", "after", etc.
    let value: String // ISO 8601 date string
    
    func toDictionary() throws -> [String: Any] {
        return [operation: value]
    }
}

struct DatabaseSort: Codable {
    let property: String
    let direction: SortDirection
    
    enum SortDirection: String, Codable {
        case ascending
        case descending
    }
    
    func toDictionary() throws -> [String: Any] {
        return [
            "property": property,
            "direction": direction.rawValue
        ]
    }
}

// MARK: - Rate Limiter

actor RateLimiter {
    private let requestsPerSecond: Double
    private let interval: TimeInterval
    private var lastRequestTime: Date = Date.distantPast
    
    init(requestsPerSecond: Double) {
        self.requestsPerSecond = requestsPerSecond
        self.interval = 1.0 / requestsPerSecond
    }
    
    func acquirePermission() async {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        if timeSinceLastRequest < interval {
            let delay = interval - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
}

// MARK: - Cache

class APICache {
    private var cache: [String: CacheItem] = [:]
    private let queue = DispatchQueue(label: "com.nobuddy.cache", attributes: .concurrent)
    
    private struct CacheItem {
        let data: Data
        let expiryDate: Date
    }
    
    func get<T: Codable>(key: String) -> T? {
        return queue.sync {
            guard let item = cache[key],
                  item.expiryDate > Date() else {
                cache.removeValue(forKey: key)
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(T.self, from: item.data)
        }
    }
    
    func set<T: Codable>(key: String, value: T, ttl: TimeInterval) {
        queue.async(flags: .barrier) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            guard let data = try? encoder.encode(value) else { return }
            
            let expiryDate = Date().addingTimeInterval(ttl)
            self.cache[key] = CacheItem(data: data, expiryDate: expiryDate)
        }
    }
    
    func remove(key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

// MARK: - Model Extensions for Serialization

extension NotionParent {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = ["type": type.rawValue]
        
        switch type {
        case .database_id:
            if let databaseId = databaseId {
                dict["database_id"] = databaseId
            }
        case .page_id:
            if let pageId = pageId {
                dict["page_id"] = pageId
            }
        case .workspace:
            dict["workspace"] = true
        case .block_id:
            if let pageId = pageId {
                dict["block_id"] = pageId
            }
        }
        
        return dict
    }
}

extension RichText {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "annotations": [
                "bold": annotations.bold,
                "italic": annotations.italic,
                "strikethrough": annotations.strikethrough,
                "underline": annotations.underline,
                "code": annotations.code,
                "color": annotations.color
            ]
        ]
        
        if let text = text {
            dict["text"] = [
                "content": text.content,
                "link": text.link?.url as Any
            ]
        }
        
        if let href = href {
            dict["href"] = href
        }
        
        return dict
    }
}

extension DatabaseProperty {
    func toDictionary() throws -> [String: Any] {
        // Simplified implementation - would need full implementation for all property types
        return [:]
    }
}

extension PageProperty {
    func toDictionary() throws -> [String: Any] {
        // Simplified implementation - would need full implementation for all property types
        return [:]
    }
}

extension NotionBlock {
    func toDictionary() throws -> [String: Any] {
        // Simplified implementation - would need full implementation for all block types
        return [
            "type": type,
            "object": object
        ]
    }
}

extension NotionIcon {
    func toDictionary() throws -> [String: Any] {
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

extension NotionFile {
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = ["type": type.rawValue]
        
        switch type {
        case .file:
            if let file = file {
                dict["file"] = ["url": file.url]
            }
        case .external:
            if let external = external {
                dict["external"] = ["url": external.url]
            }
        }
        
        return dict
    }
}

extension SearchFilter {
    func toDictionary() throws -> [String: Any] {
        return [
            "value": value.rawValue,
            "property": property
        ]
    }
}

extension SearchSort {
    func toDictionary() throws -> [String: Any] {
        return [
            "direction": direction.rawValue,
            "timestamp": timestamp.rawValue
        ]
    }
}