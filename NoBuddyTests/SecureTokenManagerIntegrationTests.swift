import XCTest
@testable import NoBuddy

/// Integration tests for SecureTokenManager focusing on app group and widget scenarios
@MainActor
class SecureTokenManagerIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    var mainAppManager: SecureTokenManager!
    var widgetManager: SecureTokenManager!
    var sharedKeychain: MockKeychainManager!
    var appGroupDefaults: UserDefaults!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create shared keychain to simulate app group
        sharedKeychain = MockKeychainManager(service: "group.com.nobuddy.app")
        
        // Create app group UserDefaults
        appGroupDefaults = UserDefaults(suiteName: "group.com.nobuddy.app.test") ?? UserDefaults.standard
        appGroupDefaults.removePersistentDomain(forName: "group.com.nobuddy.app.test")
        
        // Create managers for main app and widget
        mainAppManager = SecureTokenManager(userDefaults: appGroupDefaults, keychainManager: sharedKeychain)
        widgetManager = SecureTokenManager(userDefaults: appGroupDefaults, keychainManager: sharedKeychain)
    }
    
    override func tearDown() async throws {
        appGroupDefaults.removePersistentDomain(forName: "group.com.nobuddy.app.test")
        sharedKeychain.reset()
        
        mainAppManager = nil
        widgetManager = nil
        sharedKeychain = nil
        appGroupDefaults = nil
        
        try await super.tearDown()
    }
    
    // MARK: - App Group Tests
    
    func testMainAppToWidgetTokenSharing() async throws {
        // Given - Main app saves tokens
        let tokens = [
            NotionToken(name: "Personal Workspace", token: "secret_pers123456789012345678901234567890123456"),
            NotionToken(name: "Work Workspace", token: "secret_work123456789012345678901234567890123456")
        ]
        
        for token in tokens {
            let result = await mainAppManager.addToken(name: token.name, token: token.token)
            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("Failed to add token in main app: \(error)")
            }
        }
        
        // When - Widget loads tokens
        await widgetManager.loadTokens()
        
        // Then - Widget should see the same tokens
        XCTAssertEqual(widgetManager.tokens.count, 2)
        XCTAssertTrue(widgetManager.tokens.contains { $0.name == "Personal Workspace" })
        XCTAssertTrue(widgetManager.tokens.contains { $0.name == "Work Workspace" })
    }
    
    func testWidgetToMainAppTokenUpdates() async throws {
        // Given - Initial token in main app
        let initialToken = NotionToken(name: "Initial Token", token: "secret_init123456789012345678901234567890123456")
        _ = await mainAppManager.addToken(name: initialToken.name, token: initialToken.token)
        
        // When - Widget adds a new token
        let widgetToken = NotionToken(name: "Widget Added", token: "secret_widg123456789012345678901234567890123456")
        _ = await widgetManager.addToken(name: widgetToken.name, token: widgetToken.token)
        
        // Then - Main app should see both tokens
        await mainAppManager.loadTokens()
        XCTAssertEqual(mainAppManager.tokens.count, 2)
        XCTAssertTrue(mainAppManager.tokens.contains { $0.name == "Initial Token" })
        XCTAssertTrue(mainAppManager.tokens.contains { $0.name == "Widget Added" })
    }
    
    func testConcurrentAccessFromMultipleExtensions() async throws {
        // Simulate multiple extensions accessing tokens simultaneously
        let expectation = XCTestExpectation(description: "All concurrent operations completed")
        expectation.expectedFulfillmentCount = 20
        
        // Create additional managers to simulate more extensions
        let notificationManager = SecureTokenManager(userDefaults: appGroupDefaults, keychainManager: sharedKeychain)
        let actionManager = SecureTokenManager(userDefaults: appGroupDefaults, keychainManager: sharedKeychain)
        
        await withTaskGroup(of: Void.self) { group in
            // Main app operations
            for i in 0..<5 {
                group.addTask {
                    let token = NotionToken(
                        name: "Main \(i)",
                        token: "secret_main\(i)23456789012345678901234567890123456"
                    )
                    _ = await self.mainAppManager.addToken(name: token.name, token: token.token)
                    expectation.fulfill()
                }
            }
            
            // Widget operations
            for i in 0..<5 {
                group.addTask {
                    let token = NotionToken(
                        name: "Widget \(i)",
                        token: "secret_widg\(i)23456789012345678901234567890123456"
                    )
                    _ = await self.widgetManager.addToken(name: token.name, token: token.token)
                    expectation.fulfill()
                }
            }
            
            // Notification extension reads
            for _ in 0..<5 {
                group.addTask {
                    await notificationManager.loadTokens()
                    expectation.fulfill()
                }
            }
            
            // Action extension reads
            for _ in 0..<5 {
                group.addTask {
                    await actionManager.loadTokens()
                    expectation.fulfill()
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Verify all managers see the same tokens
        await mainAppManager.loadTokens()
        await widgetManager.loadTokens()
        await notificationManager.loadTokens()
        await actionManager.loadTokens()
        
        let expectedCount = 10 // 5 from main + 5 from widget
        XCTAssertEqual(mainAppManager.tokens.count, expectedCount)
        XCTAssertEqual(widgetManager.tokens.count, expectedCount)
        XCTAssertEqual(notificationManager.tokens.count, expectedCount)
        XCTAssertEqual(actionManager.tokens.count, expectedCount)
    }
    
    // MARK: - Migration Scenario Tests
    
    func testMigrationAcrossAppGroup() async throws {
        // Given - Legacy data in main app's UserDefaults (not app group)
        let mainAppDefaults = UserDefaults.standard
        let legacyTokens = [
            NotionToken(name: "Legacy Main 1", token: "secret_lgcy123456789012345678901234567890123456"),
            NotionToken(name: "Legacy Main 2", token: "secret_lgcy223456789012345678901234567890123456")
        ]
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let legacyData = try encoder.encode(legacyTokens)
        mainAppDefaults.set(legacyData, forKey: "saved_tokens")
        mainAppDefaults.set(false, forKey: "tokens_migrated_to_keychain")
        
        // Create manager with main app defaults for migration
        let migratingManager = SecureTokenManager(userDefaults: mainAppDefaults, keychainManager: sharedKeychain)
        
        // When - Trigger migration
        await migratingManager.loadTokens()
        
        // Then - Tokens should be migrated and accessible from widget
        await widgetManager.loadTokens()
        XCTAssertEqual(widgetManager.tokens.count, 2)
        
        // Clean up
        mainAppDefaults.removeObject(forKey: "saved_tokens")
        mainAppDefaults.removeObject(forKey: "tokens_migrated_to_keychain")
    }
    
    // MARK: - Real-World Scenario Tests
    
    func testWidgetRefreshScenario() async throws {
        // Simulate a typical widget refresh flow
        
        // 1. Main app has tokens
        let workspace1 = NotionToken(name: "Personal", token: "secret_pers123456789012345678901234567890123456")
        let workspace2 = NotionToken(name: "Work", token: "secret_work123456789012345678901234567890123456")
        
        _ = await mainAppManager.addToken(name: workspace1.name, token: workspace1.token)
        _ = await mainAppManager.addToken(name: workspace2.name, token: workspace2.token)
        
        // 2. Widget loads tokens for display
        await widgetManager.loadTokens()
        XCTAssertEqual(widgetManager.tokens.count, 2)
        
        // 3. User deletes a token in main app
        let deleteResult = await mainAppManager.deleteToken(id: mainAppManager.tokens[0].id)
        switch deleteResult {
        case .success:
            break
        case .failure(let error):
            XCTFail("Failed to delete token: \(error)")
        }
        
        // 4. Widget refreshes and should see updated list
        await widgetManager.loadTokens()
        XCTAssertEqual(widgetManager.tokens.count, 1)
    }
    
    func testExtensionMemoryPressure() async throws {
        // Simulate extension under memory pressure
        
        // Add many tokens
        for i in 0..<50 {
            let token = NotionToken(
                name: "Workspace \(i)",
                token: "secret_test\(i)23456789012345678901234567890123456"
            )
            _ = await mainAppManager.addToken(name: token.name, token: token.token)
        }
        
        // Widget loads under simulated memory pressure
        // Set a small storage limit to simulate memory constraints
        sharedKeychain.storageLimit = 50_000 // 50KB
        
        // Widget should still be able to read existing tokens
        await widgetManager.loadTokens()
        XCTAssertEqual(widgetManager.tokens.count, 50)
        
        // But adding new tokens might fail
        let newToken = NotionToken(
            name: "Memory Test",
            token: "secret_memo123456789012345678901234567890123456"
        )
        let result = await widgetManager.addToken(name: newToken.name, token: newToken.token)
        
        switch result {
        case .success:
            // Might succeed if there's still space
            break
        case .failure:
            // Expected when storage is full
            break
        }
    }
    
    // MARK: - Performance Tests
    
    func testWidgetLoadPerformance() throws {
        // Measure widget token loading performance
        
        // Pre-populate with tokens
        let tokens = (0..<100).map { i in
            NotionToken(
                name: "Token \(i)",
                token: "secret_perf\(i)23456789012345678901234567890123456"
            )
        }
        
        // Store tokens synchronously for setup
        try sharedKeychain.storeNotionTokens(tokens)
        
        // Measure widget load time
        measure {
            let expectation = XCTestExpectation(description: "Widget loaded tokens")
            
            Task {
                await widgetManager.loadTokens()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyStateAcrossExtensions() async throws {
        // Verify all extensions handle empty state correctly
        await mainAppManager.loadTokens()
        await widgetManager.loadTokens()
        
        XCTAssertEqual(mainAppManager.tokens.count, 0)
        XCTAssertEqual(widgetManager.tokens.count, 0)
        XCTAssertNil(mainAppManager.error)
        XCTAssertNil(widgetManager.error)
    }
    
    func testPartialMigrationRecovery() async throws {
        // Simulate a partial migration that was interrupted
        
        // Set migration flag but leave legacy data
        appGroupDefaults.set(true, forKey: "tokens_migrated_to_keychain")
        
        let legacyTokens = [NotionToken(name: "Orphaned", token: "secret_orph123456789012345678901234567890123456")]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let legacyData = try encoder.encode(legacyTokens)
        appGroupDefaults.set(legacyData, forKey: "saved_tokens")
        
        // Both managers should handle this gracefully
        await mainAppManager.loadTokens()
        await widgetManager.loadTokens()
        
        // Should not crash and should have no tokens (migration already marked complete)
        XCTAssertEqual(mainAppManager.tokens.count, 0)
        XCTAssertEqual(widgetManager.tokens.count, 0)
    }
}
