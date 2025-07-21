import Foundation
import XCTest
@testable import NoBuddy

/// Test configuration and helper utilities for SecureTokenManager tests
struct TestConfiguration {
    
    // MARK: - Test Constants
    
    /// Valid test token formats
    static let validTokens = [
        (name: "Standard Secret Token", value: "secret_test123456789012345678901234567890123456"),
        (name: "Internal Notion Token", value: "ntn_test12345678901234567890123456789012345678901"),
        (name: "Another Valid Token", value: "secret_abcd23456789012345678901234567890123456")
    ]
    
    /// Invalid token formats for testing
    static let invalidTokens = [
        "invalid_token_format",
        "secret_tooshort",
        "wrong_prefix123456789012345678901234567890123456",
        "",
        "   ",
        "secret_" + String(repeating: "x", count: 100),
        "ntn_wronglength",
        "SECRET_UPPERCASE3456789012345678901234567890123456"
    ]
    
    /// Test app group identifier
    static let testAppGroupIdentifier = "group.com.nobuddy.app.test"
    
    /// Test service identifier for keychain
    static let testKeychainService = "com.nobuddy.app.test"
    
    // MARK: - Helper Methods
    
    /// Create a test UserDefaults instance
    static func createTestUserDefaults() -> UserDefaults {
        let suiteName = "com.nobuddy.test.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }
    
    /// Create test tokens with unique values
    static func createTestTokens(count: Int, prefix: String = "Test") -> [NotionToken] {
        return (0..<count).map { i in
            NotionToken(
                name: "\(prefix) Token \(i)",
                token: "secret_\(prefix.lowercased())\(i)3456789012345678901234567890123456"
            )
        }
    }
    
    /// Simulate legacy UserDefaults data
    static func createLegacyUserDefaultsData(tokens: [NotionToken]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(tokens)
    }
    
    /// Assert tokens are equal (ignoring dates and validation state)
    static func assertTokensEqual(_ token1: NotionToken, _ token2: NotionToken, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(token1.id, token2.id, file: file, line: line)
        XCTAssertEqual(token1.name, token2.name, file: file, line: line)
        XCTAssertEqual(token1.token, token2.token, file: file, line: line)
        XCTAssertEqual(token1.workspaceName, token2.workspaceName, file: file, line: line)
        XCTAssertEqual(token1.workspaceIcon, token2.workspaceIcon, file: file, line: line)
    }
    
    /// Wait for async operation with timeout
    static func waitForAsync(timeout: TimeInterval = 5.0, operation: @escaping () async -> Void) {
        let expectation = XCTestExpectation(description: "Async operation completed")
        
        Task {
            await operation()
            expectation.fulfill()
        }
        
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {
    
    /// Run an async test with proper setup/teardown
    func runAsyncTest(
        timeout: TimeInterval = 10.0,
        test: @escaping () async throws -> Void
    ) {
        let expectation = XCTestExpectation(description: "Async test completed")
        
        Task {
            do {
                try await test()
            } catch {
                XCTFail("Async test failed with error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
    }
}

// MARK: - Mock Helpers

extension MockKeychainManager {
    
    /// Configure for testing specific scenarios
    func configureForScenario(_ scenario: TestScenario) {
        reset()
        
        switch scenario {
        case .normal:
            // Default configuration
            break
            
        case .keychainLocked:
            isLocked = true
            
        case .keychainError(let error):
            shouldThrowError = true
            errorToThrow = error
            
        case .storageFull:
            storageLimit = 100 // Very small limit
            
        case .malformedData:
            injectMalformedData(forKey: "notion_tokens")
        }
    }
}

/// Test scenarios for mock configuration
enum TestScenario {
    case normal
    case keychainLocked
    case keychainError(KeychainError)
    case storageFull
    case malformedData
}

// MARK: - Performance Testing Helpers

/// Measure performance of an async operation
func measureAsyncPerformance(
    iterations: Int = 10,
    operation: @escaping () async -> Void
) -> TimeInterval {
    var totalTime: TimeInterval = 0
    
    for _ in 0..<iterations {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let expectation = XCTestExpectation(description: "Performance measurement")
        Task {
            await operation()
            expectation.fulfill()
        }
        _ = XCTWaiter.wait(for: [expectation], timeout: 30.0)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        totalTime += (endTime - startTime)
    }
    
    return totalTime / Double(iterations)
}

// MARK: - Test Data Generators

struct TestDataGenerator {
    
    /// Generate a large number of tokens for stress testing
    static func generateStressTestTokens(count: Int) -> [NotionToken] {
        return (0..<count).map { i in
            let workspaceTypes = ["Personal", "Work", "Team", "Project", "Archive"]
            let workspaceType = workspaceTypes[i % workspaceTypes.count]
            
            return NotionToken(
                name: "\(workspaceType) Workspace \(i)",
                token: "secret_stress\(String(format: "%04d", i))789012345678901234567890123456",
                workspaceName: "\(workspaceType) Space \(i)",
                workspaceIcon: ["📁", "📊", "🚀", "💼", "📚"][i % 5]
            )
        }
    }
    
    /// Generate tokens with various edge case names
    static func generateEdgeCaseTokens() -> [NotionToken] {
        let edgeCaseNames = [
            "",  // Empty name
            " ",  // Single space
            "   Trimmed   ",  // Needs trimming
            String(repeating: "Long ", count: 100),  // Very long name
            "Special!@#$%^&*()Characters",  // Special characters
            "Émoji 🎉 Name 🚀",  // Emoji in name
            "Line\nBreak",  // Line break
            "Tab\tCharacter",  // Tab character
            "Quotes\"Inside\"Name",  // Quotes
            "Backslash\\Name"  // Backslash
        ]
        
        return edgeCaseNames.enumerated().map { index, name in
            NotionToken(
                name: name,
                token: "secret_edge\(index)23456789012345678901234567890123456"
            )
        }
    }
}

// MARK: - Assertion Helpers

struct TokenAssertions {
    
    /// Assert that a token operation result succeeded
    static func assertSuccess<T>(
        _ result: Result<T, TokenError>,
        file: StaticString = #file,
        line: UInt = #line
    ) -> T? {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)", file: file, line: line)
            return nil
        }
    }
    
    /// Assert that a token operation result failed with specific error
    static func assertFailure(
        _ result: Result<Any, TokenError>,
        expectedError: TokenError,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        switch result {
        case .success:
            XCTFail("Expected failure but operation succeeded", file: file, line: line)
        case .failure(let error):
            XCTAssertEqual(error, expectedError, file: file, line: line)
        }
    }
}
