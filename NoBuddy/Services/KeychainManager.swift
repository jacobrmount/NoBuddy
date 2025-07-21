import Foundation
import Security

/// Secure keychain wrapper for storing sensitive data
class KeychainManager {
    
    // MARK: - Constants
    
    private let service: String
    static let defaultService: String = Bundle.main.bundleIdentifier ?? "com.nobuddy.app"
    
    // MARK: - Initialization
    
    init(service: String = KeychainManager.defaultService) {
        self.service = service
    }
    
    // MARK: - Public Methods
    
    /// Store data securely in keychain
    /// - Parameters:
    ///   - data: Data to store
    ///   - key: Unique identifier for the data
    /// - Throws: KeychainError if operation fails
    func store(_ data: Data, forKey key: String) throws {
        // Delete existing item first (if any)
        let _ = try? delete(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            print("[KeychainManager] Failed to store item for key: \(key.prefix(8))... Status: \(status)")
            throw KeychainError.from(status: status)
        }
        
        print("[KeychainManager] ✅ Successfully stored item for key: \(key.prefix(8))...")
    }
    
    /// Retrieve data from keychain
    /// - Parameter key: Unique identifier for the data
    /// - Returns: Data if found, nil otherwise
    /// - Throws: KeychainError if operation fails (except for item not found)
    func retrieve(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.unexpectedData
            }
            print("[KeychainManager] ✅ Successfully retrieved item for key: \(key.prefix(8))...")
            return data
        case errSecItemNotFound:
            print("[KeychainManager] Item not found for key: \(key.prefix(8))...")
            return nil
        default:
            print("[KeychainManager] Failed to retrieve item for key: \(key.prefix(8))... Status: \(status)")
            throw KeychainError.from(status: status)
        }
    }
    
    /// Update existing data in keychain
    /// - Parameters:
    ///   - data: New data to store
    ///   - key: Unique identifier for the data
    /// - Throws: KeychainError if operation fails
    func update(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        switch status {
        case errSecSuccess:
            print("[KeychainManager] ✅ Successfully updated item for key: \(key.prefix(8))...")
        case errSecItemNotFound:
            // If item doesn't exist, create it
            try store(data, forKey: key)
        default:
            print("[KeychainManager] Failed to update item for key: \(key.prefix(8))... Status: \(status)")
            throw KeychainError.from(status: status)
        }
    }
    
    /// Delete data from keychain
    /// - Parameter key: Unique identifier for the data
    /// - Throws: KeychainError if operation fails (except for item not found)
    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        switch status {
        case errSecSuccess:
            print("[KeychainManager] ✅ Successfully deleted item for key: \(key.prefix(8))...")
        case errSecItemNotFound:
            print("[KeychainManager] Item not found for deletion: \(key.prefix(8))...")
            // Not an error - item doesn't exist
        default:
            print("[KeychainManager] Failed to delete item for key: \(key.prefix(8))... Status: \(status)")
            throw KeychainError.from(status: status)
        }
    }
    
    /// Check if data exists in keychain
    /// - Parameter key: Unique identifier for the data
    /// - Returns: true if item exists, false otherwise
    func exists(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Delete all items for this service (use with caution)
    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        switch status {
        case errSecSuccess, errSecItemNotFound:
            print("[KeychainManager] ✅ Successfully deleted all items for service")
        default:
            print("[KeychainManager] Failed to delete all items. Status: \(status)")
            throw KeychainError.from(status: status)
        }
    }
}

// MARK: - Keychain Error Types

enum KeychainError: LocalizedError {
    case duplicateItem
    case itemNotFound
    case userCancel
    case authFailed
    case unexpectedData
    case unhandledError(status: OSStatus)
    
    static func from(status: OSStatus) -> KeychainError {
        switch status {
        case errSecDuplicateItem:
            return .duplicateItem
        case errSecItemNotFound:
            return .itemNotFound
        case errSecAuthFailed:
            return .authFailed
        default:
            // Handle additional common keychain error codes
            switch status {
            case -128, -25293: // User canceled operation
                return .userCancel
            case -25300: // errSecItemNotFound (alternative code)
                return .itemNotFound
            case -25299: // errSecDuplicateItem (alternative code)
                return .duplicateItem
            default:
                return .unhandledError(status: status)
            }
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "Item already exists in keychain"
        case .itemNotFound:
            return "Item not found in keychain"
        case .userCancel:
            return "User canceled keychain operation"
        case .authFailed:
            return "Authentication failed for keychain access"
        case .unexpectedData:
            return "Unexpected data format in keychain"
        case .unhandledError(let status):
            return "Keychain operation failed with status: \(status)"
        }
    }
}

// MARK: - Secure Token Storage Extension

extension KeychainManager {
    
    /// Store Notion tokens securely
    /// - Parameter tokens: Array of NotionToken objects
    /// - Throws: KeychainError or encoding errors
    func storeNotionTokens(_ tokens: [NotionToken]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(tokens)
        try store(data, forKey: "notion_tokens")
    }
    
    /// Retrieve Notion tokens securely
    /// - Returns: Array of NotionToken objects, empty array if none found
    /// - Throws: KeychainError or decoding errors
    func retrieveNotionTokens() throws -> [NotionToken] {
        guard let data = try retrieve(forKey: "notion_tokens") else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([NotionToken].self, from: data)
    }
    
    /// Update stored Notion tokens
    /// - Parameter tokens: Array of NotionToken objects
    /// - Throws: KeychainError or encoding errors
    func updateNotionTokens(_ tokens: [NotionToken]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(tokens)
        try update(data, forKey: "notion_tokens")
    }
    
    /// Delete all stored Notion tokens
    /// - Throws: KeychainError
    func deleteNotionTokens() throws {
        try delete(forKey: "notion_tokens")
    }
    
    /// Check if Notion tokens exist
    /// - Returns: true if tokens exist in keychain
    func notionTokensExist() -> Bool {
        return exists(forKey: "notion_tokens")
    }
}
