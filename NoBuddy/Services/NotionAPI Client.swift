import Foundation

// MARK: - Token Error Types
enum TokenError: LocalizedError, Equatable {
    case invalidFormat
    case duplicateToken
    case tokenNotFound
    case loadFailed(Error)
    case saveFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case deleteAllFailed(Error)
    case validationFailed(Error)
    case networkError(Error)
    case connectionLost
    case connectionInvalidated
    case keychainError(KeychainError)
    case migrationFailed(Error)
    case unauthorized
    case timeout
    case widgetTimeoutExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid token format. Please check that you've entered a valid Notion integration token."
        case .duplicateToken:
            return "This token has already been added to your account."
        case .tokenNotFound:
            return "The requested token could not be found."
        case .loadFailed(let error):
            return "Failed to load saved tokens: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save token: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update token: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete token: \(error.localizedDescription)"
        case .deleteAllFailed(let error):
            return "Failed to delete all tokens: \(error.localizedDescription)"
        case .validationFailed(let error):
            return "Token validation failed: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .connectionLost:
            return "Connection lost. Please check your internet connection."
        case .connectionInvalidated:
            return "Connection was invalidated. This can happen due to network timeouts, authentication issues, or app extension limits. Please try again."
        case .keychainError(let keychainError):
            return "Keychain error: \(keychainError.localizedDescription)"
        case .migrationFailed(let error):
            return "Failed to migrate tokens to secure storage: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized. The token is invalid or has been revoked."
        case .timeout:
            return "Request timed out. Please try again."
        case .widgetTimeoutExceeded:
            return "Widget timeout exceeded. Please try again from the main app."
        }
    }
    
    static func == (lhs: TokenError, rhs: TokenError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidFormat, .invalidFormat),
             (.duplicateToken, .duplicateToken),
             (.tokenNotFound, .tokenNotFound),
             (.connectionLost, .connectionLost),
             (.connectionInvalidated, .connectionInvalidated),
             (.unauthorized, .unauthorized),
             (.timeout, .timeout),
             (.widgetTimeoutExceeded, .widgetTimeoutExceeded):
            return true
        case (.loadFailed(let lhsError), .loadFailed(let rhsError)),
             (.saveFailed(let lhsError), .saveFailed(let rhsError)),
             (.updateFailed(let lhsError), .updateFailed(let rhsError)),
             (.deleteFailed(let lhsError), .deleteFailed(let rhsError)),
             (.deleteAllFailed(let lhsError), .deleteAllFailed(let rhsError)),
             (.validationFailed(let lhsError), .validationFailed(let rhsError)),
             (.networkError(let lhsError), .networkError(let rhsError)),
             (.migrationFailed(let lhsError), .migrationFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.keychainError(let lhsError), .keychainError(let rhsError)):
            // Compare KeychainError by their localized description since they don't conform to Equatable
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
    let jitter = Double.random(in: 0...0.5)
    let baseDelay = pow(2.0, Double(attempt))
    return baseDelay + jitter
}

extension URLError {
    var toTokenError: TokenError {
        switch self.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .connectionLost
        case .timedOut:
            return .timeout
        case .cannotFindHost, .cannotConnectToHost:
            return .connectionLost
        case .secureConnectionFailed, .serverCertificateUntrusted:
            return .connectionLost
        default:
            return .connectionLost
        }
    }
}

extension TokenError {
    static func fromURLError(_ error: URLError) -> TokenError {
        return error.toTokenError
    }
}

/// Complete client for Notion API v1 with search, database, and page operations
class NotionAPIClient {
    
    // MARK: - Properties
    
    private let token: String
    private let baseURL = "https://api.notion.com/v1"
    private let session: URLSession
    private let rateLimiter: RateLimiter
    private let databaseCache = DatabaseCache()
    
    // MARK: - Initialization
    
    init(token: String, session: URLSession = .shared) {
        self.token = token
        // Configure URLSession with timeout and retry policies
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = URLSession(configuration: configuration)
        self.rateLimiter = RateLimiter(requestsPerSecond: 3) // Notion API limit
    }
    
