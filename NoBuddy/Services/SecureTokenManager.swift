import Foundation
import KeychainAccess
import Combine

/// Secure token manager for handling Notion integration tokens
@MainActor
class SecureTokenManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var tokens: [NotionToken] = []
    @Published var isLoading = false
    @Published var error: TokenError?
    
    // MARK: - Private Properties
    private let keychain: Keychain
    private let tokenListKey = "stored_tokens"
    private let apiClient: NotionAPIClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(apiClient: NotionAPIClient = NotionAPIClient()) {
        self.apiClient = apiClient
        
        // Configure Keychain with secure settings
        self.keychain = Keychain(service: "com.nobuddy.tokens")
            .accessibility(.whenUnlockedThisDeviceOnly)
            .synchronizable(false)
        
        Task {
            await loadTokens()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load all stored tokens from Keychain
    func loadTokens() async {
        isLoading = true
        error = nil
        
        do {
            let tokenIds = try loadTokenIdList()
            var loadedTokens: [NotionToken] = []
            
            for tokenId in tokenIds {
                if let token = try loadToken(id: tokenId) {
                    loadedTokens.append(token)
                }
            }
            
            tokens = loadedTokens.sorted { $0.createdAt > $1.createdAt }
        } catch {
            self.error = TokenError.unknown("Failed to load tokens: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Add a new token and validate it
    func addToken(name: String, token: String) async -> Bool {
        isLoading = true
        error = nil
        
        // Validate token format
        guard !token.isEmpty, token.hasPrefix("secret_") else {
            error = TokenError.invalidToken
            isLoading = false
            return false
        }
        
        // Check if token already exists
        if tokens.contains(where: { $0.token == token }) {
            error = TokenError.unknown("Token already exists")
            isLoading = false
            return false
        }
        
        // Validate token with Notion API
        let validationResult = await validateTokenWithAPI(token)
        
        var newToken = NotionToken(
            name: name,
            token: token,
            workspaceName: validationResult.workspaceName,
            workspaceIcon: validationResult.workspaceIcon
        )
        
        newToken.lastValidated = Date()
        newToken.isValid = validationResult.isValid
        
        if !validationResult.isValid {
            error = validationResult.error
            isLoading = false
            return false
        }
        
        // Store token securely
        do {
            try storeToken(newToken)
            tokens.append(newToken)
            tokens.sort { $0.createdAt > $1.createdAt }
        } catch {
            self.error = TokenError.unknown("Failed to store token: \(error.localizedDescription)")
            isLoading = false
            return false
        }
        
        isLoading = false
        return true
    }
    
    /// Update an existing token
    func updateToken(_ token: NotionToken, name: String? = nil) async -> Bool {
        guard let index = tokens.firstIndex(where: { $0.id == token.id }) else {
            error = TokenError.unknown("Token not found")
            return false
        }
        
        var updatedToken = token
        if let name = name {
            updatedToken.name = name
        }
        
        do {
            try storeToken(updatedToken)
            tokens[index] = updatedToken
        } catch {
            self.error = TokenError.unknown("Failed to update token: \(error.localizedDescription)")
            return false
        }
        
        return true
    }
    
    /// Delete a token
    func deleteToken(_ token: NotionToken) async -> Bool {
        do {
            try removeToken(id: token.id)
            tokens.removeAll { $0.id == token.id }
            return true
        } catch {
            self.error = TokenError.unknown("Failed to delete token: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Validate a specific token
    func validateToken(_ token: NotionToken) async -> TokenValidationResult {
        isLoading = true
        
        let result = await validateTokenWithAPI(token.token)
        
        if result.isValid {
            // Update the token with latest validation info
            var updatedToken = token
            updatedToken.lastValidated = Date()
            updatedToken.isValid = true
            updatedToken.workspaceName = result.workspaceName ?? token.workspaceName
            updatedToken.workspaceIcon = result.workspaceIcon ?? token.workspaceIcon
            
            do {
                try storeToken(updatedToken)
                if let index = tokens.firstIndex(where: { $0.id == token.id }) {
                    tokens[index] = updatedToken
                }
            } catch {
                // Log error but don't fail validation
                print("Failed to update token after validation: \(error)")
            }
        }
        
        isLoading = false
        return result
    }
    
    /// Validate all tokens
    func validateAllTokens() async {
        isLoading = true
        
        for (index, token) in tokens.enumerated() {
            let result = await validateTokenWithAPI(token.token)
            
            var updatedToken = token
            updatedToken.lastValidated = Date()
            updatedToken.isValid = result.isValid
            
            if result.isValid {
                updatedToken.workspaceName = result.workspaceName ?? token.workspaceName
                updatedToken.workspaceIcon = result.workspaceIcon ?? token.workspaceIcon
            }
            
            do {
                try storeToken(updatedToken)
                tokens[index] = updatedToken
            } catch {
                print("Failed to update token \(token.id) after validation: \(error)")
            }
        }
        
        isLoading = false
    }
    
    /// Get a valid token for API operations
    func getValidToken() -> NotionToken? {
        return tokens.first { $0.isValid && $0.isRecentlyValidated }
    }
    
    /// Clear all error states
    func clearError() {
        error = nil
    }
    
    // MARK: - Private Methods
    
    private func loadTokenIdList() throws -> [UUID] {
        guard let data = keychain[data: tokenListKey] else {
            return []
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([UUID].self, from: data)
    }
    
    private func saveTokenIdList(_ ids: [UUID]) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(ids)
        keychain[data: tokenListKey] = data
    }
    
    private func loadToken(id: UUID) throws -> NotionToken? {
        let key = "token_\(id.uuidString)"
        guard let data = keychain[data: key] else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(NotionToken.self, from: data)
    }
    
    private func storeToken(_ token: NotionToken) throws {
        let key = "token_\(token.id.uuidString)"
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(token)
        
        keychain[data: key] = data
        
        // Update token ID list
        var tokenIds = try loadTokenIdList()
        if !tokenIds.contains(token.id) {
            tokenIds.append(token.id)
            try saveTokenIdList(tokenIds)
        }
    }
    
    private func removeToken(id: UUID) throws {
        let key = "token_\(id.uuidString)"
        
        // Remove from keychain
        try keychain.remove(key)
        
        // Update token ID list
        var tokenIds = try loadTokenIdList()
        tokenIds.removeAll { $0 == id }
        try saveTokenIdList(tokenIds)
    }
    
    private func validateTokenWithAPI(_ token: String) async -> TokenValidationResult {
        do {
            // Use the Notion API to get current user info to validate token
            let user = try await apiClient.getCurrentUser(token: token)
            
            // For workspace info, we could make additional API calls
            // For now, we'll use the user info as validation
            let workspaceName = user.name ?? "Unknown Workspace"
            
            return TokenValidationResult.valid(
                workspaceName: workspaceName,
                workspaceIcon: nil // Could be enhanced to fetch workspace icon
            )
        } catch let apiError as NotionAPIError {
            switch apiError.status {
            case 401:
                return TokenValidationResult.invalid(error: .unauthorized)
            case 429:
                return TokenValidationResult.invalid(error: .rateLimited)
            default:
                return TokenValidationResult.invalid(error: .unknown(apiError.message))
            }
        } catch {
            if error.localizedDescription.contains("network") || 
               error.localizedDescription.contains("connection") {
                return TokenValidationResult.invalid(error: .networkError)
            }
            return TokenValidationResult.invalid(error: .unknown(error.localizedDescription))
        }
    }
}

// MARK: - Extensions

extension SecureTokenManager {
    
    /// Import tokens from a JSON file (for migration or backup)
    func importTokens(from data: Data) async -> Bool {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importedTokens = try decoder.decode([NotionToken].self, from: data)
            
            var successCount = 0
            for token in importedTokens {
                // Check if token already exists
                if !tokens.contains(where: { $0.token == token.token }) {
                    let success = await addToken(name: token.name, token: token.token)
                    if success {
                        successCount += 1
                    }
                }
            }
            
            return successCount > 0
        } catch {
            self.error = TokenError.unknown("Failed to import tokens: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Export tokens to JSON (excluding sensitive token data)
    func exportTokensMetadata() -> Data? {
        let tokenMetadata = tokens.map { token in
            TokenMetadata(
                id: token.id,
                name: token.name,
                workspaceName: token.workspaceName,
                workspaceIcon: token.workspaceIcon,
                createdAt: token.createdAt,
                lastValidated: token.lastValidated,
                isValid: token.isValid
            )
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try? encoder.encode(tokenMetadata)
    }
}

// MARK: - Supporting Types

struct TokenMetadata: Codable {
    let id: UUID
    let name: String
    let workspaceName: String?
    let workspaceIcon: String?
    let createdAt: Date
    let lastValidated: Date?
    let isValid: Bool
}