import XCTest
@testable import NoBuddy

class KeychainManagerTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: KeychainManager!
    var testService: String!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Use unique service identifier for tests
        testService = "com.nobuddy.test.\(UUID().uuidString)"
        sut = KeychainManager(service: testService)
    }
    
    override func tearDown() {
        // Clean up any test data
        try? sut.deleteAll()
        
        sut = nil
        testService = nil
        
        super.tearDown()
    }
    
    // MARK: - Basic Operation Tests
    
    func testStoreAndRetrieveData() throws {
        // Given
        let testData = "Test Secret Data".data(using: .utf8)!
        let testKey = "test_key"
        
        // When
        try sut.store(testData, forKey: testKey)
        let retrievedData = try sut.retrieve(forKey: testKey)
        
        // Then
        XCTAssertEqual(retrievedData, testData)
    }
    
    func testRetrieveNonExistentData() throws {
        // Given
        let nonExistentKey = "non_existent_key"
        
        // When
        let result = try sut.retrieve(forKey: nonExistentKey)
        
        // Then
        XCTAssertNil(result)
    }
    
    func testUpdateExistingData() throws {
        // Given
        let testKey = "update_test_key"
        let originalData = "Original Data".data(using: .utf8)!
        let updatedData = "Updated Data".data(using: .utf8)!
        
        try sut.store(originalData, forKey: testKey)
        
        // When
        try sut.update(updatedData, forKey: testKey)
        let retrievedData = try sut.retrieve(forKey: testKey)
        
        // Then
        XCTAssertEqual(retrievedData, updatedData)
        XCTAssertNotEqual(retrievedData, originalData)
    }
    
    func testUpdateNonExistentData() throws {
        // Given
        let testKey = "new_key"
        let testData = "New Data".data(using: .utf8)!
        
        // When - Update should create if not exists
        try sut.update(testData, forKey: testKey)
        let retrievedData = try sut.retrieve(forKey: testKey)
        
        // Then
        XCTAssertEqual(retrievedData, testData)
    }
    
    func testDeleteData() throws {
        // Given
        let testKey = "delete_test_key"
        let testData = "Data to Delete".data(using: .utf8)!
        
        try sut.store(testData, forKey: testKey)
        XCTAssertTrue(sut.exists(forKey: testKey))
        
        // When
        try sut.delete(forKey: testKey)
        
        // Then
        XCTAssertFalse(sut.exists(forKey: testKey))
        XCTAssertNil(try sut.retrieve(forKey: testKey))
    }
    
    func testDeleteNonExistentData() throws {
        // Given
        let nonExistentKey = "non_existent_delete_key"
        
        // When/Then - Should not throw
        XCTAssertNoThrow(try sut.delete(forKey: nonExistentKey))
    }
    
    func testExistsCheck() throws {
        // Given
        let testKey = "exists_test_key"
        let testData = "Exists Test Data".data(using: .utf8)!
        
        // When/Then - Before storing
        XCTAssertFalse(sut.exists(forKey: testKey))
        
        // When/Then - After storing
        try sut.store(testData, forKey: testKey)
        XCTAssertTrue(sut.exists(forKey: testKey))
        
        // When/Then - After deleting
        try sut.delete(forKey: testKey)
        XCTAssertFalse(sut.exists(forKey: testKey))
    }
    
    func testDeleteAll() throws {
        // Given - Store multiple items
        let testData = "Test Data".data(using: .utf8)!
        let keys = ["key1", "key2", "key3", "key4", "key5"]
        
        for key in keys {
            try sut.store(testData, forKey: key)
        }
        
        // Verify all exist
        for key in keys {
            XCTAssertTrue(sut.exists(forKey: key))
        }
        
        // When
        try sut.deleteAll()
        
        // Then - All should be deleted
        for key in keys {
            XCTAssertFalse(sut.exists(forKey: key))
        }
    }
    
    // MARK: - Token Storage Tests
    
    func testStoreAndRetrieveNotionTokens() throws {
        // Given
        let tokens = [
            NotionToken(name: "Token 1", token: "secret_test123456789012345678901234567890123456"),
            NotionToken(name: "Token 2", token: "secret_test223456789012345678901234567890123456"),
            NotionToken(name: "Token 3", token: "ntn_test12345678901234567890123456789012345678901")
        ]
        
        // When
        try sut.storeNotionTokens(tokens)
        let retrievedTokens = try sut.retrieveNotionTokens()
        
        // Then
        XCTAssertEqual(retrievedTokens.count, tokens.count)
        for (index, token) in tokens.enumerated() {
            XCTAssertEqual(retrievedTokens[index].id, token.id)
            XCTAssertEqual(retrievedTokens[index].name, token.name)
            XCTAssertEqual(retrievedTokens[index].token, token.token)
        }
    }
    
    func testRetrieveEmptyNotionTokens() throws {
        // Given - No tokens stored
        
        // When
        let retrievedTokens = try sut.retrieveNotionTokens()
        
        // Then
        XCTAssertEqual(retrievedTokens.count, 0)
    }
    
    func testUpdateNotionTokens() throws {
        // Given
        let originalTokens = [
            NotionToken(name: "Original 1", token: "secret_orig123456789012345678901234567890123456"),
            NotionToken(name: "Original 2", token: "secret_orig223456789012345678901234567890123456")
        ]
        
        try sut.storeNotionTokens(originalTokens)
        
        // When - Update with new tokens
        let updatedTokens = [
            NotionToken(name: "Updated 1", token: "secret_updt123456789012345678901234567890123456"),
            NotionToken(name: "Updated 2", token: "secret_updt223456789012345678901234567890123456"),
            NotionToken(name: "Updated 3", token: "secret_updt323456789012345678901234567890123456")
        ]
        
        try sut.updateNotionTokens(updatedTokens)
        let retrievedTokens = try sut.retrieveNotionTokens()
        
        // Then
        XCTAssertEqual(retrievedTokens.count, 3)
        XCTAssertEqual(retrievedTokens[0].name, "Updated 1")
        XCTAssertEqual(retrievedTokens[1].name, "Updated 2")
        XCTAssertEqual(retrievedTokens[2].name, "Updated 3")
    }
    
    func testDeleteNotionTokens() throws {
        // Given
        let tokens = [
            NotionToken(name: "Delete Test 1", token: "secret_del123456789012345678901234567890123456"),
            NotionToken(name: "Delete Test 2", token: "secret_del223456789012345678901234567890123456")
        ]
        
        try sut.storeNotionTokens(tokens)
        XCTAssertTrue(sut.notionTokensExist())
        
        // When
        try sut.deleteNotionTokens()
        
        // Then
        XCTAssertFalse(sut.notionTokensExist())
        let retrievedTokens = try sut.retrieveNotionTokens()
        XCTAssertEqual(retrievedTokens.count, 0)
    }
    
    // MARK: - Large Data Tests
    
    func testStoreLargeData() throws {
        // Given - 1MB of data
        let largeData = Data(repeating: 0xFF, count: 1_000_000)
        let testKey = "large_data_key"
        
        // When
        try sut.store(largeData, forKey: testKey)
        let retrievedData = try sut.retrieve(forKey: testKey)
        
        // Then
        XCTAssertEqual(retrievedData?.count, largeData.count)
        XCTAssertEqual(retrievedData, largeData)
    }
    
    func testStoreMultipleLargeTokens() throws {
        // Given - Many tokens with large names
        var tokens: [NotionToken] = []
        for i in 0..<100 {
            let largeName = String(repeating: "Token \(i) ", count: 100)
            let token = NotionToken(
                name: largeName,
                token: "secret_lrg\(i)23456789012345678901234567890123456"
            )
            tokens.append(token)
        }
        
        // When
        try sut.storeNotionTokens(tokens)
        let retrievedTokens = try sut.retrieveNotionTokens()
        
        // Then
        XCTAssertEqual(retrievedTokens.count, 100)
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentReads() throws {
        // Given
        let testData = "Concurrent Test Data".data(using: .utf8)!
        let testKey = "concurrent_read_key"
        try sut.store(testData, forKey: testKey)
        
        // When - Multiple concurrent reads
        let expectation = XCTestExpectation(description: "All concurrent reads completed")
        expectation.expectedFulfillmentCount = 10
        
        let group = DispatchGroup()
        var results: [Data?] = []
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        for _ in 0..<10 {
            group.enter()
            queue.async {
                do {
                    let data = try self.sut.retrieve(forKey: testKey)
                    results.append(data)
                } catch {
                    XCTFail("Concurrent read failed: \(error)")
                }
                group.leave()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Then - All reads should succeed with same data
        XCTAssertEqual(results.count, 10)
        for result in results {
            XCTAssertEqual(result, testData)
        }
    }
    
    func testConcurrentWrites() throws {
        // Given
        let expectation = XCTestExpectation(description: "All concurrent writes completed")
        expectation.expectedFulfillmentCount = 10
        
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "test.concurrent.write", attributes: .concurrent)
        
        // When - Multiple concurrent writes to different keys
        for i in 0..<10 {
            group.enter()
            queue.async {
                do {
                    let data = "Data \(i)".data(using: .utf8)!
                    let key = "concurrent_write_key_\(i)"
                    try self.sut.store(data, forKey: key)
                } catch {
                    XCTFail("Concurrent write failed: \(error)")
                }
                group.leave()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Then - All writes should succeed
        for i in 0..<10 {
            let key = "concurrent_write_key_\(i)"
            XCTAssertTrue(sut.exists(forKey: key))
        }
    }
    
    // MARK: - Error Case Tests
    
    func testCorruptedDataHandling() throws {
        // This test verifies the behavior when keychain returns unexpected data
        // In a real scenario, this would require mocking the Security framework
        // For now, we test that our error types work correctly
        
        let error = KeychainError.unexpectedData
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Unexpected data"))
    }
    
    func testErrorDescriptions() {
        // Test all error types have proper descriptions
        let errors: [KeychainError] = [
            .duplicateItem,
            .itemNotFound,
            .userCancel,
            .authFailed,
            .unexpectedData,
            .unhandledError(status: -9999)
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}
