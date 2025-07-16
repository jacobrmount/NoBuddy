import Foundation

/// Model representing a Notion integration token
struct NotionToken: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let token: String
    var workspaceName: String?
    var workspaceIcon: String?
    let createdAt: Date
    var lastValidated: Date?
    var isValid: Bool
    
    /// Initializer for creating a new token
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
    
    /// Returns the masked token for display purposes
    var maskedToken: String {
        guard token.count > 8 else { return "••••••••" }
        let prefix = String(token.prefix(4))
        let suffix = String(token.suffix(4))
        return "\(prefix)••••••••\(suffix)"
    }
    
    /// Returns display name for the workspace or a fallback
    var displayName: String {
        return workspaceName ?? name
    }
    
    /// Returns true if the token has been validated recently (within 24 hours)
    var isRecentlyValidated: Bool {
        guard let lastValidated = lastValidated else { return false }
        return lastValidated.timeIntervalSinceNow > -86400 // 24 hours
    }
}

/// Error types for token operations
enum TokenError: Error, LocalizedError {
    case invalidToken
    case networkError
    case unauthorized
    case rateLimited
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "The provided token is invalid"
        case .networkError:
            return "Network connection error"
        case .unauthorized:
            return "Token is not authorized for this operation"
        case .rateLimited:
            return "Rate limit exceeded. Please try again later"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

/// Token validation result
struct TokenValidationResult {
    let isValid: Bool
    let workspaceName: String?
    let workspaceIcon: String?
    let error: TokenError?
    
    static func valid(workspaceName: String?, workspaceIcon: String?) -> TokenValidationResult {
        return TokenValidationResult(isValid: true, workspaceName: workspaceName, workspaceIcon: workspaceIcon, error: nil)
    }
    
    static func invalid(error: TokenError) -> TokenValidationResult {
        return TokenValidationResult(isValid: false, workspaceName: nil, workspaceIcon: nil, error: error)
    }
}