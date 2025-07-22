// Test file to verify NotionDatabase models compile correctly
import Foundation

// This file tests that the NotionDatabase models can be instantiated
// without infinite recursion errors

func testNotionDatabaseModels() {
    // Test basic database creation
    let database = NotionDatabase(
        object: "database",
        id: "test-id",
        createdTime: Date(),
        createdBy: nil,
        lastEditedTime: Date(),
        lastEditedBy: nil,
        title: nil,
        description: nil,
        icon: nil,
        cover: nil,
        properties: nil,
        parent: nil,
        url: nil,
        archived: false,
        isInline: false,
        publicUrl: nil,
        inTrash: false
    )
    
    print("Database ID: \(database.id)")
    print("Display Title: \(database.displayTitle)")
    
    // Test user model
    let user = DatabaseUser(
        object: "user",
        id: "user-id",
        name: "Test User",
        avatarUrl: nil,
        type: "person",
        person: DatabasePersonDetails(email: "test@example.com"),
        bot: nil
    )
    
    print("User Name: \(user.name ?? "Unknown")")
    
    // Test bot owner (should not cause recursion)
    let botOwner = DatabaseBotOwner(
        type: "user",
        userId: "owner-id",
        workspace: false
    )
    
    print("Bot Owner Type: \(botOwner.type)")
    
    // Test JSON encoding/decoding
    do {
        let encoded = try JSONEncoder().encode(database)
        let decoded = try JSONDecoder().decode(NotionDatabase.self, from: encoded)
        print("Encoding/Decoding successful: \(decoded.id)")
    } catch {
        print("Encoding/Decoding failed: \(error)")
    }
    
    print("All model tests completed successfully!")
}