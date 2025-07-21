import Foundation
@testable import NoBuddy

/// Mock implementation of KeychainManager for testing purposes
class MockKeychainManager: KeychainManager {
    
    // MARK: - Properties
    
    /// In-memory storage to simulate keychain
    private var storage: [String: Data] = [:]
    
    /// Simulate keychain access errors
    var shouldThrowError: Bool = false
    var errorToThrow: KeychainError = .authFailed
    
    /// Track method calls for verification
    var storeCallCount = 0
    var retrieveCallCount = 0
    var updateCallCount = 0
    var deleteCallCount = 0
    var deleteAllCallCount = 0
    
    /// Simulate keychain locked state
    var isLocked: Bool = false
    
    /// Simulate storage limit
    var storageLimit: Int = 1_000_000 // 1MB limit
    var currentStorageSize: Int {
        return storage.values.reduce(0) { $0 + $1.count }
    }
    
    // MARK: - Initialization
    
    override init(service: String = "com.nobuddy.app.test") {
        super.init(service: service)
    }
    
    // MARK: - Override Methods
    
    override func store(_ data: Data, forKey key: String) throws {
        storeCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if isLocked {
            throw KeychainError.authFailed
        }
        
        // Check storage limit
        if currentStorageSize + data.count > storageLimit {
            throw KeychainError.unhandledError(status: -34)
        }
        
        storage[key] = data
    }
    
    override func retrieve(forKey key: String) throws -> Data? {
        retrieveCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if isLocked {
            throw KeychainError.authFailed
        }
        
        return storage[key]
    }
    
    override func update(_ data: Data, forKey key: String) throws {
        updateCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if isLocked {
            throw KeychainError.authFailed
        }
        
        // Check storage limit
        let existingSize = storage[key]?.count ?? 0
        if currentStorageSize - existingSize + data.count > storageLimit {
            throw KeychainError.unhandledError(status: -34)
        }
        
        storage[key] = data
    }
    
    override func delete(forKey key: String) throws {
        deleteCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if isLocked {
            throw KeychainError.authFailed
        }
        
        storage.removeValue(forKey: key)
    }
    
    override func exists(forKey key: String) -> Bool {
        if isLocked {
            return false
        }
        
        return storage[key] != nil
    }
    
    override func deleteAll() throws {
        deleteAllCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if isLocked {
            throw KeychainError.authFailed
        }
        
        storage.removeAll()
    }
    
    // MARK: - Test Helpers
    
    /// Reset all mock state
    func reset() {
        storage.removeAll()
        shouldThrowError = false
        errorToThrow = .authFailed
        isLocked = false
        storeCallCount = 0
        retrieveCallCount = 0
        updateCallCount = 0
        deleteCallCount = 0
        deleteAllCallCount = 0
    }
    
    /// Simulate app group sharing by copying storage
    func shareStorageWith(_ otherMock: MockKeychainManager) {
        otherMock.storage = self.storage
    }
    
    /// Get raw storage for verification
    func getRawStorage() -> [String: Data] {
        return storage
    }
    
    /// Inject malformed data for testing
    func injectMalformedData(forKey key: String) {
        storage[key] = "malformed".data(using: .utf8)!
    }
}
