import Foundation
import Combine

/// Comprehensive client for the Notion API v1
@MainActor
class NotionAPIClient: ObservableObject {
    
    // MARK: - Properties
    
    private let baseURL = "https://api.notion.com/v1"
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    // Rate limiting (3 requests per second as per Notion API limits)
    private let rateLimiter = RateLimiter(maxRequests: 3, timeWindow: 1.0)
    
    // Cache for responses
    private var responseCache: [String: CachedResponse] = [:]
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    init() {
        // Configure URLSession with timeout and headers
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        // Configure JSON decoder with date formatting
        self.decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .formatted(formatter)
        
        // Configure JSON encoder
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(formatter)
    }
    
    // MARK: - Authentication
    
    /// Validate a Notion integration token
    func validateToken(_ token: String) async -> TokenValidationResult {
        do {
            let user = try await getCurrentUser(token: token)
            
            // Extract workspace information if available
            let workspaceName = user.name ?? "Unknown Workspace"
            let workspaceIcon = user.avatarUrl
            
            return .valid(workspaceName: workspaceName, workspaceIcon: workspaceIcon)
        } catch {
            if let notionError = error as? NotionError {
                return .invalid(error: notionError.message)
            } else if error is URLError {
                return .networkError(error: error.localizedDescription)
            } else {
                return .invalid(error: error.localizedDescription)
            }
        }
    }
    
    // MARK: - User Endpoints
    
    /// Get current user information
    func getCurrentUser(token: String) async throws -> NotionUser {
        let endpoint = "/users/me"
        return try await makeRequest(endpoint: endpoint, method: .GET, token: token)
    }
    
    /// Get all users in workspace
    func getUsers(token: String, startCursor: String? = nil) async throws -> NotionListResponse<NotionUser> {
        var endpoint = "/users"
        
        if let cursor = startCursor {
            endpoint += "?start_cursor=\(cursor)"
        }
        
        return try await makeRequest(endpoint: endpoint, method: .GET, token: token)
    }
    
    // MARK: - Database Endpoints
    
    /// Get a database by ID
    func getDatabase(id: String, token: String) async throws -> NotionDatabase {
        let endpoint = "/databases/\(id)"
        return try await makeRequest(endpoint: endpoint, method: .GET, token: token)
    }
    
    /// Query a database
    func queryDatabase(
        id: String,
        token: String,
        filter: [String: Any]? = nil,
        sorts: [[String: Any]]? = nil,
        startCursor: String? = nil,
        pageSize: Int? = nil
    ) async throws -> NotionListResponse<NotionPage> {
        let endpoint = "/databases/\(id)/query"
        
        var body: [String: Any] = [:]
        if let filter = filter { body["filter"] = filter }
        if let sorts = sorts { body["sorts"] = sorts }
        if let cursor = startCursor { body["start_cursor"] = cursor }
        if let size = pageSize { body["page_size"] = size }
        
        return try await makeRequest(endpoint: endpoint, method: .POST, token: token, body: body)
    }
    
    /// Create a database
    func createDatabase(
        parentPageId: String,
        title: String,
        properties: [String: Any],
        token: String
    ) async throws -> NotionDatabase {
        let endpoint = "/databases"
        
        let body: [String: Any] = [
            "parent": ["page_id": parentPageId],
            "title": [
                [
                    "type": "text",
                    "text": ["content": title]
                ]
            ],
            "properties": properties
        ]
        
        return try await makeRequest(endpoint: endpoint, method: .POST, token: token, body: body)
    }
    
    // MARK: - Page Endpoints
    
    /// Get a page by ID
    func getPage(id: String, token: String) async throws -> NotionPage {
        let endpoint = "/pages/\(id)"
        return try await makeRequest(endpoint: endpoint, method: .GET, token: token)
    }
    
    /// Create a new page
    func createPage(
        parent: [String: String],
        properties: [String: Any],
        children: [[String: Any]]? = nil,
        token: String
    ) async throws -> NotionPage {
        let endpoint = "/pages"
        
        var body: [String: Any] = [
            "parent": parent,
            "properties": properties
        ]
        
        if let children = children {
            body["children"] = children
        }
        
        return try await makeRequest(endpoint: endpoint, method: .POST, token: token, body: body)
    }
    
    /// Update a page
    func updatePage(
        id: String,
        properties: [String: Any],
        token: String
    ) async throws -> NotionPage {
        let endpoint = "/pages/\(id)"
        
        let body: [String: Any] = [
            "properties": properties
        ]
        
        return try await makeRequest(endpoint: endpoint, method: .PATCH, token: token, body: body)
    }
    
    // MARK: - Block Endpoints
    
