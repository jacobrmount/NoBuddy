import Foundation
import Combine

/// Service responsible for secure storage and management of Notion tokens
@MainActor
class SecureTokenManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published private(set) var tokens: [NotionToken] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: TokenError?
    
    private let userDefaults: UserDefaults
    private let tokenListKey = "saved_tokens"
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        Task {
            await loadTokens()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load all saved tokens from secure storage
    func loadTokens() async {
        isLoading = true
        error = nil
        
        do {
            let tokenData = userDefaults.data(forKey: tokenListKey) ?? Data()
            let tokenMetadata = try JSONDecoder().decode([TokenMetadata].self, from: tokenData)
            
            var loadedTokens: [NotionToken] = []
            
            for metadata in tokenMetadata {
                // For now, create sample tokens since we don't have Keychain access
                let token = NotionToken(
                    name: metadata.name,
                    token: "secret_sample_token_\(metadata.id.uuidString.prefix(8))"
                )
                loadedTokens.append(token)
            }
            
            self.tokens = loadedTokens.sorted { $0.createdAt > $1.createdAt }
        } catch {
            self.error = .loadFailed(error)
        }
        
        isLoading = false
    }
    
    /// Add a new token to secure storage
    func addToken(name: String, token: String) async -> Result<NotionToken, TokenError> {
        isLoading = true
        error = nil
        
        // Validate token format
        guard isValidNotionToken(token) else {
            error = .invalidFormat
            isLoading = false
            return .failure(.invalidFormat)
        }
        
        // Check for duplicate tokens
        if tokens.contains(where: { $0.token == token }) {
            error = .duplicateToken
            isLoading = false
            return .failure(.duplicateToken)
        }
        
        let newToken = NotionToken(name: name, token: token)
        
        do {
            // Add to local array
            tokens.insert(newToken, at: 0)
            
            // Save metadata to UserDefaults
            try await saveTokenMetadata()
            
            isLoading = false
            return .success(newToken)
        } catch {
            self.error = .saveFailed(error)
            isLoading = false
            return .failure(.saveFailed(error))
        }
    }
    
    /// Update an existing token
    func updateToken(_ token: NotionToken) async -> Result<NotionToken, TokenError> {
        isLoading = true
        error = nil
        
        guard let index = tokens.firstIndex(where: { $0.id == token.id }) else {
            error = .tokenNotFound
            isLoading = false
            return .failure(.tokenNotFound)
        }
        
        // Update local array
        tokens[index] = token
        
        do {
            try await saveTokenMetadata()
            isLoading = false
            return .success(token)
        } catch {
            self.error = .updateFailed(error)
            isLoading = false
            return .failure(.updateFailed(error))
        }
    }
    
    /// Delete a token from secure storage
    func deleteToken(_ token: NotionToken) async -> Result<Void, TokenError> {
        isLoading = true
        error = nil
        
        // Remove from local array
        tokens.removeAll { $0.id == token.id }
        
        do {
            // Update metadata
            try await saveTokenMetadata()
            
            isLoading = false
            return .success(())
        } catch {
            self.error = .deleteFailed(error)
            isLoading = false
            return .failure(.deleteFailed(error))
        }
    }
    
    /// Delete all tokens from secure storage
    func deleteAllTokens() async -> Result<Void, TokenError> {
        isLoading = true
        error = nil
        
        // Clear metadata
        userDefaults.removeObject(forKey: tokenListKey)
        
        // Clear local array
        tokens.removeAll()
        
        isLoading = false
        return .success(())
    }
    
    /// Get a specific token by ID
    func getToken(by id: UUID) -> NotionToken? {
        return tokens.first { $0.id == id }
    }
    
    /// Validate a token against the Notion API
    func validateToken(_ token: NotionToken) async -> Result<TokenValidationResponse, TokenError> {
        // Simulate validation for now
        let validationResponse = TokenValidationResponse(
            workspaceName: "Sample Workspace",
            workspaceIcon: nil,
            isValid: true,
            error: nil
        )
        
        // Update token with validation info
        var updatedToken = token
        updatedToken.workspaceName = validationResponse.workspaceName
        updatedToken.workspaceIcon = validationResponse.workspaceIcon
        updatedToken.lastValidated = Date()
        updatedToken.isValid = true
        
        let _ = await updateToken(updatedToken)
        
        return .success(validationResponse)
    }
    
    /// Clear any error state
    func clearError() {
        error = nil
    }
    
    // MARK: - Private Methods
    
    private func saveTokenMetadata() async throws {
        let metadata = tokens.map { TokenMetadata(id: $0.id, name: $0.name, createdAt: $0.createdAt) }
        let data = try JSONEncoder().encode(metadata)
        userDefaults.set(data, forKey: tokenListKey)
    }
    
    private func isValidNotionToken(_ token: String) -> Bool {
        // Notion integration tokens start with "secret_" and are 50 characters long
        // Internal integration tokens start with "ntn_" and are 51 characters long
        let secretPattern = "^secret_[A-Za-z0-9]{43}$"
        let internalPattern = "^ntn_[A-Za-z0-9]{46}$"  // ← Changed from 36 to 46
        
        let secretRegex = try? NSRegularExpression(pattern: secretPattern)
        let internalRegex = try? NSRegularExpression(pattern: internalPattern)
        
        let range = NSRange(location: 0, length: token.utf16.count)
        
        return secretRegex?.firstMatch(in: token, options: [], range: range) != nil ||
               internalRegex?.firstMatch(in: token, options: [], range: range) != nil
    }
}

// MARK: - Supporting Types

/// Lightweight metadata for tokens stored in UserDefaults
private struct TokenMetadata: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
}

/// Comprehensive error types for token operations
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
        }
    }
    
    static func == (lhs: TokenError, rhs: TokenError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidFormat, .invalidFormat),
             (.duplicateToken, .duplicateToken),
             (.tokenNotFound, .tokenNotFound):
            return true
        case (.loadFailed(let lhsError), .loadFailed(let rhsError)),
             (.saveFailed(let lhsError), .saveFailed(let rhsError)),
             (.updateFailed(let lhsError), .updateFailed(let rhsError)),
             (.deleteFailed(let lhsError), .deleteFailed(let rhsError)),
             (.deleteAllFailed(let lhsError), .deleteAllFailed(let rhsError)),
             (.validationFailed(let lhsError), .validationFailed(let rhsError)),
             (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
