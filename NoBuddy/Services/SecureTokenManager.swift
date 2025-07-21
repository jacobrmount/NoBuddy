import Foundation
import Combine
import WidgetKit

/// Service responsible for secure storage and management of Notion tokens
@MainActor
class SecureTokenManager: ObservableObject {
    
    // MARK: - Properties
    
@Published private(set) var tokens: [NotionToken] = []
@Published private(set) var isLoading = false
@Published private(set) var error: TokenError?

// SECURE: Using Keychain instead of UserDefaults
private let keychainManager: KeychainManager
private let userDefaults: UserDefaults  // Only used for migration
private let legacyTokenListKey = "saved_tokens"  // Legacy UserDefaults key

// Concurrent queue for thread-safe operations
private let queue = DispatchQueue(label: "com.nobuddy.app.token.queue", attributes: .concurrent)
    
    private var hasMigrated: Bool {
        get { userDefaults.bool(forKey: "tokens_migrated_to_keychain") }
        set { userDefaults.set(newValue, forKey: "tokens_migrated_to_keychain") }
    }
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard, keychainManager: KeychainManager? = nil) {
        self.userDefaults = userDefaults
        self.keychainManager = keychainManager ?? KeychainManager()
        
        Task {
            await loadTokens()
        }
    }
    
    // MARK: - Public Methods
    
    /// Add a new token
    func addToken(name: String, token: String) async -> Result<NotionToken, TokenError> {
        // Validate token format
        guard isValidNotionToken(token) else {
            return .failure(.invalidFormat)
        }
        
        // Check for duplicates
        if tokens.contains(where: { $0.token == token }) {
            return .failure(.duplicateToken)
        }
        
        // Create new token
        let newToken = NotionToken(
            name: name,
            token: token
        )
        
        // Validate token with Notion API
        do {
            let validatedToken = try await validateToken(newToken)
            
            // Add to tokens array
            tokens.append(validatedToken)
            tokens.sort { $0.createdAt > $1.createdAt }
            
            // Save to keychain
            do {
                try await saveTokensToKeychain()
                return .success(validatedToken)
            } catch {
                // Remove from array if save failed
                tokens.removeAll { $0.id == validatedToken.id }
                return .failure(.saveFailed(error))
            }
            
        } catch let error as TokenError {
            return .failure(error)
        } catch {
            return .failure(.validationFailed(error))
        }
    }
    
    /// Load all saved tokens from secure storage (Keychain)
    func loadTokens() async {
        print("[SecureTokenManager] Loading tokens from secure storage...")
        isLoading = true
        error = nil
        
        do {
            // First, handle migration from UserDefaults if needed
            if !hasMigrated {
                await migrateFromUserDefaults()
            }
            
            // Load tokens from secure Keychain storage
            let loadedTokens = try keychainManager.retrieveNotionTokens()
            self.tokens = loadedTokens.sorted { $0.createdAt > $1.createdAt }
            
            print("[SecureTokenManager] ✅ Successfully loaded \(loadedTokens.count) tokens from Keychain")
            
        } catch let keychainError as KeychainError {
            print("[SecureTokenManager] ❌ Keychain error loading tokens: \(keychainError)")
            self.error = .keychainError(keychainError)
        } catch {
            print("[SecureTokenManager] ❌ Failed to load tokens from Keychain: \(error)")
            self.error = .loadFailed(error)
        }
        
        isLoading = false
    }
    
/// Save a token in secure storage
func saveToken(token: NotionToken) async throws {
    let data = try JSONEncoder().encode(token)
    let key = token.id.uuidString
    
    queue.async(flags: .barrier) {
        do {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrService as String: SecurityConstants.keychainService,
            kSecAttrAccessGroup as String: "group.com.nobuddy.app",
                kSecAttrAccessible as String: SecurityConstants.keychainAccessibility
            ]

            let status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess {
                throw TokenError.keychainError(KeychainError.from(status: status))
            }
        } catch {
            DispatchQueue.main.async {
                self.error = .saveFailed(error)
            }
        }
    }
}

/// Delete a specific token from secure storage
func deleteToken(id: UUID) async -> Result<Void, TokenError> {
    // Remove from local array
    if let index = tokens.firstIndex(where: { $0.id == id }) {
        tokens.remove(at: index)
    } else {
        return .failure(.tokenNotFound)
    }
    
    // Save updated array to keychain
    do {
        try await saveTokensToKeychain()
        return .success(())
    } catch {
        // Re-add to array if save failed
        await loadTokens()
        return .failure(.deleteFailed(error))
    }
}