    // MARK: - User Endpoints
    
    /// Get the current user (used for token validation)
    func getCurrentUser() async throws -> NotionUser {
        return try await makeRequest(endpoint: "/users/me", method: .GET)
    }
    
    /// Validate token and get comprehensive workspace information
    func validateTokenAndGetWorkspace() async throws -> WorkspaceInfo {
        print("[NotionAPI] 🔍 Starting comprehensive token validation and workspace discovery...")
        
        // Step 1: Validate token by getting current user
        let user: NotionUser
        do {
            user = try await getCurrentUser()
            print("[NotionAPI] ✅ Token validated successfully - User: \(user.name ?? "Unknown")")
        } catch {
            print("[NotionAPI] ❌ Token validation failed: \(error)")
            throw error
        }
        
        // Step 2: Try to get workspace content information
        var databaseCount: Int? = nil
        var pageCount: Int? = nil
        var workspaceError: String? = nil
        
        do {
            // Get database count
            print("[NotionAPI] 🔍 Searching for databases...")
            let databaseSearch = try await search(filter: SearchFilter(value: .database), pageSize: 100)
            databaseCount = databaseSearch.results.count
            print("[NotionAPI] ✅ Found \(databaseCount ?? 0) databases")
            
            // Get page count (first 100)
            print("[NotionAPI] 🔍 Searching for pages...")
            let pageSearch = try await search(filter: SearchFilter(value: .page), pageSize: 100)
            pageCount = pageSearch.results.count
            print("[NotionAPI] ✅ Found \(pageCount ?? 0) pages (first 100)")
            
        } catch {
            print("[NotionAPI] ⚠️ Workspace content search failed: \(error)")
            workspaceError = "Limited workspace access - \(error.localizedDescription)"
        }
        
        // Step 3: Create comprehensive workspace info
        let workspaceInfo = WorkspaceInfo(
            isValid: true,
            workspaceName: user.name ?? "Notion Workspace",
            workspaceIcon: user.avatarUrl,
            userEmail: user.email,
            userType: user.type?.rawValue ?? "person",
            databaseCount: databaseCount,
            pageCount: pageCount,
            error: workspaceError
        )
        
        print("[NotionAPI] ✅ Workspace validation completed")
        print("[NotionAPI] - Workspace: \(workspaceInfo.workspaceName ?? "Unknown")")
        print("[NotionAPI] - User: \(workspaceInfo.userEmail ?? "Unknown")")
        print("[NotionAPI] - Databases: \(workspaceInfo.databaseCount ?? 0)")
        print("[NotionAPI] - Pages: \(workspaceInfo.pageCount ?? 0)")
        
        return workspaceInfo
    }
    
