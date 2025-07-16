import AppIntents
import Foundation

// MARK: - Create Notion Page Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct CreateNotionPageIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Notion Page"
    static var description = IntentDescription("Create a new page in your Notion workspace")
    
    @Parameter(title: "Title", description: "The title of the page")
    var title: String
    
    @Parameter(title: "Content", description: "The content of the page", default: "")
    var content: String
    
    @Parameter(title: "Database", description: "The database to add the page to")
    var database: DatabaseEntity?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Create a page titled \(\.$title)") {
            \.$content
            \.$database
        }
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Load tokens and validate
        guard let token = await getValidToken() else {
            throw IntentError.noValidToken
        }
        
        // Create the page
        do {
            let apiClient = NotionAPIClient()
            
            // Determine parent (database or workspace)
            let parent: NotionParent
            if let databaseId = database?.id {
                parent = NotionParent(
                    type: .database_id,
                    pageId: nil,
                    databaseId: databaseId,
                    workspaceId: nil
                )
            } else {
                parent = NotionParent(
                    type: .workspace,
                    pageId: nil,
                    databaseId: nil,
                    workspaceId: nil
                )
            }
            
            // Create basic properties for the page
            var properties: [String: PageProperty] = [:]
            
            // If it's a database page, we need to handle title differently
            if database != nil {
                // For database pages, title goes in properties
                let titleRichText = [RichText(
                    type: .text,
                    text: TextContent(content: title, link: nil),
                    mention: nil,
                    equation: nil,
                    annotations: Annotations(
                        bold: false,
                        italic: false,
                        strikethrough: false,
                        underline: false,
                        code: false,
                        color: "default"
                    ),
                    plainText: title,
                    href: nil
                )]
                properties["Name"] = .title(titleRichText)
            }
            
            // Create content blocks if provided
            var children: [NotionBlock]? = nil
            if !content.isEmpty {
                // Create a simple paragraph block
                let textContent = [RichText(
                    type: .text,
                    text: TextContent(content: content, link: nil),
                    mention: nil,
                    equation: nil,
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
                )]
                
                let paragraphBlock = NotionBlock(
                    id: "",
                    object: "block",
                    createdTime: Date(),
                    lastEditedTime: Date(),
                    createdBy: NotionUser(
                        id: "",
                        object: "user",
                        type: .bot,
                        name: "NoBuddy",
                        avatarUrl: nil,
                        createdTime: Date(),
                        lastEditedTime: Date()
                    ),
                    lastEditedBy: NotionUser(
                        id: "",
                        object: "user",
                        type: .bot,
                        name: "NoBuddy",
                        avatarUrl: nil,
                        createdTime: Date(),
                        lastEditedTime: Date()
                    ),
                    hasChildren: false,
                    archived: false,
                    type: "paragraph",
                    content: .paragraph(textContent)
                )
                
                children = [paragraphBlock]
            }
            
            let page = try await apiClient.createPage(
                parent: parent,
                properties: properties,
                children: children,
                token: token.token
            )
            
            return .result(dialog: "Successfully created page '\(title)' in Notion")
            
        } catch {
            throw IntentError.creationFailed(error.localizedDescription)
        }
    }
}

// MARK: - Query Notion Database Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct QueryNotionDatabaseIntent: AppIntent {
    static var title: LocalizedStringResource = "Query Notion Database"
    static var description = IntentDescription("Query a Notion database and get results")
    
    @Parameter(title: "Database", description: "The database to query")
    var database: DatabaseEntity
    
    @Parameter(title: "Query", description: "Search term to filter results", default: "")
    var query: String
    
    @Parameter(title: "Limit", description: "Maximum number of results", default: 10)
    var limit: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Query \(\.$database) for \(\.$query)") {
            \.$limit
        }
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<[PageEntity]> {
        guard let token = await getValidToken() else {
            throw IntentError.noValidToken
        }
        
        do {
            let apiClient = NotionAPIClient()
            
            // Create filter if query is provided
            var filter: DatabaseFilter? = nil
            if !query.isEmpty {
                filter = DatabaseFilter(
                    property: "Name",
                    condition: .contains(query)
                )
            }
            
            let response = try await apiClient.queryDatabase(
                id: database.id,
                token: token.token,
                filter: filter,
                pageSize: min(limit, 100)
            )
            
            let pageEntities = response.results.map { page in
                PageEntity(
                    id: page.id,
                    title: extractPageTitle(from: page),
                    url: page.url
                )
            }
            
            let resultCount = pageEntities.count
            let dialogText = resultCount > 0 
                ? "Found \(resultCount) page(s) in \(database.title)"
                : "No pages found in \(database.title)"
            
            return .result(
                value: pageEntities,
                dialog: dialogText
            )
            
        } catch {
            throw IntentError.queryFailed(error.localizedDescription)
        }
    }
}

