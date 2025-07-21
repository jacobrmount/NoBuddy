import Foundation

/// Client for interacting with the Notion API v1
class NotionAPIClient {
    
    // MARK: - Properties
    
    private let token: String
    private let baseURL = "https://api.notion.com/v1"
    private let session: URLSession
    private let rateLimiter: RateLimiter
    
    // MARK: - Initialization
    
    init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
        self.rateLimiter = RateLimiter(requestsPerSecond: 3) // Notion API limit
    }
    
    // MARK: - User Endpoints
    
    /// Get the current user
    func getCurrentUser() async throws -> NotionUser {
        return try await makeRequest(endpoint: "/users/me", method: .GET)
    }
    
    /// Get a user by ID
    func getUser(id: String) async throws -> NotionUser {
        return try await makeRequest(endpoint: "/users/\(id)", method: .GET)
    }
    
    /// List all users
    func listUsers(startCursor: String? = nil, pageSize: Int = 100) async throws -> ListResponse<NotionUser> {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        
        if let startCursor = startCursor {
            queryItems.append(URLQueryItem(name: "start_cursor", value: startCursor))
        }
        
        return try await makeRequest(endpoint: "/users", method: .GET, queryItems: queryItems)
    }
    
    // MARK: - Database Endpoints
    
    /// Get a database by ID
    func getDatabase(id: String) async throws -> NotionDatabase {
        return try await makeRequest(endpoint: "/databases/\(id)", method: .GET)
    }
    
    /// Query a database
    func queryDatabase(
        id: String,
        filter: DatabaseFilter? = nil,
        sorts: [DatabaseSort]? = nil,
        startCursor: String? = nil,
        pageSize: Int = 100
    ) async throws -> DatabaseQueryResponse {
        var body: [String: Any] = [
            "page_size": pageSize
        ]
        
        if let filter = filter {
            body["filter"] = filter.toDictionary()
        }
        
        if let sorts = sorts {
            body["sorts"] = sorts.map { $0.toDictionary() }
        }
        
        if let startCursor = startCursor {
            body["start_cursor"] = startCursor
        }
        
        return try await makeRequest(endpoint: "/databases/\(id)/query", method: .POST, body: body)
    }
    
    /// Create a database
    func createDatabase(parent: Parent, title: [RichText], properties: [String: Property]) async throws -> NotionDatabase {
        let body: [String: Any] = [
            "parent": parent.toDictionary(),
            "title": title.map { $0.toDictionary() },
            "properties": properties.mapValues { $0.toDictionary() }
        ]
        
        return try await makeRequest(endpoint: "/databases", method: .POST, body: body)
    }
    
    /// Update a database
    func updateDatabase(
        id: String,
        title: [RichText]? = nil,
        description: [RichText]? = nil,
        properties: [String: Property]? = nil
    ) async throws -> NotionDatabase {
        var body: [String: Any] = [:]
        
        if let title = title {
            body["title"] = title.map { $0.toDictionary() }
        }
        
        if let description = description {
            body["description"] = description.map { $0.toDictionary() }
        }
        
        if let properties = properties {
            body["properties"] = properties.mapValues { $0.toDictionary() }
        }
        
        return try await makeRequest(endpoint: "/databases/\(id)", method: .PATCH, body: body)
    }
    
    /// Get a page by ID
    func getPage(id: String) async throws -> NotionPage {
        return try await makeRequest(endpoint: "/pages/\(id)", method: .GET)
    }
    
    /// Search for pages and databases
    func search(
        query: String? = nil,
        filter: SearchFilter? = nil,
        sort: SearchSort? = nil,
        startCursor: String? = nil,
        pageSize: Int = 100
    ) async throws -> SearchResponse {
        var body: [String: Any] = [
            "page_size": pageSize
        ]
        
        if let query = query {
            body["query"] = query
        }
        
        if let filter = filter {
            body["filter"] = filter.toDictionary()
        }
        
        if let sort = sort {
            body["sort"] = sort.toDictionary()
        }
        
        if let startCursor = startCursor {
            body["start_cursor"] = startCursor
        }
        
        return try await makeRequest(endpoint: "/search", method: .POST, body: body)
    }
    
    // MARK: - Private Methods
    
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem]? = nil,
        body: [String: Any]? = nil
    ) async throws -> T {
        // Rate limiting
        await rateLimiter.waitIfNeeded()
        
        // Build URL
        var components = URLComponents(string: baseURL + endpoint)!
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIClientError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add body if provided
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        // Make request
        let (data, response) = try await session.data(for: request)
        
        // Handle HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let notionError = try? JSONDecoder().decode(NotionAPIError.self, from: data) {
                throw APIClientError.notionAPIError(notionError)
            } else {
                throw APIClientError.httpError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
            }
        }
        
        // Decode response
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decodingError(error)
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

