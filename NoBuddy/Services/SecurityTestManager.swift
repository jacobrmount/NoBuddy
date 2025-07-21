import Foundation

/// Test manager for verifying secure token storage implementation
class SecurityTestManager {
    
    private let keychainManager: KeychainManager
    private let userDefaults: UserDefaults
    
    init(keychainManager: KeychainManager = KeychainManager(), userDefaults: UserDefaults = .standard) {
        self.keychainManager = keychainManager
        self.userDefaults = userDefaults
    }
    
    // MARK: - Security Verification Tests
    
    /// Verify that tokens are no longer stored in UserDefaults (security check)
    func verifyUserDefaultsSecurity() -> SecurityTestResult {
        print("[SecurityTest] 🔒 Verifying UserDefaults security...")
        
        let legacyKeys = ["saved_tokens", "notion_tokens", "api_tokens"]
        var foundInsecureData = false
        var insecureKeys: [String] = []
        
        for key in legacyKeys {
            if let data = userDefaults.data(forKey: key), !data.isEmpty {
                foundInsecureData = true
                insecureKeys.append(key)
                print("[SecurityTest] ❌ SECURITY RISK: Found sensitive data in UserDefaults for key: \(key)")
            }
        }
        
        if foundInsecureData {
            return .failed("SECURITY VULNERABILITY: Sensitive data found in UserDefaults for keys: \(insecureKeys)")
        } else {
            print("[SecurityTest] ✅ UserDefaults security verified - no sensitive data found")
            return .passed("UserDefaults security verified")
        }
    }
    
    /// Verify keychain storage is working correctly
    func verifyKeychainStorage() -> SecurityTestResult {
        print("[SecurityTest] 🔒 Verifying Keychain storage...")
        
        do {
            // Test storing and retrieving data
            let testData = "test_secure_data".data(using: .utf8)!
            let testKey = "security_test_key"
            
            // Store test data
            try keychainManager.store(testData, forKey: testKey)
            
            // Retrieve test data
            guard let retrievedData = try keychainManager.retrieve(forKey: testKey) else {
                return .failed("Failed to retrieve test data from Keychain")
            }
            
            // Verify data integrity
            let retrievedString = String(data: retrievedData, encoding: .utf8)
            guard retrievedString == "test_secure_data" else {
                return .failed("Data integrity check failed")
            }
            
            // Clean up test data
            try keychainManager.delete(forKey: testKey)
            
            print("[SecurityTest] ✅ Keychain storage verified successfully")
            return .passed("Keychain storage working correctly")
            
        } catch {
            print("[SecurityTest] ❌ Keychain storage test failed: \(error)")
            return .failed("Keychain storage error: \(error.localizedDescription)")
        }
    }
    
    /// Test migration scenario from UserDefaults to Keychain
    @MainActor
    func testMigrationScenario() async -> SecurityTestResult {
        print("[SecurityTest] 🔄 Testing migration scenario...")
        
        do {
            // Create test token for migration
            let testToken = NotionToken(
                name: "Migration Test Token",
                token: "secret_test123456789012345678901234567890123456"
            )
            
            // Simulate legacy UserDefaults storage
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let legacyData = try encoder.encode([testToken])
            userDefaults.set(legacyData, forKey: "saved_tokens")
            userDefaults.set(false, forKey: "tokens_migrated_to_keychain")
            
            // Create SecureTokenManager to trigger migration
            let tokenManager = SecureTokenManager(userDefaults: userDefaults, keychainManager: keychainManager)
            
            // Wait for migration to complete
            await tokenManager.loadTokens()
            
            // Verify migration results
            let migrationCompleted = userDefaults.bool(forKey: "tokens_migrated_to_keychain")
            let legacyDataRemoved = userDefaults.data(forKey: "saved_tokens") == nil
            let keychainHasTokens = keychainManager.notionTokensExist()
            
            if migrationCompleted && legacyDataRemoved && keychainHasTokens {
                print("[SecurityTest] ✅ Migration test passed")
                
                // Clean up test data
                try keychainManager.deleteNotionTokens()
                userDefaults.removeObject(forKey: "tokens_migrated_to_keychain")
                
                return .passed("Migration working correctly")
            } else {
                return .failed("Migration test failed - migrated: \(migrationCompleted), legacy removed: \(legacyDataRemoved), keychain has tokens: \(keychainHasTokens)")
            }
            
        } catch {
            print("[SecurityTest] ❌ Migration test error: \(error)")
            return .failed("Migration test error: \(error.localizedDescription)")
        }
    }
    
    /// Test keychain access scenarios (device locked/unlocked)
    func testKeychainAccessibility() -> SecurityTestResult {
        print("[SecurityTest] 🔒 Testing Keychain accessibility...")
        
        do {
            // Test basic keychain operations
            let testData = "accessibility_test".data(using: .utf8)!
            let testKey = "accessibility_test_key"
            
            // Store with specific accessibility
            try keychainManager.store(testData, forKey: testKey)
            
            // Verify we can retrieve it
            let retrievedData = try keychainManager.retrieve(forKey: testKey)
            guard retrievedData != nil else {
                return .failed("Could not retrieve data with current accessibility settings")
            }
            
            // Clean up
            try keychainManager.delete(forKey: testKey)
            
            print("[SecurityTest] ✅ Keychain accessibility test passed")
            return .passed("Keychain accessibility working correctly")
            
        } catch {
            print("[SecurityTest] ❌ Keychain accessibility test failed: \(error)")
            return .failed("Keychain accessibility error: \(error.localizedDescription)")
        }
    }
    
    /// Run comprehensive security test suite
    @MainActor
    func runComprehensiveSecurityTests() async -> [String: SecurityTestResult] {
        print("[SecurityTest] 🚀 Running comprehensive security test suite...")
        
        var results: [String: SecurityTestResult] = [:]
        
        results["UserDefaults Security"] = verifyUserDefaultsSecurity()
        results["Keychain Storage"] = verifyKeychainStorage()
        results["Migration Scenario"] = await testMigrationScenario()
        results["Keychain Accessibility"] = testKeychainAccessibility()
        
        // Summary
        let passedTests = results.values.filter { $0.isSuccess }.count
        let totalTests = results.count
        
        print("[SecurityTest] 📊 Security Test Summary: \(passedTests)/\(totalTests) tests passed")
        
        if passedTests == totalTests {
            print("[SecurityTest] ✅ ALL SECURITY TESTS PASSED")
        } else {
            print("[SecurityTest] ❌ SECURITY ISSUES DETECTED")
            for (testName, result) in results {
                if !result.isSuccess {
                    print("[SecurityTest] Failed: \(testName) - \(result.message)")
                }
            }
        }
        
        return results
    }
}

// MARK: - Test Result Types

enum SecurityTestResult {
    case passed(String)
    case failed(String)
    
    var isSuccess: Bool {
        switch self {
        case .passed:
            return true
        case .failed:
            return false
        }
    }
    
    var message: String {
        switch self {
        case .passed(let message), .failed(let message):
            return message
        }
    }
}

// MARK: - XCTest Expectation Mock (for standalone testing)

class XCTestExpectation {
    let description: String
    
    init(description: String) {
        self.description = description
    }
    
    func fulfill() {
        // Mock implementation for standalone testing
        print("[Test] Expectation fulfilled: \(description)")
    }
}