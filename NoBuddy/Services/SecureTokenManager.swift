import Foundation
import KeychainAccess
import Combine

/// Manages secure storage and retrieval of Notion integration tokens
@MainActor
class SecureTokenManager: ObservableObject {
    @Published var tokens: [SafeNotionToken] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let keychain: Keychain
    private let userDefaults = UserDefaults.standard
    private let tokensKey = "saved_tokens"
    
    init() {
        // Initialize Keychain with app-specific service and security settings
        self.keychain = Keychain(service: "com.nobuddy.tokens")
            .accessibility(.whenUnlockedThisDeviceOnly)
            .synchronizable(false)
    }
    
    // MARK: - Public Methods
    
    /// Load all saved tokens from storage
    func loadTokens() {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load token metadata from UserDefaults
            if let data = userDefaults.data(forKey: tokensKey) {
                let decodedTokens = try JSONDecoder().decode([SafeNotionToken].self, from: data)
                self.tokens = decodedTokens
            }
        } catch {
            self.errorMessage = "Failed to load tokens: \(error.localizedDescription)"
        }
    }
    
    /// Add a new token with validation
    func addToken(name: String, token: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Validate input
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TokenError.invalidToken
        }
        
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TokenError.invalidToken
        }
        
        // Check for duplicate names
        if tokens.contains(where: { $0.name == name }) {
            throw TokenError.tokenAlreadyExists
        }
        
        // Create token model
        let notionToken = NotionToken(name: name, token: token)
        
        // Validate token with Notion API
        let apiClient = NotionAPIClient()
        let validationResult = await apiClient.validateToken(token)
        
        var updatedToken = notionToken
        switch validationResult {
        case .valid(let workspaceName, let workspaceIcon):
            updatedToken.workspaceName = workspaceName
            updatedToken.workspaceIcon = workspaceIcon
            updatedToken.isValid = true
            updatedToken.lastValidated = Date()
        case .invalid(let error):
            throw TokenError.invalidToken
        case .networkError(let error):
            // Allow saving but mark as unvalidated
            self.errorMessage = "Could not validate token: \(error)"
        }
        
        // Store token securely in Keychain
        do {
            try keychain.set(token, key: updatedToken.id.uuidString)
        } catch {
            throw TokenError.keychainError(error.localizedDescription)
        }
        
        // Add to tokens array and save metadata
        let safeToken = updatedToken.safeModel
        tokens.append(safeToken)
        try saveTokensMetadata()
        
        self.errorMessage = nil
    }
    
    /// Update an existing token
    func updateToken(_ tokenId: UUID, name: String) throws {
        guard let index = tokens.firstIndex(where: { $0.id == tokenId }) else {
            throw TokenError.tokenNotFound
        }
        
        // Check for duplicate names (excluding current token)
        if tokens.enumerated().contains(where: { $0.offset != index && $0.element.name == name }) {
            throw TokenError.tokenAlreadyExists
        }
        
        tokens[index].name = name
        try saveTokensMetadata()
        
        self.errorMessage = nil
    }
    
    /// Delete a token
    func deleteToken(_ tokenId: UUID) throws {
        guard let index = tokens.firstIndex(where: { $0.id == tokenId }) else {
            throw TokenError.tokenNotFound
        }
        
        // Remove from Keychain
        do {
            try keychain.remove(tokenId.uuidString)
        } catch {
            throw TokenError.keychainError(error.localizedDescription)
        }
        
        // Remove from tokens array
        tokens.remove(at: index)
        try saveTokensMetadata()
        
        self.errorMessage = nil
    }
    
    /// Get the actual token value from Keychain
    func getToken(_ tokenId: UUID) throws -> String {
        do {
            guard let token = try keychain.get(tokenId.uuidString) else {
                throw TokenError.tokenNotFound
            }
            return token
        } catch {
            throw TokenError.keychainError(error.localizedDescription)
        }
    }
    
    /// Validate all tokens
    func validateAllTokens() async {
        isLoading = true
        defer { isLoading = false }
        
        let apiClient = NotionAPIClient()
        
        for (index, safeToken) in tokens.enumerated() {
            do {
                let token = try getToken(safeToken.id)
                let result = await apiClient.validateToken(token)
                
                switch result {
                case .valid(let workspaceName, let workspaceIcon):
                    tokens[index].workspaceName = workspaceName
                    tokens[index].workspaceIcon = workspaceIcon
                    tokens[index].isValid = true
                    tokens[index].lastValidated = Date()
                case .invalid, .networkError:
                    tokens[index].isValid = false
                }
            } catch {
                tokens[index].isValid = false
            }
        }
        
        do {
            try saveTokensMetadata()
        } catch {
            self.errorMessage = "Failed to save token validation results"
        }
    }
    
    /// Get a complete NotionToken (including token value) for API calls
    func getCompleteToken(_ tokenId: UUID) throws -> NotionToken {
        guard let safeToken = tokens.first(where: { $0.id == tokenId }) else {
            throw TokenError.tokenNotFound
        }
        
        let tokenValue = try getToken(tokenId)
        
        return NotionToken(
            id: safeToken.id,
            name: safeToken.name,
            token: tokenValue,
            workspaceName: safeToken.workspaceName,
            workspaceIcon: safeToken.workspaceIcon,
            createdAt: safeToken.createdAt,
            lastValidated: safeToken.lastValidated,
            isValid: safeToken.isValid
        )
    }
    
    // MARK: - Private Methods
    
    private func saveTokensMetadata() throws {
        do {
            let data = try JSONEncoder().encode(tokens)
            userDefaults.set(data, forKey: tokensKey)
        } catch {
            throw TokenError.keychainError("Failed to save token metadata: \(error.localizedDescription)")
        }
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - NotionToken Extensions

private extension NotionToken {
    init(id: UUID, name: String, token: String, workspaceName: String?, workspaceIcon: String?, createdAt: Date, lastValidated: Date?, isValid: Bool) {
        self.id = id
        self.name = name
        self.token = token
        self.workspaceName = workspaceName
        self.workspaceIcon = workspaceIcon
        self.createdAt = createdAt
        self.lastValidated = lastValidated
        self.isValid = isValid
    }
}