/// Delete all tokens from secure storage
func deleteAllTokens() async throws {
    queue.async(flags: .barrier) {
        do {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: SecurityConstants.keychainService,
                kSecAttrAccessGroup as String: "group.com.nobuddy.app"
            ]

            let status = SecItemDelete(query as CFDictionary)
            if status != errSecSuccess && status != errSecItemNotFound {
                throw TokenError.keychainError(KeychainError.from(status: status))
            }
            
            DispatchQueue.main.async {
                self.tokens.removeAll()
            }
        } catch {
            DispatchQueue.main.async {
                self.error = .deleteAllFailed(error)
            }
        }
    }
}
    
    /// Get a specific token by ID
    func getToken(by id: UUID) -> NotionToken? {
        return tokens.first { $0.id == id }
    }
    
    /// Validate a token against the Notion API with comprehensive workspace info
    func validateToken(_ token: NotionToken) async throws -> NotionToken {
        print("[SecureTokenManager] 🔄 Validating token with Notion API: \(token.name)")
        
        // Show loading state
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Create API client for this token
            let apiClient = NotionAPIClient(token: token.token)
            
            // Call getCurrentUser() to validate token and get workspace info
            let user = try await apiClient.getCurrentUser()
            
            // Extract workspace name and icon from API response
            var updatedToken = token
            updatedToken.workspaceName = user.name
            updatedToken.workspaceIcon = user.avatarUrl
            updatedToken.isValid = true
            updatedToken.lastValidated = Date()
            
            // Cache validation results to avoid excessive API calls
            print("[SecureTokenManager] ✅ Token validated successfully")
            print("[SecureTokenManager] - Workspace: \(user.name ?? "Unknown")")
            print("[SecureTokenManager] - User type: \(user.type?.rawValue ?? "unknown")")
            
            return updatedToken
            
        } catch let error as NotionAPIError where error.status == 401 {
            // Handle 401 Unauthorized status for invalid/expired tokens
            print("[SecureTokenManager] ❌ Token is invalid or expired (401 Unauthorized)")
            self.error = .unauthorized
            
            // Update token to mark as invalid
            var invalidToken = token
            invalidToken.isValid = false
            invalidToken.lastValidated = Date()
            throw TokenError.unauthorized
            
        } catch {
            // Handle other errors (network timeouts, etc.)
            print("[SecureTokenManager] ❌ Validation failed: \(error)")
            self.error = .validationFailed(error)
            
            // Clear error messages on validation failure
            throw TokenError.validationFailed(error)
        }
    }

    func validateAndSaveToken(_ token: NotionToken) async -> Result<TokenValidationResponse, TokenError> {
        print("[SecureTokenManager] 🔍 Validating and saving token: \(token.name)")
        
        // Show loading state during validation process
        isLoading = true
        defer {
            isLoading = false
        }
        
        do {
            let apiClient = NotionAPIClient(token: token.token)
            
            // Call getCurrentUser() from NotionAPIClient for validation
            let user = try await apiClient.getCurrentUser()
            
            // Extract workspace name and icon from API response
            let validationResponse = TokenValidationResponse(
                workspaceName: user.name ?? "Notion Workspace",
                workspaceIcon: user.avatarUrl,
                isValid: true,
                error: nil
            )
            
            // Update token object with fetched workspace information
            var updatedToken = token
            updatedToken.workspaceName = validationResponse.workspaceName
            updatedToken.workspaceIcon = validationResponse.workspaceIcon
            updatedToken.lastValidated = Date()
            updatedToken.isValid = true
            
            // Update the local tokens array
            if let index = tokens.firstIndex(where: { $0.id == token.id }) {
                tokens[index] = updatedToken
            }
            
            // Update token storage after successful validation
            try await saveTokensToKeychain()
            
            print("[SecureTokenManager] ✅ Token validation successful")
            print("[SecureTokenManager] - Workspace: \(validationResponse.workspaceName ?? "Unknown")")
            print("[SecureTokenManager] - Valid: \(validationResponse.isValid)")
            
            return .success(validationResponse)
            
        } catch let error as NotionAPIError where error.status == 401 {
            // Handle 401 Unauthorized status for invalid/expired tokens
            print("[SecureTokenManager] ❌ Token is unauthorized (401)")
            
            // Update token to mark as invalid
            var updatedToken = token
            updatedToken.lastValidated = Date()
            updatedToken.isValid = false
            
            // Update the local tokens array with the invalid token
            if let index = tokens.firstIndex(where: { $0.id == token.id }) {
                tokens[index] = updatedToken
            }
            
            // Update token storage after validation failure
            do {
                try await saveTokensToKeychain()
            } catch {
                print("[SecureTokenManager] Failed to save updated token state: \(error)")
            }
            
            // Clear error messages on validation failure
            return .failure(.unauthorized)
            
        } catch {
            // Handle network timeouts gracefully in validation
            print("[SecureTokenManager] ❌ Token validation failed: \(error)")
            
            // Show appropriate error messages for different failure types
            self.error = .validationFailed(error)
            
            return .failure(.validationFailed(error))
        }
    }
    
    /// Quick token validation (faster, less comprehensive)
    func validateTokenQuick(_ token: NotionToken) async -> Result<Bool, TokenError> {
        do {
            let apiClient = NotionAPIClient(token: token.token)
            
            // Use getCurrentUser() for quick validation check
            do {
                _ = try await apiClient.getCurrentUser()
                
                // Set isValid flag based on successful API response
                var updatedToken = token
                updatedToken.lastValidated = Date()
                updatedToken.isValid = true
                
                // Update the local tokens array
                if let index = tokens.firstIndex(where: { $0.id == token.id }) {
                    tokens[index] = updatedToken
                }
                
                // Cache validation results to avoid excessive API calls
                try await saveTokensToKeychain()
                
                return .success(true)
                
            } catch let error as NotionAPIError where error.status == 401 {
                // Token is invalid
                var updatedToken = token
                updatedToken.lastValidated = Date()
                updatedToken.isValid = false
                
                // Update the local tokens array
                if let index = tokens.firstIndex(where: { $0.id == token.id }) {
                    tokens[index] = updatedToken
                }
                
                try await saveTokensToKeychain()
                
                return .success(false)
            }
            
        } catch {
            // Consider validation caching to reduce API calls
            return .failure(.validationFailed(error))
        }
    }
    
    /// Clear any error state
    func clearError() {
        error = nil
    }
    
    /// Refresh and update the list of databases for a specific token
    func refreshDatabases(for token: NotionToken) async throws -> [NotionDatabase] {
        print("[SecureTokenManager] 🔄 Refreshing databases for token: \(token.name)")
        isLoading = true
        defer { isLoading = false }

        do {
            // Create API client for this token
            let apiClient = NotionAPIClient(token: token.token)
            
            // Fetch updated databases without cache
            let updatedDatabases = try await apiClient.searchDatabases()

            // Update widgets with new database data
            await updateWidgetsAfterDatabaseRefresh(updatedDatabases, workspaceName: token.workspaceName)

            print("[SecureTokenManager] ✅ Databases refreshed successfully: \(updatedDatabases.count) databases")
            return updatedDatabases
        } catch {
            print("[SecureTokenManager] ❌ Failed to refresh databases: \(error)")
            throw error
        }
    }

    /// SECURITY: Validate that tokens are stored securely (development/debug only)
    func validateSecureStorage() -> Bool {
        // Check if tokens exist in insecure UserDefaults (should be false)
        let hasInsecureData = userDefaults.data(forKey: legacyTokenListKey) != nil
        
        // Check if tokens exist in secure Keychain (should be true if we have tokens)
        let hasSecureData = keychainManager.notionTokensExist()
        
        // Check if migration is marked as complete
        let migrationComplete = hasMigrated
        
        print("[SecureTokenManager] Security Validation:")
        print("- Has insecure data in UserDefaults: \(hasInsecureData)")
        print("- Has secure data in Keychain: \(hasSecureData)")
        print("- Migration completed: \(migrationComplete)")
        
        // Security is valid if no insecure data exists and migration is complete
        let isSecure = !hasInsecureData && migrationComplete
        
        if isSecure {
            print("[SecureTokenManager] ✅ Security validation PASSED")
        } else {
            print("[SecureTokenManager] ❌ Security validation FAILED")
        }
        
        return isSecure
    }
    
    // MARK: - Private Methods
    
    /// SECURE: Save tokens to Keychain instead of UserDefaults
