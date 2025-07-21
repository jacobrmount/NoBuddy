import Foundation

// MARK: - NotionAPIClient Usage Examples

/// Examples demonstrating how to use the enhanced NotionAPIClient
class NotionAPIClientExamples {
    
    let client: NotionAPIClient
    
    init(token: String) {
        self.client = NotionAPIClient(token: token)
    }
    
    // MARK: - Search Examples
    
    /// Search for pages and databases containing "Project Tasks"
    func searchExample() async throws {
        print("🔍 Searching for 'Project Tasks'...")
        
let searchResults = try await client.search(
    query: "Project Tasks",
    filter: nil as SearchFilter?,  // Search both pages and databases
    sort: SearchSort(direction: .descending),
    pageSize: 20
)
        
        print("Found \(searchResults.results.count) results")
        for result in searchResults.results {
            print("- \(result.object): \(result.id)")
        }
        
        // Handle pagination
        if searchResults.hasMore {
            print("More results available, fetching next page...")
            let nextPage = try await client.search(
                query: "Project Tasks",
                startCursor: searchResults.nextCursor,
                pageSize: 20
            )
            print("Found \(nextPage.results.count) more results")
        }
    }
    
    /// Search only for databases
    func searchDatabasesExample() async throws {
        print("🗄️ Searching for databases...")
        
        let databases = try await client.search(
            filter: SearchFilter(value: .database),
            sort: SearchSort(direction: .descending),
            pageSize: 100
        )
        
        print("Found \(databases.results.count) databases")
    }
    
    /// Search all results with automatic pagination
    func searchAllExample() async throws {
        print("🔍 Searching all pages with 'Meeting'...")
        
        let allResults = try await client.searchAll(
            query: "Meeting",
            filter: SearchFilter(value: .page)
        )
        
        print("Found total of \(allResults.count) pages")
    }
    
    // MARK: - Database Query Examples
    
    /// Query a database with filters
    func queryDatabaseExample(databaseId: String) async throws {
        print("📊 Querying database...")
        
        // Create filters
        let statusFilter = DatabaseFilter(
            property: "Status",
            condition: .selectEquals("In Progress")
        )
        
        let priorityFilter = DatabaseFilter(
            property: "Priority",
            condition: .multiSelectContains("High")
        )
        
        // Combine filters with AND
        let combinedFilter = DatabaseFilter(
            property: "",
            condition: .and([statusFilter, priorityFilter])
        )
        
        // Create sort
        let sort = DatabaseSort(
            property: "Due Date",
            timestamp: nil,
            direction: .ascending
        )
        
        // Query the database
        let pages = try await client.queryDatabase(
            databaseId: databaseId,
            filter: combinedFilter,
            sorts: [sort],
            pageSize: 50
        )
        
        print("Found \(pages.results.count) pages matching criteria")
        for page in pages.results {
            if let titleProp = page.properties["Name"],
               case .title(let titleArray) = titleProp,
               let title = titleArray.first?.plainText {
                print("- \(title)")
            }
        }
    }
    
    /// Query database with date filters
    func queryDatabaseWithDateFilter(databaseId: String) async throws {
        print("📅 Querying tasks due this week...")
        
        let dueDateFilter = DatabaseFilter(
            property: "Due Date",
            condition: .dateNextWeek
        )
        
        let notCompletedFilter = DatabaseFilter(
            property: "Completed",
            condition: .checkboxEquals(false)
        )
        
        let combinedFilter = DatabaseFilter(
            property: "",
            condition: .and([dueDateFilter, notCompletedFilter])
        )
        
        let results = try await client.queryDatabase(
            databaseId: databaseId,
            filter: combinedFilter,
            sorts: [
                DatabaseSort(
                    property: "Due Date",
                    timestamp: nil,
                    direction: .ascending
                )
            ]
        )
        
        print("Found \(results.results.count) incomplete tasks due next week")
    }
    
    /// Query all pages from a database
    func queryAllPagesExample(databaseId: String) async throws {
        print("📊 Fetching all pages from database...")
        
        let allPages = try await client.queryDatabaseAll(
            databaseId: databaseId,
            sorts: [
DatabaseSort(
    property: "SomeProperty", // Specify an appropriate property or remove
    timestamp: .lastEditedTime,
    direction: .descending
)
            ]
        )
        
        print("Retrieved total of \(allPages.count) pages")
    }
    
    // MARK: - Page Creation Examples
    
    /// Create a new page in a database
    func createPageInDatabase(databaseId: String) async throws {
        print("📝 Creating new page in database...")
        
        // Prepare properties
        let properties: [String: PropertyValue] = [
            "Name": .title("New Task from API"),
            "Status": .select(SelectOption(id: nil, name: "To Do", color: nil)),
            "Priority": .multiSelect([
                SelectOption(id: nil, name: "High", color: nil)
            ]),
            "Due Date": .date(DateValue(
                start: "2024-12-25",
                end: nil,
                timeZone: nil
            )),
            "Assignee": .people([]),
            "Completed": .checkbox(false),
            "Notes": .text("Created via NoBuddy API")
        ]
        
        // Create page content
        let content: [Block] = [
            .heading1(HeadingBlock(
                richText: [.text("Task Details")],
                color: nil,
                isToggleable: false
            )),
            .paragraph(ParagraphBlock(
                richText: [.text("This task was created using the Notion API.")],
                color: nil
            )),
            .todo(TodoBlock(
                richText: [.text("Complete initial setup")],
                checked: false,
                color: nil
            )),
            .todo(TodoBlock(
                richText: [.text("Review requirements")],
                checked: false,
                color: nil
            )),
            .divider,
            .callout(CalloutBlock(
                richText: [.text("Remember to update the status when complete!")],
                icon: .emoji("💡"),
                color: "yellow_background"
            ))
        ]
        
        let newPage = try await client.createPage(
            parent: .database(databaseId),
            properties: properties,
            children: content,
            icon: .emoji("✅"),
            cover: nil
        )
        
        print("✅ Created page: \(newPage.id)")
        print("Page URL: \(newPage.url)")
    }
    
