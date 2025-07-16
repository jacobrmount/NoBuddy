import Foundation

/// Represents a Notion integration token with metadata
struct NotionToken: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let token: String // This will be stored securely in Keychain
    var workspaceName: String?
    var workspaceIcon: String?
    let createdAt: Date
    var lastValidated: Date?
    var isValid: Bool
    
    init(name: String, token: String) {
        self.id = UUID()
        self.name = name
        self.token = token
        self.workspaceName = nil
        self.workspaceIcon = nil
        self.createdAt = Date()
        self.lastValidated = nil
        self.isValid = false
    }
    
    /// Creates a copy of the token without the actual token value for secure storage
    var safeModel: SafeNotionToken {
        SafeNotionToken(
            id: id,
            name: name,
            workspaceName: workspaceName,
            workspaceIcon: workspaceIcon,
            createdAt: createdAt,
            lastValidated: lastValidated,
            isValid: isValid
        )
    }
}

/// A safe version of NotionToken that doesn't contain the actual token value
struct SafeNotionToken: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var workspaceName: String?
    var workspaceIcon: String?
    let createdAt: Date
    var lastValidated: Date?
    var isValid: Bool
}

/// Token validation result
enum TokenValidationResult {
    case valid(workspaceName: String?, workspaceIcon: String?)
    case invalid(error: String)
    case networkError(error: String)
}

/// Token management errors
enum TokenError: LocalizedError {
    case invalidToken
    case networkError(String)
    case keychainError(String)
    case tokenAlreadyExists
    case tokenNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "The provided token is invalid or has expired."
        case .networkError(let message):
            return "Network error: \(message)"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .tokenAlreadyExists:
            return "A token with this name already exists."
        case .tokenNotFound:
            return "Token not found."
        }
    }
}