func saveTokensToKeychain() async throws {
        do {
            try keychainManager.updateNotionTokens(tokens)
            print("[SecureTokenManager] ✅ Successfully saved \(tokens.count) tokens to Keychain")
        } catch let keychainError as KeychainError {
            print("[SecureTokenManager] ❌ Keychain error saving tokens: \(keychainError)")
            throw TokenError.keychainError(keychainError)
        } catch {
            print("[SecureTokenManager] ❌ Failed to save tokens to Keychain: \(error)")
            throw error
        }
    }
    
    /// MIGRATION: Migrate tokens from insecure UserDefaults to secure Keychain
    func migrateFromUserDefaults() async {
        print("[SecureTokenManager] 🔄 Starting migration from UserDefaults to Keychain...")
        
        guard let legacyData = userDefaults.data(forKey: legacyTokenListKey),
              !legacyData.isEmpty else {
            print("[SecureTokenManager] No legacy tokens found in UserDefaults")
            hasMigrated = true
            return
        }
        
        do {
            // Decode legacy tokens from UserDefaults
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let legacyTokens = try decoder.decode([NotionToken].self, from: legacyData)
            
            print("[SecureTokenManager] Found \(legacyTokens.count) legacy tokens in UserDefaults")
            
            // Store tokens securely in Keychain
            try keychainManager.storeNotionTokens(legacyTokens)
            
            // Remove insecure data from UserDefaults
            userDefaults.removeObject(forKey: legacyTokenListKey)
            
            // Mark migration as complete
            hasMigrated = true
            
            print("[SecureTokenManager] ✅ Successfully migrated \(legacyTokens.count) tokens to Keychain")
            print("[SecureTokenManager] ✅ Removed insecure data from UserDefaults")
            
        } catch {
            print("[SecureTokenManager] ❌ Migration failed: \(error)")
            // Don't mark as migrated so we can retry
            self.error = .loadFailed(error)
        }
    }
    
    func isValidNotionToken(_ token: String) -> Bool {
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

// TokenError is imported from NotionAPI Client.swift