    /// Create a subpage under another page
    func createSubpage(parentPageId: String) async throws {
        print("📄 Creating subpage...")
        
        let properties: [String: PropertyValue] = [
            "title": .title("Meeting Notes - \(Date())")
        ]
        
        let content: [Block] = [
            .heading2(HeadingBlock(
                richText: [.text("Attendees")],
                color: nil,
                isToggleable: false
            )),
            .bulletedListItem(ListItemBlock(
                richText: [.text("John Doe")],
                color: nil
            )),
            .bulletedListItem(ListItemBlock(
                richText: [.text("Jane Smith")],
                color: nil
            )),
            .heading2(HeadingBlock(
                richText: [.text("Agenda")],
                color: nil,
                isToggleable: false
            )),
            .numberedListItem(ListItemBlock(
                richText: [.text("Project status update")],
                color: nil
            )),
            .numberedListItem(ListItemBlock(
                richText: [.text("Budget review")],
                color: nil
            )),
            .numberedListItem(ListItemBlock(
                richText: [.text("Next steps")],
                color: nil
            ))
        ]
        
        let subpage = try await client.createPage(
            parent: .page(parentPageId),
            properties: properties,
            children: content,
            icon: .emoji("📝")
        )
        
        print("✅ Created subpage: \(subpage.id)")
    }
    
    // MARK: - Page Update Examples
    
    /// Update page properties
    func updatePageProperties(pageId: String) async throws {
        print("✏️ Updating page properties...")
        
        let updatedProperties: [String: PropertyValue] = [
            "Status": .select(SelectOption(id: nil, name: "Completed", color: nil)),
            "Completed": .checkbox(true),
            "Completion Date": .date(DateValue(
                start: ISO8601DateFormatter().string(from: Date()),
                end: nil,
                timeZone: nil
            )),
            "Notes": .text("Task completed successfully!")
        ]
        
        let updatedPage = try await client.updatePage(
            pageId: pageId,
            properties: updatedProperties
        )
        
        print("✅ Page updated successfully")
        print("Last edited: \(updatedPage.lastEditedTime)")
    }
    
    /// Archive a page
    func archivePage(pageId: String) async throws {
        print("🗄️ Archiving page...")
        
        let archivedPage = try await client.updatePage(
            pageId: pageId,
            archived: true
        )
        
        print("✅ Page archived: \(archivedPage.archived)")
    }
    
    /// Update page icon and cover
    func updatePageAppearance(pageId: String) async throws {
        print("🎨 Updating page appearance...")
        
_ = try await client.updatePage(
    pageId: pageId,
    icon: .emoji("🚀"),
    cover: .external("https://images.unsplash.com/photo-1512917774080-9991f1c4c750")
)
        
        print("✅ Page appearance updated")
    }
    
    // MARK: - Complex Examples
    
    /// Complete workflow example
    func completeWorkflowExample(databaseId: String) async throws {
        print("🔄 Running complete workflow...")
        
        // 1. Search for existing tasks
        let searchResults = try await client.search(
            query: "API Test",
            filter: SearchFilter(value: .page)
        )
        
        print("Found \(searchResults.results.count) existing test pages")
        
        // 2. Query database for incomplete tasks
        let incompleteTasks = try await client.queryDatabase(
            databaseId: databaseId,
            filter: DatabaseFilter(
                property: "Completed",
                condition: .checkboxEquals(false)
            )
        )
        
        print("Found \(incompleteTasks.results.count) incomplete tasks")
        
        // 3. Create a new task
        let newTaskProperties: [String: PropertyValue] = [
            "Name": .title("API Workflow Test - \(Date())"),
            "Status": .select(SelectOption(id: nil, name: "In Progress", color: nil)),
            "Completed": .checkbox(false)
        ]
        
        let newTask = try await client.createPage(
            parent: .database(databaseId),
            properties: newTaskProperties,
            icon: .emoji("🔄")
        )
        
        print("Created new task: \(newTask.id)")
        
        // 4. Simulate work and update the task
        try await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
        
_ = try await client.updatePage(
    pageId: newTask.id,
    properties: [
        "Status": .select(SelectOption(id: nil, name: "Completed", color: nil)),
        "Completed": .checkbox(true)
    ]
)
        
        print("✅ Workflow completed successfully!")
    }
    
    // MARK: - Error Handling Example
    
    /// Demonstrate error handling
    func errorHandlingExample() async {
        print("⚠️ Demonstrating error handling...")
        
        do {
            // Try to query a non-existent database
            let _ = try await client.queryDatabase(
                databaseId: "invalid-database-id"
            )
        } catch let error as NotionAPIError {
            print("Notion API Error:")
            print("- Status: \(error.status)")
            print("- Code: \(error.code)")
            print("- Message: \(error.message)")
        } catch {
            print("Unexpected error: \(error)")
        }
    }
}

// MARK: - Usage

/*
 To use these examples:
 
 let examples = NotionAPIClientExamples(token: "your-notion-token")
 
 // Search example
 try await examples.searchExample()
 
 // Query database
 try await examples.queryDatabaseExample(databaseId: "your-database-id")
 
 // Create a page
 try await examples.createPageInDatabase(databaseId: "your-database-id")
 
 // Update a page
 try await examples.updatePageProperties(pageId: "your-page-id")
 
 // Complete workflow
 try await examples.completeWorkflowExample(databaseId: "your-database-id")
 */