/// Client-side API errors (separate from Notion API error responses)
enum APIClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String)
    case decodingError(Error)
    case notionAPIError(NotionAPIError)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .notionAPIError(let notionError):
            return notionError.message
        }
    }
}

/// Generic list response wrapper
struct ListResponse<T: Codable>: Codable {
    let object: String
    let results: [T]
    let nextCursor: String?
    let hasMore: Bool
    
    private enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

/// Rate limiter to respect Notion API limits
actor RateLimiter {
    private let requestsPerSecond: Double
    private let interval: TimeInterval
    private var lastRequestTime: Date = Date.distantPast
    
    init(requestsPerSecond: Double) {
        self.requestsPerSecond = requestsPerSecond
        self.interval = 1.0 / requestsPerSecond
    }
    
    func waitIfNeeded() async {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        if timeSinceLastRequest < interval {
            let waitTime = interval - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
}

// MARK: - Filter and Sort Types

struct DatabaseFilter {
    func toDictionary() -> [String: Any] {
        return [:]
    }
}

struct DatabaseSort {
    let property: String
    let direction: SortDirection
    
    enum SortDirection: String {
        case ascending = "ascending"
        case descending = "descending"
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "property": property,
            "direction": direction.rawValue
        ]
    }
}

struct SearchFilter {
    let value: SearchFilterValue
    let property: String
    
    enum SearchFilterValue: String {
        case page = "page"
        case database = "database"
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "value": value.rawValue,
            "property": property
        ]
    }
}

struct SearchSort {
    let direction: SortDirection
    let timestamp: SortTimestamp
    
    enum SortDirection: String {
        case ascending = "ascending"
        case descending = "descending"
    }
    
    enum SortTimestamp: String {
        case lastEditedTime = "last_edited_time"
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "direction": direction.rawValue,
            "timestamp": timestamp.rawValue
        ]
    }
}

// MARK: - Extensions for Dictionary Conversion

extension NotionToken {
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "token": token
        ]
    }
}

extension RichText {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "plain_text": plainText,
            "annotations": annotations.toDictionary()
        ]
        
        if let text = text {
            dict["text"] = text.toDictionary()
        }
        
        if let href = href {
            dict["href"] = href
        }
        
        return dict
    }
}

extension RichText.TextContent {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["content": content]
        if let link = link {
            dict["link"] = ["url": link.url]
        }
        return dict
    }
}

extension RichText.Annotations {
    func toDictionary() -> [String: Any] {
        return [
            "bold": bold,
            "italic": italic,
            "strikethrough": strikethrough,
            "underline": underline,
            "code": code,
            "color": color.rawValue
        ]
    }
}

extension Parent {
    func toDictionary() -> [String: Any] {
        switch self {
        case .database(let databaseId):
            return [
                "type": "database_id",
                "database_id": databaseId
            ]
        case .page(let pageId):
            return [
                "type": "page_id",
                "page_id": pageId
            ]
        case .workspace:
            return [
                "type": "workspace",
                "workspace": true
            ]
        case .block(let blockId):
            return [
                "type": "block_id",
                "block_id": blockId
            ]
        }
    }
}

extension Property {
    func toDictionary() -> [String: Any] {
        return [:]
    }
}

extension PropertyValue {
    func toDictionary() -> [String: Any] {
        return [:]
    }
}

extension FileOrEmoji {
    func toDictionary() -> [String: Any] {
        return [:]
    }
}

extension File {
    func toDictionary() -> [String: Any] {
        return [:]
    }
}

extension NotionBlock {
    func toDictionary() -> [String: Any] {
        return [:]
    }
}
