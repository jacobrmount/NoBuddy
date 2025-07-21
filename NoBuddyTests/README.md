# SecureTokenManager Test Suite

This directory contains comprehensive XCTest unit tests for the NoBuddy app's SecureTokenManager, which handles secure storage of Notion API tokens using iOS Keychain instead of UserDefaults.

## Test Files Overview

### 1. **SecureTokenManagerTests.swift**
Main test suite covering core functionality:
- Token persistence across app launches
- Widget extension access
- UserDefaults to Keychain migration
- Encryption verification
- Error handling (locked keychain, access denied)
- Thread safety and concurrent operations
- Token validation and format checking
- Security validation

### 2. **KeychainManagerTests.swift**
Tests for the KeychainManager wrapper:
- Basic CRUD operations (Create, Read, Update, Delete)
- Token-specific storage methods
- Large data handling
- Concurrent access scenarios
- Error cases and edge conditions

### 3. **SecureTokenManagerIntegrationTests.swift**
Integration tests focusing on real-world scenarios:
- App group sharing between main app and extensions
- Widget extension token access
- Cross-extension synchronization
- Migration scenarios
- Performance under memory pressure
- Real-world widget refresh flows

### 4. **MockKeychainManager.swift**
Mock implementation of KeychainManager for isolated testing:
- In-memory storage simulation
- Error injection capabilities
- Keychain locked state simulation
- Storage limit simulation
- App group sharing simulation

### 5. **TestConfiguration.swift**
Test utilities and helpers:
- Test constants and sample data
- Helper methods for test setup
- Performance measurement utilities
- Test data generators
- Custom assertions

## Running the Tests

### Command Line
```bash
# Run all tests
xcodebuild test -scheme NoBuddy -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -scheme NoBuddy -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:NoBuddyTests/SecureTokenManagerTests

# Run with verbose output
xcodebuild test -scheme NoBuddy -destination 'platform=iOS Simulator,name=iPhone 15' -verbose
```

### Xcode
1. Open NoBuddy.xcodeproj in Xcode
2. Press `Cmd+U` to run all tests
3. Or click on individual test methods to run specific tests

## Test Coverage Areas

### 1. **Security**
- ✅ Tokens are encrypted in Keychain storage
- ✅ No sensitive data remains in UserDefaults after migration
- ✅ Proper error handling for locked Keychain
- ✅ App group access controls

### 2. **Functionality**
- ✅ Token CRUD operations
- ✅ Token persistence across app restarts
- ✅ Widget extension can access main app tokens
- ✅ Concurrent operations are thread-safe
- ✅ Token format validation

### 3. **Migration**
- ✅ Automatic migration from UserDefaults to Keychain
- ✅ Migration only happens once
- ✅ Legacy data is properly cleaned up
- ✅ Partial migration recovery

### 4. **Performance**
- ✅ Large data set handling
- ✅ Concurrent read/write operations
- ✅ Widget loading performance
- ✅ Memory pressure scenarios

### 5. **Edge Cases**
- ✅ Empty state handling
- ✅ Malformed data recovery
- ✅ Storage limit scenarios
- ✅ Special characters in token names

## Test Data

### Valid Token Formats
```swift
// Standard Notion integration token
"secret_test123456789012345678901234567890123456"

// Internal Notion token
"ntn_test12345678901234567890123456789012345678901"
```

### Mock Configurations
The `MockKeychainManager` can be configured for various scenarios:
```swift
// Normal operation
mockKeychain.configureForScenario(.normal)

// Keychain locked
mockKeychain.configureForScenario(.keychainLocked)

// Storage full
mockKeychain.configureForScenario(.storageFull)

// Specific error
mockKeychain.configureForScenario(.keychainError(.authFailed))
```

## Best Practices

1. **Isolation**: Each test uses isolated UserDefaults and mock Keychain to prevent interference
2. **Async Testing**: Proper use of XCTestExpectation for async operations
3. **Cleanup**: tearDown methods ensure clean state between tests
4. **Realistic Scenarios**: Integration tests simulate real app/widget interactions
5. **Performance**: Dedicated performance tests with measurements

## Adding New Tests

When adding new tests:

1. Use the provided mock objects for isolation
2. Follow the Given-When-Then pattern for clarity
3. Use descriptive test method names
4. Clean up any test data in tearDown
5. Use TestConfiguration helpers for common operations

Example:
```swift
func testNewFeature() async throws {
    // Given
    let token = createTestToken(name: "Test", tokenValue: "secret_test...")
    
    // When
    let result = await sut.someNewMethod(token)
    
    // Then
    XCTAssertTrue(result.isSuccess)
}
```

## Continuous Integration

These tests are designed to run in CI environments:
- No dependency on physical device features
- No UI tests that require specific device states
- Consistent timing with proper expectations
- Clean state management

## Troubleshooting

### Common Issues

1. **Tests fail with "Keychain access denied"**
   - Ensure tests are running in Simulator, not on device
   - Check that keychain entitlements are set correctly

2. **Async tests timeout**
   - Increase timeout values in XCTestExpectation
   - Check for deadlocks in concurrent operations

3. **Migration tests fail**
   - Ensure UserDefaults are properly cleaned between tests
   - Verify mock data format matches production

### Debug Tips

- Use `print()` statements in mock methods to trace execution
- Set breakpoints in mock error injection to debug error handling
- Use Xcode's test navigator to run individual tests
- Check test logs for detailed error messages

## Notes for Physical Device Testing

While these tests use mocks, for app group functionality testing on physical devices:
1. Ensure proper app group entitlements
2. Use the same team ID for all targets
3. Test with actual widget extension installed
4. Verify keychain sharing capability is enabled
