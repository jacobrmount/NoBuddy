import Foundation

/// Model representing a Notion API token with workspace information
struct NotionToken: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let token: String
    var workspaceName: String?
    var workspaceIcon: String?
    let createdAt: Date
    var lastValidated: Date?
    var isValid: Bool
    
    init(name: String, token: String, workspaceName: String? = nil, workspaceIcon: String? = nil) {
        self.id = UUID()
        self.name = name
        self.token = token
        self.workspaceName = workspaceName
        self.workspaceIcon = workspaceIcon
        self.createdAt = Date()
        self.lastValidated = nil
        self.isValid = false
    }
    
    /// Computed property for display purposes
    var displayName: String {
        if let workspaceName = workspaceName, !workspaceName.isEmpty {
            return workspaceName
        }
        return name
    }
    
    /// Masked token for UI display (shows only first 8 characters)
    var maskedToken: String {
        guard token.count > 8 else { return String(repeating: "•", count: token.count) }
        let prefix = String(token.prefix(8))
        let suffix = String(repeating: "•", count: token.count - 8)
        return prefix + suffix
    }
}

/// Response model for Notion token validation
struct TokenValidationResponse: Codable {
    let workspaceName: String?
    let workspaceIcon: String?
    let isValid: Bool
    let error: String?
} 
