# Retrieve Database API Example

This demonstrates how to use the new `retrieveDatabase(databaseId:)` method to get complete database details from the Notion API.

## Usage

```swift
import Foundation

// Initialize the Notion API client
let client = NotionAPIClient(token: "your_notion_integration_token")

// Example: Retrieve a specific database
Task {
    do {
        let database = try await client.retrieveDatabase(databaseId: "your_database_id")
        
        // Access all the comprehensive database information
        print("Database Title: \(database.displayTitle)")
        print("Description: \(database.displayDescription ?? "No description")")
        print("Created: \(database.safeCreatedTime)")
        print("Last Edited: \(database.safeLastEditedTime)")
        print("URL: \(database.url ?? "No URL")")
        print("Archived: \(database.archived ?? false)")
        print("In Trash: \(database.inTrash ?? false)")
        print("Is Inline: \(database.isInline ?? false)")
        
        // Access icon information
        if let icon = database.icon {
            print("Icon Type: \(icon.type)")
            print("Icon Display: \(icon.displayIcon)")
            if let iconUrl = icon.iconUrl {
                print("Icon URL: \(iconUrl)")
            }
        }
        
        // Access cover information
        if let cover = database.cover {
            print("Cover Type: \(cover.type)")
            if let coverUrl = cover.coverUrl {
                print("Cover URL: \(coverUrl)")
            }
        }
        
        // Access properties schema
        if let properties = database.properties {
            print("\nProperties Schema:")
            for (name, property) in properties {
                print("- \(name): \(property.type)")
                if let description = property.description {
                    print("  Description: \(description)")
                }
            }
        }
        
        // Access parent information
        if let parent = database.parent {
            print("\nParent Type: \(parent.type)")
            if let pageId = parent.pageId {
                print("Parent Page ID: \(pageId)")
            }
        }
        
        // Access user information
        if let createdBy = database.createdBy {
            print("\nCreated by: \(createdBy.name ?? "Unknown")")
        }
        
        if let lastEditedBy = database.lastEditedBy {
            print("Last edited by: \(lastEditedBy.name ?? "Unknown")")
        }
        
    } catch let error as NotionAPIError {
        print("API Error: \(error.message)")
    } catch {
        print("Unexpected error: \(error)")
    }
}
```

## New Features

### Complete Database Object
The method now returns the full `NotionDatabase` object with all fields from the Notion Database Object specification:

- **Basic Information**: `id`, `object`, `url`, `publicUrl`
- **Timestamps**: `createdTime`, `lastEditedTime`
- **User Information**: `createdBy`, `lastEditedBy`
- **Content**: `title`, `description`
- **Visual Elements**: `icon`, `cover`
- **Schema**: `properties` (complete property definitions)
- **Structure**: `parent` (page or workspace)
- **Status**: `archived`, `isInline`, `inTrash`

### Enhanced Icon Support
Icons now support three types:
- **Emoji**: Simple emoji icons
- **External**: External image URLs
- **File**: Notion-hosted files with expiry times

### Enhanced Cover Support
Covers support:
- **External**: External image URLs
- **File**: Notion-hosted files with expiry times

### Comprehensive Properties Schema
Each property includes:
- **Basic Info**: `id`, `name`, `type`, `description`
- **Type-specific Configuration**: Select options, formula expressions, relation targets, etc.
- **Future Widget Support**: Ready for property selection in widget configuration

### Error Handling
The method includes comprehensive error handling:
- **API Errors**: Proper `NotionAPIError` with status codes and messages
- **Network Errors**: Graceful handling of connection issues
- **Parsing Errors**: Clear error messages for invalid responses

## Integration Notes

This method is designed to work seamlessly with the existing codebase:
- Uses the same rate limiting as other API methods
- Follows the same error handling patterns
- Integrates with the existing `NotionDatabase` model used throughout the app
- Supports the widget data pipeline for future enhancements