// MARK: - Add Database Entry Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct AddDatabaseEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Add to Notion Database"
    static var description = IntentDescription("Add a new entry to a Notion database")
    
    @Parameter(title: "Database", description: "The database to add to")
    var database: DatabaseEntity
    
    @Parameter(title: "Title", description: "The title of the entry")
    var title: String
    
    @Parameter(title: "Properties", description: "Additional properties as key-value pairs", default: "")
    var properties: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$title) to \(\.$database)") {
            \.$properties
        }
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let token = await getValidToken() else {
            throw IntentError.noValidToken
        }
        
        do {
            let apiClient = NotionAPIClient()
            
            let parent = NotionParent(
                type: .database_id,
                pageId: nil,
                databaseId: database.id,
                workspaceId: nil
            )
            
            // Create title property
            let titleRichText = [RichText(
                type: .text,
                text: TextContent(content: title, link: nil),
                mention: nil,
                equation: nil,
                annotations: Annotations(
                    bold: false,
                    italic: false,
                    strikethrough: false,
                    underline: false,
                    code: false,
                    color: "default"
                ),
                plainText: title,
                href: nil
            )]
            
            var pageProperties: [String: PageProperty] = [
                "Name": .title(titleRichText)
            ]
            
            // Parse additional properties if provided
            if !properties.isEmpty {
                let additionalProperties = parseProperties(properties)
                for (key, value) in additionalProperties {
                    // Add as rich text property for simplicity
                    let richText = [RichText(
                        type: .text,
                        text: TextContent(content: value, link: nil),
                        mention: nil,
                        equation: nil,
                        annotations: Annotations(
                            bold: false,
                            italic: false,
                            strikethrough: false,
                            underline: false,
                            code: false,
                            color: "default"
                        ),
                        plainText: value,
                        href: nil
                    )]
                    pageProperties[key] = .richText(richText)
                }
            }
            
            let page = try await apiClient.createPage(
                parent: parent,
                properties: pageProperties,
                token: token.token
            )
            
            return .result(dialog: "Successfully added '\(title)' to \(database.title)")
            
        } catch {
            throw IntentError.creationFailed(error.localizedDescription)
        }
    }
}

// MARK: - Search Notion Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct SearchNotionIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Notion"
    static var description = IntentDescription("Search across all your Notion pages and databases")
    
    @Parameter(title: "Query", description: "What to search for")
    var query: String
    
    @Parameter(title: "Limit", description: "Maximum number of results", default: 10)
    var limit: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Search Notion for \(\.$query)") {
            \.$limit
        }
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<[SearchResultEntity]> {
        guard let token = await getValidToken() else {
            throw IntentError.noValidToken
        }
        
        do {
            let apiClient = NotionAPIClient()
            
            let response = try await apiClient.search(
                query: query,
                pageSize: min(limit, 100),
                token: token.token
            )
            
            let searchResults = response.results.map { result in
                switch result {
                case .page(let page):
                    return SearchResultEntity(
                        id: page.id,
                        title: extractPageTitle(from: page),
                        type: "page",
                        url: page.url
                    )
                case .database(let database):
                    return SearchResultEntity(
                        id: database.id,
                        title: database.title.first?.plainText ?? "Untitled Database",
                        type: "database",
                        url: database.url
                    )
                }
            }
            
            let resultCount = searchResults.count
            let dialogText = resultCount > 0 
                ? "Found \(resultCount) result(s) for '\(query)'"
                : "No results found for '\(query)'"
            
            return .result(
                value: searchResults,
                dialog: dialogText
            )
            
        } catch {
            throw IntentError.searchFailed(error.localizedDescription)
        }
    }
}

// MARK: - Update Notion Page Intent

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct UpdateNotionPageIntent: AppIntent {
    static var title: LocalizedStringResource = "Update Notion Page"
    static var description = IntentDescription("Update an existing Notion page")
    
    @Parameter(title: "Page", description: "The page to update")
    var page: PageEntity
    
    @Parameter(title: "New Title", description: "New title for the page", default: "")
    var newTitle: String
    
    @Parameter(title: "Archive", description: "Archive the page", default: false)
    var archive: Bool
    
    static var parameterSummary: some ParameterSummary {
        Summary("Update \(\.$page)") {
            \.$newTitle
            \.$archive
        }
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let token = await getValidToken() else {
            throw IntentError.noValidToken
        }
        
        do {
            let apiClient = NotionAPIClient()
            
            var properties: [String: PageProperty]? = nil
            if !newTitle.isEmpty {
                let titleRichText = [RichText(
                    type: .text,
                    text: TextContent(content: newTitle, link: nil),
                    mention: nil,
                    equation: nil,
                    annotations: Annotations(
                        bold: false,
                        italic: false,
                        strikethrough: false,
                        underline: false,
                        code: false,
                        color: "default"
                    ),
                    plainText: newTitle,
                    href: nil
                )]
                properties = ["Name": .title(titleRichText)]
            }
            
            let updatedPage = try await apiClient.updatePage(
                id: page.id,
                properties: properties,
                archived: archive ? true : nil,
                token: token.token
            )
            
            let action = archive ? "archived" : "updated"
            return .result(dialog: "Successfully \(action) page '\(page.title)'")
            
        } catch {
            throw IntentError.updateFailed(error.localizedDescription)
        }
    }
}

