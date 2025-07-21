import Foundation

// MARK: - Security Validation Extensions

extension SecureTokenManager {
    
    /// Quick security check for development builds
    func performSecurityCheck() {
        #if DEBUG
        print("\n🔒 SECURITY CHECK - NoBuddy Token Storage")
        print("==========================================")
        
        let isSecure = validateSecureStorage()
        
        if isSecure {
            print("✅ SECURITY STATUS: SECURE")
            print("✅ Tokens are stored in iOS Keychain")
            print("✅ No sensitive data in UserDefaults")
            print("✅ Migration completed successfully")
        } else {
            print("❌ SECURITY STATUS: VULNERABLE")
            print("❌ Immediate action required!")
            print("❌ Check SecureTokenManager implementation")
        }
        
        print("==========================================\n")
        #endif
    }
}

// MARK: - UserDefaults Security Helpers

extension UserDefaults {
    
    /// Check for any remaining insecure token data (debug only)
    func auditTokenSecurity() -> [String: Any] {
        #if DEBUG
        var findings: [String: Any] = [:]
        
        let suspiciousKeys = ["saved_tokens", "notion_tokens", "api_tokens", "tokens", "auth_tokens"]
        
        for key in suspiciousKeys {
            if let data = data(forKey: key), !data.isEmpty {
                findings[key] = "FOUND SENSITIVE DATA - Size: \(data.count) bytes"
            }
        }
        
        return findings
        #else
        return [:]
        #endif
    }
    
    /// Remove any remaining insecure token data (use with caution)
    func cleanupInsecureTokenData() {
        #if DEBUG
        let keysToRemove = ["saved_tokens", "notion_tokens", "api_tokens", "tokens", "auth_tokens"]
        
        for key in keysToRemove {
            if data(forKey: key) != nil {
                print("[UserDefaults] Removing insecure data for key: \(key)")
                removeObject(forKey: key)
            }
        }
        #endif
    }
}

// MARK: - Keychain Security Verification

extension KeychainManager {
    
    /// Verify keychain security configuration (debug only)
    func verifySecurityConfiguration() -> Bool {
        #if DEBUG
        print("[KeychainManager] Verifying security configuration...")
        
        // Test that we can store and retrieve data
        do {
            let testData = "security_test".data(using: .utf8)!
            let testKey = "config_test"
            
            try store(testData, forKey: testKey)
            let retrieved = try retrieve(forKey: testKey)
            try delete(forKey: testKey)
            
            let success = retrieved != nil
            print("[KeychainManager] Security configuration: \(success ? "✅ VALID" : "❌ INVALID")")
            return success
            
        } catch {
            print("[KeychainManager] Security configuration test failed: \(error)")
            return false
        }
        #else
        return true
        #endif
    }
}

// MARK: - Security Constants

struct SecurityConstants {
    
    /// Security attributes used for keychain storage
    static let keychainAccessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    
    /// Service identifier for keychain items
    static let keychainService = Bundle.main.bundleIdentifier ?? "com.nobuddy.app"
    
    /// Security validation messages
    struct Messages {
        static let migrationComplete = "Token migration to secure storage completed"
        static let migrationFailed = "Token migration to secure storage failed"
        static let keychainStoreSuccess = "Tokens successfully stored in secure keychain"
        static let keychainStoreFailed = "Failed to store tokens in secure keychain"
        static let insecureDataFound = "SECURITY ALERT: Insecure token data found"
        static let securityValidationPassed = "Security validation passed"
        static let securityValidationFailed = "Security validation failed"
    }
}

// MARK: - Development Security Utilities

#if DEBUG
class SecurityDevUtils {
    
    /// Run comprehensive security audit (development only)
    @MainActor
    static func runSecurityAudit() async {
        print("\n🔒 COMPREHENSIVE SECURITY AUDIT")
        print("=====================================")
        
        // Check UserDefaults
        let userDefaultsFindings = UserDefaults.standard.auditTokenSecurity()
        if userDefaultsFindings.isEmpty {
            print("✅ UserDefaults: No insecure data found")
        } else {
            print("❌ UserDefaults: SECURITY ISSUES FOUND:")
            for (key, value) in userDefaultsFindings {
                print("   - \(key): \(value)")
            }
        }
        
        // Check Keychain
        let keychain = KeychainManager()
        let keychainValid = keychain.verifySecurityConfiguration()
        print(keychainValid ? "✅ Keychain: Configuration valid" : "❌ Keychain: Configuration invalid")
        
        // Check SecureTokenManager
        let tokenManager = SecureTokenManager()
        let storageSecure = tokenManager.validateSecureStorage()
        print(storageSecure ? "✅ TokenManager: Secure storage validated" : "❌ TokenManager: Security validation failed")
        
        print("=====================================\n")
    }
    
    /// Force clean migration (development only - use with extreme caution)
    static func forceCleanMigration() {
        print("⚠️  FORCING CLEAN MIGRATION - THIS WILL DELETE ALL TOKENS")
        
        // Clear UserDefaults
        UserDefaults.standard.cleanupInsecureTokenData()
        UserDefaults.standard.removeObject(forKey: "tokens_migrated_to_keychain")
        
        // Clear Keychain
        let keychain = KeychainManager()
        try? keychain.deleteNotionTokens()
        
        print("✅ Clean migration completed - all token data removed")
    }
}
#endif
