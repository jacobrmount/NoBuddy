import XCTest
@testable import NoBuddy

@MainActor
class SecureTokenManagerTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: SecureTokenManager!
    var mockKeychain: MockKeychainManager!
    var testUserDefaults: UserDefaults!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create isolated UserDefaults for testing
        testUserDefaults = UserDefaults(suiteName: "com.nobuddy.test")!
        testUserDefaults.removePersistentDomain(forName: "com.nobuddy.test")
        
        // Create mock keychain
        mockKeychain = MockKeychainManager()
        
        // Create system under test
        sut = SecureTokenManager(userDefaults: testUserDefaults, keychainManager: mockKeychain)
    }
    
    override func tearDown() async throws {
        // Clean up
        testUserDefaults.removePersistentDomain(forName: "com.nobuddy.test")
        mockKeychain.reset()
        
        sut = nil
        mockKeychain = nil
        testUserDefaults = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Token Persistence Tests
    
    func testTokenPersistenceAcrossAppLaunches() async throws {
        // Given
        let token = createTestToken(name: "Test Workspace", tokenValue: "secret_test123456789012345678901234567890123456")
        
        // When - Save token
        let result = await sut.addToken(name: token.name, token: token.token)
        
        // Then - Verify save succeeded
        switch result {
        case .success(let savedToken):
            XCTAssertEqual(savedToken.name, token.name)
            XCTAssertEqual(savedToken.token, token.token)
        case .failure(let error):
            XCTFail("Failed to save token: \(error)")
        }
        
        // Simulate app restart by creating new manager instance
        let newManager = SecureTokenManager(userDefaults: testUserDefaults, keychainManager: mockKeychain)
        
        // Use expectation for async loading
        let expectation = XCTestExpectation(description: "Tokens loaded after restart")
        
        Task {
            await newManager.loadTokens()
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Verify token persists
        XCTAssertEqual(newManager.tokens.count, 1)
        XCTAssertEqual(newManager.tokens.first?.name, token.name)
        XCTAssertEqual(newManager.tokens.first?.token, token.token)
    }
    
    func testMultipleTokenPersistence() async throws {
        // Given
        let tokens = [
            createTestToken(name: "Workspace 1", tokenValue: "secret_test123456789012345678901234567890123456"),
            createTestToken(name: "Workspace 2", tokenValue: "secret_test223456789012345678901234567890123456"),
            createTestToken(name: "Workspace 3", tokenValue: "secret_test323456789012345678901234567890123456")
        ]
        
        // When - Save multiple tokens
        for token in tokens {
            let result = await sut.addToken(name: token.name, token: token.token)
            
            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("Failed to save token \(token.name): \(error)")
            }
        }
        
        // Then - Verify all tokens saved
        XCTAssertEqual(sut.tokens.count, 3)
        
        // Simulate app restart
        let newManager = SecureTokenManager(userDefaults: testUserDefaults, keychainManager: mockKeychain)
        await newManager.loadTokens()
        
        // Verify all tokens persist
        XCTAssertEqual(newManager.tokens.count, 3)
        XCTAssertTrue(newManager.tokens.contains { $0.name == "Workspace 1" })
        XCTAssertTrue(newManager.tokens.contains { $0.name == "Workspace 2" })
        XCTAssertTrue(newManager.tokens.contains { $0.name == "Workspace 3" })
    }
    
    // MARK: - Widget Extension Access Tests
    
    func testWidgetExtensionCanAccessMainAppTokens() async throws {
        // Given - Main app saves token
        let token = createTestToken(name: "Main App Token", tokenValue: "secret_test123456789012345678901234567890123456")
        _ = await sut.addToken(name: token.name, token: token.token)
        
        // When - Widget extension accesses same keychain (simulated with same mock)
        let widgetKeychain = MockKeychainManager()
        mockKeychain.shareStorageWith(widgetKeychain)
        
        let widgetManager = SecureTokenManager(userDefaults: testUserDefaults, keychainManager: widgetKeychain)
        await widgetManager.loadTokens()
        
        // Then - Widget can access the token
        XCTAssertEqual(widgetManager.tokens.count, 1)
        XCTAssertEqual(widgetManager.tokens.first?.name, token.name)
    }
    
    func testAppGroupSharing() async throws {
        // Given
        let token = createTestToken(name: "Shared Token", tokenValue: "secret_test123456789012345678901234567890123456")
        
        // When - Save token with app group
        let appGroupDefaults = UserDefaults(suiteName: "group.com.nobuddy.app")
        let appGroupManager = SecureTokenManager(userDefaults: appGroupDefaults ?? testUserDefaults, keychainManager: mockKeychain)
        _ = await appGroupManager.addToken(name: token.name, token: token.token)
        
        // Then - Verify token is accessible via app group
        XCTAssertEqual(mockKeychain.storeCallCount, 1)
        XCTAssertTrue(mockKeychain.notionTokensExist())
    }
    
    // MARK: - Migration Tests
    
    func testUserDefaultsToKeychainMigration() async throws {
        // Given - Legacy tokens in UserDefaults
        let legacyTokens = [
            NotionToken(name: "Legacy 1", token: "secret_legacy123456789012345678901234567890123"),
            NotionToken(name: "Legacy 2", token: "secret_legacy223456789012345678901234567890123")
        ]
        
        // Store in UserDefaults (simulating old storage)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let legacyData = try encoder.encode(legacyTokens)
        testUserDefaults.set(legacyData, forKey: "saved_tokens")
        testUserDefaults.set(false, forKey: "tokens_migrated_to_keychain")
        
        // When - Create new manager (should trigger migration)
        let expectation = XCTestExpectation(description: "Migration completed")
        
        sut = SecureTokenManager(userDefaults: testUserDefaults, keychainManager: mockKeychain)
        
        Task {
            await sut.loadTokens()
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Then - Verify migration completed
        XCTAssertTrue(testUserDefaults.bool(forKey: "tokens_migrated_to_keychain"))
        XCTAssertNil(testUserDefaults.data(forKey: "saved_tokens"))
        XCTAssertEqual(sut.tokens.count, 2)
        XCTAssertTrue(mockKeychain.notionTokensExist())
    }
    
    func testMigrationOnlyHappensOnce() async throws {
        // Given - Already migrated
        testUserDefaults.set(true, forKey: "tokens_migrated_to_keychain")
        
        // Create legacy data that shouldn't be migrated
        let legacyToken = NotionToken(name: "Should Not Migrate", token: "secret_nomigrate3456789012345678901234567890123")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let legacyData = try encoder.encode([legacyToken])
        testUserDefaults.set(legacyData, forKey: "saved_tokens")
        
        // When - Create manager
        await sut.loadTokens()
        
        // Then - No migration should occur
        XCTAssertEqual(sut.tokens.count, 0)
        XCTAssertNotNil(testUserDefaults.data(forKey: "saved_tokens")) // Legacy data still there
    }
    
    // MARK: - Encryption Verification Tests
    
    func testTokensAreEncryptedInKeychain() async throws {
        // Given
        let token = createTestToken(name: "Encrypted Token", tokenValue: "secret_encrypted456789012345678901234567890123")
        
        // When
        _ = await sut.addToken(name: token.name, token: token.token)
        
        // Then - Verify data in keychain is not plain text
        let rawStorage = mockKeychain.getRawStorage()
        XCTAssertFalse(rawStorage.isEmpty)
        
        if let storedData = rawStorage["notion_tokens"] {
            let dataString = String(data: storedData, encoding: .utf8) ?? ""
            // Token value should not appear in plain text in the stored data
            XCTAssertFalse(dataString.contains(token.token))
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testKeychainLockedErrorHandling() async throws {
        // Given - Keychain is locked
        mockKeychain.isLocked = true
        
        // When - Try to add token
        let token = createTestToken(name: "Test", tokenValue: "secret_test123456789012345678901234567890123456")
        let result = await sut.addToken(name: token.name, token: token.token)
        
        // Then - Should fail with appropriate error
        switch result {
        case .success:
            XCTFail("Should have failed with locked keychain")
        case .failure(let error):
            if case .keychainError(let keychainError) = error {
                XCTAssertEqual(keychainError, .authFailed)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testAccessDeniedScenario() async throws {
        // Given - Keychain will throw access denied
        mockKeychain.shouldThrowError = true
        mockKeychain.errorToThrow = .authFailed
        
        // When - Try to load tokens
        await sut.loadTokens()
        
        // Then - Should handle error gracefully
        XCTAssertNotNil(sut.error)
        XCTAssertEqual(sut.tokens.count, 0)
    }
    
    func testStorageLimitExceeded() async throws {
        // Given - Set very low storage limit
        mockKeychain.storageLimit = 100 // 100 bytes
        
        // When - Try to save large token
        let largeToken = createTestToken(
            name: String(repeating: "Large Name ", count: 50),
            tokenValue: "secret_test123456789012345678901234567890123456"
        )
        let result = await sut.addToken(name: largeToken.name, token: largeToken.token)
        
        // Then - Should fail with storage error
        switch result {
        case .success:
            XCTFail("Should have failed with storage limit")
        case .failure(let error):
            XCTAssertNotNil(error)
        }
    }
    
    func testMalformedDataHandling() async throws {
        // Given - Inject malformed data
        mockKeychain.injectMalformedData(forKey: "notion_tokens")
        
        // When - Try to load tokens
        await sut.loadTokens()
        
        // Then - Should handle gracefully
        XCTAssertNotNil(sut.error)
        XCTAssertEqual(sut.tokens.count, 0)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentTokenOperations() async throws {
        // Given
        let tokenCount = 10
        let expectation = XCTestExpectation(description: "All concurrent operations completed")
        expectation.expectedFulfillmentCount = tokenCount
        
        // When - Perform concurrent operations
        await withTaskGroup(of: Result<NotionToken, TokenError>.self) { group in
            for i in 0..<tokenCount {
                group.addTask {
                    let token = self.createTestToken(
                        name: "Concurrent \(i)",
                        tokenValue: "secret_test\(i)23456789012345678901234567890123456"
                    )
                    let result = await self.sut.addToken(name: token.name, token: token.token)
                    expectation.fulfill()
                    return result
                }
            }
            
            // Collect results
            var successCount = 0
            for await result in group {
                switch result {
                case .success:
                    successCount += 1
                case .failure(let error):
                    print("Concurrent operation failed: \(error)")
                }
            }
            
            // Then - All operations should succeed
            XCTAssertEqual(successCount, tokenCount)
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Verify final state
        XCTAssertEqual(sut.tokens.count, tokenCount)
    }
    
    func testConcurrentReadWriteOperations() async throws {
        // Given - Pre-populate some tokens
        for i in 0..<5 {
            let token = createTestToken(
                name: "Initial \(i)",
                tokenValue: "secret_init\(i)23456789012345678901234567890123456"
            )
            _ = await sut.addToken(name: token.name, token: token.token)
        }
        
        // When - Concurrent reads and writes
        let expectation = XCTestExpectation(description: "Concurrent read/write completed")
        expectation.expectedFulfillmentCount = 20
        
        await withTaskGroup(of: Void.self) { group in
            // Add more tokens
            for i in 0..<10 {
                group.addTask {
                    let token = self.createTestToken(
                        name: "New \(i)",
                        tokenValue: "secret_new\(i)23456789012345678901234567890123456"
                    )
                    _ = await self.sut.addToken(name: token.name, token: token.token)
                    expectation.fulfill()
                }
            }
            
            // Read tokens
            for _ in 0..<10 {
                group.addTask {
                    await self.sut.loadTokens()
                    expectation.fulfill()
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Then - State should be consistent
        XCTAssertEqual(sut.tokens.count, 15) // 5 initial + 10 new
    }
    
    // MARK: - Token Validation Tests
    
    func testValidTokenFormat() async throws {
        // Given - Valid token formats
        let validTokens = [
            ("Standard Token", "secret_test123456789012345678901234567890123456"),
            ("Internal Token", "ntn_test12345678901234567890123456789012345678901")
        ]
        
        // When/Then - All should save successfully
        for (name, tokenValue) in validTokens {
            let result = await sut.addToken(name: name, token: tokenValue)
            
            switch result {
            case .success:
                break // Expected
            case .failure(let error):
                XCTFail("Valid token '\(name)' failed: \(error)")
            }
        }
        
        XCTAssertEqual(sut.tokens.count, validTokens.count)
    }
    
    func testInvalidTokenFormat() async throws {
        // Given - Invalid token formats
        let invalidTokens = [
            "invalid_token",
            "secret_short",
            "wrong_prefix123456789012345678901234567890123456",
            "",
            "secret_" + String(repeating: "a", count: 100) // Too long
        ]
        
        // When/Then - All should fail with invalidFormat error
        for tokenValue in invalidTokens {
            let result = await sut.addToken(name: "Test", token: tokenValue)
            
            switch result {
            case .success:
                XCTFail("Invalid token should have failed: \(tokenValue)")
            case .failure(let error):
                XCTAssertEqual(error, .invalidFormat)
            }
        }
    }
    
    func testDuplicateTokenPrevention() async throws {
        // Given - Add a token
        let token = createTestToken(name: "Original", tokenValue: "secret_test123456789012345678901234567890123456")
        _ = await sut.addToken(name: token.name, token: token.token)
        
        // When - Try to add same token with different name
        let result = await sut.addToken(name: "Duplicate", token: token.token)
        
        // Then - Should fail with duplicate error
        switch result {
        case .success:
            XCTFail("Duplicate token should have been rejected")
        case .failure(let error):
            XCTAssertEqual(error, .duplicateToken)
        }
        
        XCTAssertEqual(sut.tokens.count, 1)
    }
    
    // MARK: - Security Validation Tests
    
    func testSecureStorageValidation() async throws {
        // Given - Fresh setup with migration completed
        testUserDefaults.set(true, forKey: "tokens_migrated_to_keychain")
        
        // When - Validate secure storage
        let isSecure = sut.validateSecureStorage()
        
        // Then
        XCTAssertTrue(isSecure)
    }
    
    func testInsecureStorageDetection() async throws {
        // Given - Insecure data in UserDefaults
        testUserDefaults.set("insecure_data".data(using: .utf8), forKey: "saved_tokens")
        testUserDefaults.set(false, forKey: "tokens_migrated_to_keychain")
        
        // When - Validate secure storage
        let isSecure = sut.validateSecureStorage()
        
        // Then
        XCTAssertFalse(isSecure)
    }
    
    // MARK: - Helper Methods
    
    private func createTestToken(name: String, tokenValue: String) -> NotionToken {
        return NotionToken(name: name, token: tokenValue)
    }
}