// MARK: - Entity Definitions

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct DatabaseEntity: AppEntity {
    let id: String
    let title: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Database"
    static var defaultQuery = DatabaseEntityQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct DatabaseEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DatabaseEntity] {
        guard let token = await getValidToken() else { return [] }
        
        // In a real implementation, fetch specific databases by ID
        return identifiers.compactMap { id in
            DatabaseEntity(id: id, title: "Database \(id)")
        }
    }
    
    func suggestedEntities() async throws -> [DatabaseEntity] {
        guard let token = await getValidToken() else { return [] }
        
        // In a real implementation, fetch user's databases
        // For now, return placeholder data
        return [
            DatabaseEntity(id: "sample1", title: "Tasks"),
            DatabaseEntity(id: "sample2", title: "Notes"),
            DatabaseEntity(id: "sample3", title: "Projects")
        ]
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct PageEntity: AppEntity {
    let id: String
    let title: String
    let url: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Page"
    static var defaultQuery = PageEntityQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct PageEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PageEntity] {
        guard let token = await getValidToken() else { return [] }
        
        // In a real implementation, fetch specific pages by ID
        return identifiers.compactMap { id in
            PageEntity(id: id, title: "Page \(id)", url: "https://notion.so/\(id)")
        }
    }
    
    func suggestedEntities() async throws -> [PageEntity] {
        guard let token = await getValidToken() else { return [] }
        
        // In a real implementation, fetch recent pages
        return [
            PageEntity(id: "page1", title: "Meeting Notes", url: "https://notion.so/page1"),
            PageEntity(id: "page2", title: "Project Plan", url: "https://notion.so/page2"),
            PageEntity(id: "page3", title: "Weekly Review", url: "https://notion.so/page3")
        ]
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct SearchResultEntity: AppEntity {
    let id: String
    let title: String
    let type: String
    let url: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Search Result"
    static var defaultQuery = SearchResultEntityQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(type.capitalized)"
        )
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct SearchResultEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SearchResultEntity] {
        return []
    }
    
    func suggestedEntities() async throws -> [SearchResultEntity] {
        return []
    }
}

// MARK: - Intent Errors

enum IntentError: Error, LocalizedError {
    case noValidToken
    case creationFailed(String)
    case queryFailed(String)
    case searchFailed(String)
    case updateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noValidToken:
            return "No valid Notion token found. Please configure a token in the NoBuddy app."
        case .creationFailed(let message):
            return "Failed to create page: \(message)"
        case .queryFailed(let message):
            return "Failed to query database: \(message)"
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .updateFailed(let message):
            return "Failed to update page: \(message)"
        }
    }
}

// MARK: - App Shortcuts Provider

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct NoBuddyShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNotionPageIntent(),
            phrases: [
                "Create a page in \(.applicationName)",
                "Create a new \(.applicationName) page",
                "Add a page to Notion with \(.applicationName)"
            ],
            shortTitle: "Create Page",
            systemImageName: "doc.badge.plus"
        )
        
        AppShortcut(
            intent: SearchNotionIntent(),
            phrases: [
                "Search Notion with \(.applicationName)",
                "Find in \(.applicationName)",
                "Search for \(\.$query) in Notion"
            ],
            shortTitle: "Search Notion",
            systemImageName: "magnifyingglass"
        )
        
        AppShortcut(
            intent: AddDatabaseEntryIntent(),
            phrases: [
                "Add to database with \(.applicationName)",
                "Create database entry in \(.applicationName)"
            ],
            shortTitle: "Add to Database",
            systemImageName: "tablecells.badge.ellipsis"
        )
    }
}

// MARK: - Helper Functions

@MainActor
private func getValidToken() async -> NotionToken? {
    // In a real implementation, this would load from the shared container
    // For now, return nil
    return nil
}

private func extractPageTitle(from page: NotionPage) -> String {
    // Extract title from page properties
    for (_, property) in page.properties {
        if case .title(let richTexts) = property {
            return richTexts.first?.plainText ?? "Untitled"
        }
    }
    return "Untitled"
}

private func parseProperties(_ propertiesString: String) -> [String: String] {
    var result: [String: String] = [:]
    
    // Simple parsing of "key1:value1,key2:value2" format
    let pairs = propertiesString.components(separatedBy: ",")
    for pair in pairs {
        let components = pair.components(separatedBy: ":")
        if components.count == 2 {
            let key = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            result[key] = value
        }
    }
    
    return result
}