    /// Quick token validation (just checks if token is valid)
    func validateTokenQuick() async throws -> Bool {
        do {
            let _ = try await getCurrentUser()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Search Endpoints
    
    /// Search for pages and databases with optional query
    /// - Parameters:
    ///   - query: Text query to search for
    ///   - filter: Filter by object type (page or database)
    ///   - sort: Sort order for results
    ///   - startCursor: Cursor for pagination
    ///   - pageSize: Number of results per page (max 100)
    /// - Returns: SearchResponse with results and pagination info
    func search(
        query: String? = nil,
        filter: SearchFilter? = nil,
        sort: SearchSort? = nil,
        startCursor: String? = nil,
        pageSize: Int = 10
    ) async throws -> SearchResponse {
        var body: [String: Any] = [:]
        
        if let query = query, !query.isEmpty {
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
        
        body["page_size"] = min(pageSize, 100)
        
        return try await makeRequestWithRetry(
            endpoint: "/search",
            method: .POST,
            body: body
        )
    }
    
    /// Search all pages and databases with pagination support
    func searchAll(
        query: String? = nil,
        filter: SearchFilter? = nil,
        sort: SearchSort? = nil,
        pageSize: Int = 100
    ) async throws -> [SearchResult] {
        var allResults: [SearchResult] = []
        var cursor: String? = nil
        var hasMore = true
        
        while hasMore {
            let response = try await search(
                query: query,
                filter: filter,
                sort: sort,
                startCursor: cursor,
                pageSize: pageSize
            )
            
            allResults.append(contentsOf: response.results)
            cursor = response.nextCursor
            hasMore = response.hasMore
        }
        
        return allResults
    }
    
    // MARK: - Database Endpoints
    
    /// Retrieve complete database details including all metadata fields
    /// - Parameter databaseId: The database ID to retrieve
    /// - Returns: Full NotionDatabase object with all fields from Notion's database object spec
    func retrieveDatabase(databaseId: String) async throws -> NotionDatabase {
        print("[NotionAPI] 🔍 Retrieving complete database details for ID: \(databaseId)")
        
        let endpoint = "/databases/\(databaseId)"
        
        do {
            let database: NotionDatabase = try await makeRequestWithRetry(
                endpoint: endpoint,
                method: .GET
            )
            
            print("[NotionAPI] ✅ Successfully retrieved database: \(database.displayTitle)")
            print("[NotionAPI] - ID: \(database.id)")
            print("[NotionAPI] - Properties count: \(database.properties?.count ?? 0)")
            print("[NotionAPI] - Created: \(database.createdTime ?? Date())")
            print("[NotionAPI] - Last edited: \(database.lastEditedTime ?? Date())")
            print("[NotionAPI] - URL: \(database.url ?? "N/A")")
            
            return database
        } catch let error as NotionAPIError {
            print("[NotionAPI] ❌ Failed to retrieve database: \(error.message)")
            throw error
        } catch {
            print("[NotionAPI] ❌ Unexpected error retrieving database: \(error)")
            throw NotionAPIError(
                object: "error",
                status: 500,
                code: "internal_error",
                message: "Failed to retrieve database: \(error.localizedDescription)"
            )
        }
    }
    
    /// Query a database with filters and sorts
    /// - Parameters:
    ///   - databaseId: The database ID to query
    ///   - filter: Filter conditions for the query
    ///   - sorts: Sort conditions for the results
    ///   - startCursor: Cursor for pagination
    ///   - pageSize: Number of results per page (max 100)
    /// - Returns: DatabaseQueryResponse with pages and pagination info
    func queryDatabase(
        databaseId: String,
        filter: DatabaseFilter? = nil,
        sorts: [DatabaseSort]? = nil,
        startCursor: String? = nil,
        pageSize: Int = 10
    ) async throws -> DatabaseQueryResponse {
        var body: [String: Any] = [:]
        
        if let filter = filter {
            body["filter"] = filter.toDictionary()
        }
        
        if let sorts = sorts, !sorts.isEmpty {
            body["sorts"] = sorts.map { $0.toDictionary() }
        }
        
        if let startCursor = startCursor {
            body["start_cursor"] = startCursor
        }
        
        body["page_size"] = min(pageSize, 100)
        
        return try await makeRequestWithRetry(
            endpoint: "/databases/\(databaseId)/query",
            method: .POST,
            body: body
        )
    }
    
    /// Query all pages from a database with pagination
    func queryDatabaseAll(
        databaseId: String,
        filter: DatabaseFilter? = nil,
        sorts: [DatabaseSort]? = nil,
        pageSize: Int = 100
    ) async throws -> [Page] {
        var allPages: [Page] = []
        var cursor: String? = nil
        var hasMore = true
        
        while hasMore {
            let response = try await queryDatabase(
                databaseId: databaseId,
                filter: filter,
                sorts: sorts,
                startCursor: cursor,
                pageSize: pageSize
            )
            
            allPages.append(contentsOf: response.results)
            cursor = response.nextCursor
            hasMore = response.hasMore
        }
        
        return allPages
    }
    
    /// Fetch databases for selection UI
    func searchDatabases() async throws -> [NotionDatabase] {
        print("[NotionAPI] 🔍 Searching for databases...")
        
        var body: [String: Any] = [:]
        body["filter"] = [
            "value": "database",
            "property": "object"
        ]
        body["page_size"] = 100
        
        let (data, response) = try await performRawRequest(endpoint: "/search", method: .POST, body: body)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionAPIError(object: "error", status: 500, code: "internal_server_error", message: "Invalid response")
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ API Error \(httpResponse.statusCode): \(errorString)")
            throw NotionAPIError(object: "error", status: httpResponse.statusCode, code: "api_error", message: "API request failed")
        }
        
        // Parse JSON manually to extract databases
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            throw NotionAPIError(object: "error", status: 422, code: "parse_error", message: "Failed to parse response")
        }
        
        var databases: [NotionDatabase] = []
        
        for result in results {
            if let objectType = result["object"] as? String, objectType == "database" {
                do {
                    let dbData = try JSONSerialization.data(withJSONObject: result)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let database = try decoder.decode(NotionDatabase.self, from: dbData)
                    databases.append(database)
                } catch {
                    print("⚠️ Failed to decode individual database: \(error)")
                    continue
                }
            }
        }
        
        print("🔍 Found \(databases.count) databases from API")
        return databases.sorted { $0.safeLastEditedTime > $1.safeLastEditedTime }
    }
    
    /// Fetch all accessible databases with caching support
    /// - Parameters:
    ///   - useCache: Whether to use cached data if available and not expired
    ///   - cacheExpirationInterval: How long cached data is considered valid (default: 5 minutes)
    /// - Returns: Array of DatabaseInfo structs with essential metadata
    func fetchDatabases(
        useCache: Bool = true,
        cacheExpirationInterval: TimeInterval = 300
    ) async throws -> [DatabaseInfo] {
        print("[NotionAPI] 🔍 Fetching databases with pagination support...")
        
        // Check cache first if enabled
        if useCache {
            let cached = databaseCache.retrieveAll()
            if !cached.isEmpty {
                let nonExpired = cached.filter { !$0.isCacheExpired(expirationInterval: cacheExpirationInterval) }
                if !nonExpired.isEmpty {
                    print("[NotionAPI] ✅ Returning \(nonExpired.count) cached databases")
                    return nonExpired.sorted { $0.lastEditedTime > $1.lastEditedTime }
                }
            }
        }
        
        var allDatabases: [DatabaseInfo] = []
        var cursor: String? = nil
        var hasMore = true
        var pageCount = 0
        
        while hasMore {
            pageCount += 1
            print("[NotionAPI] 📄 Fetching page \(pageCount) of databases...")
            
            // Prepare request body
            var body: [String: Any] = [:]
            body["filter"] = [
                "value": "database",
                "property": "object"
            ]
            body["page_size"] = 100
            
            if let cursor = cursor {
                body["start_cursor"] = cursor
            }
            
            // Make the request
            let (data, response) = try await performRawRequest(endpoint: "/search", method: .POST, body: body)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NotionAPIError(object: "error", status: 500, code: "internal_server_error", message: "Invalid response")
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("[NotionAPI] ❌ API Error \(httpResponse.statusCode): \(errorString)")
                throw NotionAPIError(object: "error", status: httpResponse.statusCode, code: "api_error", message: "API request failed")
            }
            
            // Parse JSON response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                throw NotionAPIError(object: "error", status: 422, code: "parse_error", message: "Failed to parse response")
            }
            
            // Extract pagination info
            hasMore = json["has_more"] as? Bool ?? false
            cursor = json["next_cursor"] as? String
            
            // Process each database result
            for result in results {
                if let objectType = result["object"] as? String, objectType == "database" {
                    // Extract essential info
                    guard let id = result["id"] as? String else { continue }
                    
                    // Extract title
                    var title = "Untitled Database"
                    if let titleArray = result["title"] as? [[String: Any]] {
                        for titleItem in titleArray {
                            if let plainText = titleItem["plain_text"] as? String, !plainText.isEmpty {
                                title = plainText
                                break
                            }
                        }
                    }
                    
                    // Extract icon emoji if present
                    var iconEmoji: String? = nil
                    if let icon = result["icon"] as? [String: Any],
                       let type = icon["type"] as? String,
                       type == "emoji",
                       let emoji = icon["emoji"] as? String {
                        iconEmoji = emoji
                    }
                    
                    // Extract properties and their types
                    var propertyTypes: [String: PropertyType] = [:]
                    if let properties = result["properties"] as? [String: [String: Any]] {
                        for (propName, propData) in properties {
                            if let typeString = propData["type"] as? String,
                               let propertyType = PropertyType(rawValue: typeString) {
                                propertyTypes[propName] = propertyType
                            }
                        }
                    }
                    
                    // Extract timestamps
                    let dateFormatter = ISO8601DateFormatter()
                    var lastEditedTime = Date()
                    var createdTime = Date()
                    
                    if let lastEditedString = result["last_edited_time"] as? String {
                        lastEditedTime = dateFormatter.date(from: lastEditedString) ?? Date()
                    }
                    
                    if let createdString = result["created_time"] as? String {
                        createdTime = dateFormatter.date(from: createdString) ?? Date()
                    }
                    
                    // Extract URL
                    let url = result["url"] as? String
                    
                    // Create DatabaseInfo
                    let databaseInfo = DatabaseInfo(
                        id: id,
                        title: title,
                        icon: iconEmoji,
                        properties: propertyTypes,
                        lastEditedTime: lastEditedTime,
                        createdTime: createdTime,
                        url: url,
                        cachedAt: Date()
                    )
                    
                    allDatabases.append(databaseInfo)
                }
            }
            
            print("[NotionAPI] ✅ Processed \(results.count) results from page \(pageCount)")
        }
        
