# Core Data Setup Instructions for NoBuddy

## Overview
The Core Data stack has been configured to use a shared App Group container (`group.com.nobuddy.app`) to enable data sharing between the main app and widget extension.

## Setting up the NoBuddy.xcdatamodeld file

### 1. Create the Entities

In your `NoBuddy.xcdatamodeld` file, create the following entities:

#### CDToken Entity
**Attributes:**
- `id` (UUID) - Non-optional
- `name` (String) - Non-optional
- `token` (String) - Non-optional
- `workspaceName` (String) - Optional
- `workspaceIcon` (String) - Optional
- `createdAt` (Date) - Non-optional
- `lastValidated` (Date) - Optional
- `isValid` (Boolean) - Non-optional, Default: NO

**Relationships:**
- `databases` - To Many, Destination: CDDatabase, Delete Rule: Cascade
- `selectedDatabases` - To Many, Destination: CDSelectedDatabase, Delete Rule: Cascade

#### CDDatabase Entity
**Attributes:**
- `id` (String) - Non-optional
- `title` (String) - Non-optional
- `icon` (String) - Optional
- `url` (String) - Optional
- `lastEditedTime` (Date) - Non-optional
- `createdTime` (Date) - Non-optional
- `cachedAt` (Date) - Non-optional

**Relationships:**
- `token` - To One, Destination: CDToken, Delete Rule: Cascade, Inverse: databases
- `selections` - To Many, Destination: CDSelectedDatabase, Delete Rule: Cascade

#### CDSelectedDatabase Entity
**Attributes:**
- `databaseId` (String) - Non-optional
- `selectedAt` (Date) - Non-optional
- `isSelected` (Boolean) - Non-optional, Default: YES

**Relationships:**
- `database` - To One, Destination: CDDatabase, Delete Rule: Nullify, Inverse: selections
- `token` - To One, Destination: CDToken, Delete Rule: Cascade, Inverse: selectedDatabases

### 2. Configure Entity Settings

For each entity:
1. Set the Class Name to match the entity name (e.g., `CDToken`)
2. Set Module to "Current Product Module"
3. Set Codegen to "Manual/None" (since we have custom NSManagedObject subclasses)

### 3. Add to Targets

Make sure the `NoBuddy.xcdatamodeld` file is included in:
- NoBuddy (main app target)
- NoBuddyWidget (widget extension target)

### 4. Test the Setup

To verify everything is working:

```swift
// In your app code
let coreDataManager = CoreDataManager.shared
let context = coreDataManager.viewContext

// Create a test token
let testToken = CDToken(context: context)
testToken.id = UUID()
testToken.name = "Test Token"
testToken.token = "secret_test_token"
testToken.createdAt = Date()
testToken.isValid = false

// Save
try await coreDataManager.saveViewContext()
```

## Migration Strategy

The CoreDataManager is configured with:
- Automatic lightweight migration enabled
- Persistent history tracking for cross-process coordination
- Remote change notifications for widget updates

## Troubleshooting

1. **"Failed to load model" error**: Ensure the `NoBuddy.xcdatamodeld` file is in the main bundle
2. **Widget can't access data**: Verify App Group entitlements are set correctly in both targets
3. **Migration issues**: Check `CoreDataManager.checkMigrationStatus()` before making schema changes

## Best Practices

1. Always use the shared `CoreDataManager.shared` instance
2. Perform heavy operations on background contexts using `performBackgroundTask`
3. Save changes promptly to ensure widget sees updates
4. Use the conversion methods in extensions to convert between Core Data and model objects