    /// Get block children
    func getBlockChildren(
        blockId: String,
        token: String,
        startCursor: String? = nil,
        pageSize: Int? = nil
    ) async throws -> NotionListResponse<NotionBlock> {
        var endpoint = "/blocks/\(blockId)/children"
        
        var queryItems: [String] = []
        if let cursor = startCursor {
            queryItems.append("start_cursor=\(cursor)")
        }
        if let size = pageSize {
            queryItems.append("page_size=\(size)")
        }
        
        if !queryItems.isEmpty {
            endpoint += "?" + queryItems.joined(separator: "&")
        }
        
        return try await makeRequest(endpoint: endpoint, method: .GET, token: token)
    }
    
    /// Append block children
    func appendBlockChildren(
        blockId: String,
        children: [[String: Any]],
        token: String
    ) async throws -> NotionListResponse<NotionBlock> {
        let endpoint = "/blocks/\(blockId)/children"
        
        let body: [String: Any] = [
            "children": children
        ]
        
        return try await makeRequest(endpoint: endpoint, method: .PATCH, token: token, body: body)
    }
    
    /// Update a block
    func updateBlock(
        blockId: String,
        content: [String: Any],
        token: String
    ) async throws -> NotionBlock {
        let endpoint = "/blocks/\(blockId)"
        return try await makeRequest(endpoint: endpoint, method: .PATCH, token: token, body: content)
    }
    
    /// Delete a block
    func deleteBlock(blockId: String, token: String) async throws -> NotionBlock {
        let endpoint = "/blocks/\(blockId)"
        return try await makeRequest(endpoint: endpoint, method: .DELETE, token: token)
    }
    
    // MARK: - Search
    
    /// Search across the workspace
    func search(
        query: String? = nil,
        filter: [String: Any]? = nil,
        sort: [String: Any]? = nil,
        startCursor: String? = nil,
        pageSize: Int? = nil,
        token: String
    ) async throws -> SearchResponse {
        let endpoint = "/search"
        
        var body: [String: Any] = [:]
        if let query = query { body["query"] = query }
        if let filter = filter { body["filter"] = filter }
        if let sort = sort { body["sort"] = sort }
        if let cursor = startCursor { body["start_cursor"] = cursor }
        if let size = pageSize { body["page_size"] = size }
        
        return try await makeRequest(endpoint: endpoint, method: .POST, token: token, body: body)
    }
    
    // MARK: - Helper Methods
    
    /// Make HTTP request to Notion API
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        token: String,
        body: [String: Any]? = nil
    ) async throws -> T {
        // Apply rate limiting
        await rateLimiter.waitIfNeeded()
        
        // Check cache for GET requests
        if method == .GET {
            let cacheKey = "\(endpoint)_\(token.suffix(8))"
            if let cached = responseCache[cacheKey],
               Date().timeIntervalSince(cached.timestamp) < cacheExpirationTime {
                if let data = cached.data as? T {
                    return data
                }
            }
        }
        
        // Construct URL
        guard let url = URL(string: baseURL + endpoint) else {
            throw URLError(.badURL)
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add body for non-GET requests
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        // Perform request
        let (data, response) = try await session.data(for: request)
        
        // Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode >= 400 {
            // Try to decode error response
            if let errorResponse = try? decoder.decode(NotionError.self, from: data) {
                throw errorResponse
            } else {
                throw URLError(.badServerResponse)
            }
        }
        
        // Decode response
        let result = try decoder.decode(T.self, from: data)
        
        // Cache successful GET responses
        if method == .GET {
            let cacheKey = "\(endpoint)_\(token.suffix(8))"
            responseCache[cacheKey] = CachedResponse(data: result, timestamp: Date())
        }
        
        return result
    }
}

// MARK: - Supporting Types

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PATCH = "PATCH"
    case DELETE = "DELETE"
}

struct CachedResponse {
    let data: Any
    let timestamp: Date
}

struct SearchResponse: Codable {
    let results: [SearchResult]
    let nextCursor: String?
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

enum SearchResult: Codable {
    case page(NotionPage)
    case database(NotionDatabase)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let object = try container.decode(String.self, forKey: .object)
        
        switch object {
        case "page":
            let page = try NotionPage(from: decoder)
            self = .page(page)
        case "database":
            let database = try NotionDatabase(from: decoder)
            self = .database(database)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown object type: \(object)")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .page(let page):
            try page.encode(to: encoder)
        case .database(let database):
            try database.encode(to: encoder)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case object
    }
}

// MARK: - Rate Limiter

actor RateLimiter {
    private let maxRequests: Int
    private let timeWindow: TimeInterval
    private var requests: [Date] = []
    
    init(maxRequests: Int, timeWindow: TimeInterval) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
    }
    
    func waitIfNeeded() async {
        let now = Date()
        
        // Remove old requests outside the time window
        requests = requests.filter { now.timeIntervalSince($0) < timeWindow }
        
        // If we're at the limit, wait until we can make another request
        if requests.count >= maxRequests {
            let oldestRequest = requests.first!
            let waitTime = timeWindow - now.timeIntervalSince(oldestRequest)
            if waitTime > 0 {
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        
        // Add this request to the list
        requests.append(now)
    }
}