        print("[NotionAPI] ✅ Found total of \(allDatabases.count) databases across \(pageCount) pages")
        
        // Cache the results
        if useCache && !allDatabases.isEmpty {
            databaseCache.store(allDatabases)
            print("[NotionAPI] 💾 Cached \(allDatabases.count) databases")
        }
        
        // Sort by last edited time (most recent first)
        return allDatabases.sorted { $0.lastEditedTime > $1.lastEditedTime }
    }
    
    // MARK: - Page Endpoints
    
    /// Create a new page
    /// - Parameters:
    ///   - parent: Parent object (database or page)
    ///   - properties: Page properties
    ///   - children: Page content blocks (optional)
    ///   - icon: Page icon (optional)
    ///   - cover: Page cover (optional)
    /// - Returns: The created Page object
    func createPage(
        parent: PageParent,
        properties: [String: PropertyValue],
        children: [Block]? = nil,
        icon: PageIcon? = nil,
        cover: PageCover? = nil
    ) async throws -> Page {
        var body: [String: Any] = [:]
        
        body["parent"] = parent.toDictionary()
        body["properties"] = properties.mapValues { $0.toDictionary() }
        
        if let children = children {
            body["children"] = children.map { $0.toDictionary() }
        }
        
        if let icon = icon {
            body["icon"] = icon.toDictionary()
        }
        
        if let cover = cover {
            body["cover"] = cover.toDictionary()
        }
        
        return try await makeRequestWithRetry(
            endpoint: "/pages",
            method: .POST,
            body: body
        )
    }
    
    /// Update page properties
    /// - Parameters:
    ///   - pageId: The page ID to update
    ///   - properties: Properties to update
    ///   - archived: Whether to archive/unarchive the page
    ///   - icon: Update page icon
    ///   - cover: Update page cover
    /// - Returns: The updated Page object
    func updatePage(
        pageId: String,
        properties: [String: PropertyValue]? = nil,
        archived: Bool? = nil,
        icon: PageIcon? = nil,
        cover: PageCover? = nil
    ) async throws -> Page {
        var body: [String: Any] = [:]
        
        if let properties = properties {
            body["properties"] = properties.mapValues { $0.toDictionary() }
        }
        
        if let archived = archived {
            body["archived"] = archived
        }
        
        if let icon = icon {
            body["icon"] = icon.toDictionary()
        }
        
        if let cover = cover {
            body["cover"] = cover.toDictionary()
        }
        
        return try await makeRequestWithRetry(
            endpoint: "/pages/\(pageId)",
            method: .PATCH,
            body: body
        )
    }
    
    /// Retrieve a page
    func getPage(pageId: String) async throws -> Page {
        return try await makeRequestWithRetry(
            endpoint: "/pages/\(pageId)",
            method: .GET
        )
    }
    
    // MARK: - Private Methods
    
    private enum HTTPMethod: String {
        case GET = "GET"
        case POST = "POST"
        case PATCH = "PATCH"
        case DELETE = "DELETE"
    }
    
    private func performRawRequest(
        endpoint: String,
        method: HTTPMethod,
        body: [String: Any]? = nil
    ) async throws -> (Data, URLResponse) {
        // Apply rate limiting
        await rateLimiter.waitForPermission()
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw NotionAPIError(object: "error", status: 400, code: "invalid_request", message: "Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        return try await session.data(for: request)
    }
    
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: [String: Any]? = nil
    ) async throws -> T {
        // Apply rate limiting
        await rateLimiter.waitForPermission()
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw NotionAPIError(object: "error", status: 400, code: "invalid_request", message: "Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionAPIError(object: "error", status: 500, code: "internal_server_error", message: "Invalid response")
        }
        
        // Handle non-success status codes
        guard 200...299 ~= httpResponse.statusCode else {
            if let errorData = try? JSONDecoder().decode(NotionAPIError.self, from: data) {
                throw errorData
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NotionAPIError(
                    object: "error",
                    status: httpResponse.statusCode,
                    code: "api_error",
                    message: errorMessage
                )
            }
        }
        
        // Decode the response
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("[NotionAPI] ❌ Decoding error: \(error)")
            print("[NotionAPI] Raw response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw NotionAPIError(
                object: "error",
                status: 422,
                code: "validation_error",
                message: "Failed to decode response: \(error.localizedDescription)"
            )
        }
    }
    
    /// Make request with automatic retry for rate limiting
