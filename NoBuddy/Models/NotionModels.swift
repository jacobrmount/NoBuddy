import Foundation

// MARK: - Basic Models for Token Validation

/// Simplified NotionUser model for token validation
struct NotionUser: Identifiable, Codable {
    let object: String
    let id: String
    let name: String?
    let avatarUrl: String?
    let type: UserType?
    let email: String?
    
    enum UserType: String, Codable {
        case person = "person"
        case bot = "bot"
    }
    
    private enum CodingKeys: String, CodingKey {
        case object, id, name, type, email
        case avatarUrl = "avatar_url"
    }
}

// MARK: - Search Models (Minimal for API compatibility)

struct SearchResponse: Codable {
    let object: String
    let results: [SearchResult]
    let nextCursor: String?
    let hasMore: Bool
    
    private enum CodingKeys: String, CodingKey {
        case object, results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

struct SearchResult: Codable {
    let object: String
    let id: String
    
    // Only keeping minimal fields needed for counting
    init(object: String, id: String) {
        self.object = object
        self.id = id
    }
}

// MARK: - Database Models (Minimal for listing)

/// Minimal database model for selection UI
struct NotionDatabase: Identifiable, Codable {
    let object: String
    let id: String
    let title: [RichText]?
    let lastEditedTime: Date?
    let icon: DatabaseIcon?
    
    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title.compactMap { $0.plainText }.joined()
        }
        return "Untitled Database"
    }
    
    var safeLastEditedTime: Date {
        return lastEditedTime ?? Date()
    }
    
    private enum CodingKeys: String, CodingKey {
        case object, id, title, icon
        case lastEditedTime = "last_edited_time"
    }
}

/// Simple rich text model for database titles
struct RichText: Codable {
    let type: String
    let plainText: String
    
    private enum CodingKeys: String, CodingKey {
        case type
        case plainText = "plain_text"
    }
}

/// Simple database icon model
struct DatabaseIcon: Codable {
    let type: String
    let emoji: String?
    
    var displayIcon: String {
        return emoji ?? "📋"
    }
}

// MARK: - Error Models

struct NotionAPIError: Codable, Error {
    let object: String
    let status: Int
    let code: String
    let message: String
    
    private enum CodingKeys: String, CodingKey {
        case object, status, code, message
    }
}