private func shouldRetry(for error: Error) -> Bool {
    if let urlError = error as? URLError {
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
    return false
}

    private func makeRequestWithRetry<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: [String: Any]? = nil,
        maxRetries: Int = 3
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                return try await makeRequest(
                    endpoint: endpoint,
                    method: method,
                    body: body
                )
            } catch let error as NotionAPIError {
                lastError = error
                
                // If rate limited, wait and retry
                if error.status == 429 {
let jitter = Double.random(in: 0...0.5) // Add jitter
                    let baseDelay = pow(2.0, Double(attempt))
                    let waitTime = (baseDelay + jitter) * 1_000_000_000 // Convert to nanoseconds
                    print("[NotionAPI] Rate limited, waiting \(waitTime) seconds...")
                    try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                    continue
                }
                
                // For other errors, throw immediately
                throw error
            } catch {
                // For non-API errors, throw immediately
                throw error
            }
        }
        
        // If we've exhausted retries, throw the last error
        throw lastError ?? NotionAPIError(
            object: "error",
            status: 429,
            code: "rate_limited",
            message: "Rate limit exceeded after \(maxRetries) retries"
        )
    }
}

// MARK: - Helper Models

struct SearchFilter {
    let value: SearchFilterValue
    
    enum SearchFilterValue: String {
        case page = "page"
        case database = "database"
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "value": value.rawValue,
            "property": "object"
        ]
    }
}

struct SearchSort {
    let direction: SortDirection
    
    enum SortDirection: String {
        case ascending = "ascending"
        case descending = "descending"
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "timestamp": "last_edited_time",
            "direction": direction.rawValue
        ]
    }
}

// MARK: - Rate Limiter

actor RateLimiter {
    private let requestsPerSecond: Double
    private let interval: TimeInterval
    private var lastRequestTime: Date = Date(timeIntervalSince1970: 0)

    init(requestsPerSecond: Double) {
        self.requestsPerSecond = requestsPerSecond
        self.interval = 1.0 / requestsPerSecond
    }

    // Wait for permission based on rate limit
    func waitForPermission() async {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)

        if timeSinceLastRequest < interval {
            let waitTime = interval - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }

        lastRequestTime = Date()
    }
}
