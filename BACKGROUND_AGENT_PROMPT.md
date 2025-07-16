# Background Agent Prompt: NoBuddy iOS Project Implementation

## Project Overview
Create a complete, production-ready iOS application called "NoBuddy" that serves as a powerful companion app for Notion. This project has been initialized with git and contains comprehensive documentation and project structure guidelines.

## Immediate Implementation Tasks

### 1. Xcode Project Creation & Setup
**CRITICAL FIRST STEP**: Create the Xcode project with these exact specifications:
- **Product Name**: NoBuddy
- **Interface**: SwiftUI
- **Language**: Swift  
- **Bundle Identifier**: com.nobuddy.app
- **Deployment Target**: iOS 16.0
- **Organization Identifier**: com.nobuddy
- **Team**: Configure with available development team

**Additional Targets to Create**:
- Widget Extension: NoBuddyWidget (Bundle ID: com.nobuddy.app.widget)
- App Intents Extension: NoBuddyIntents (Bundle ID: com.nobuddy.app.intents)

### 2. Swift Package Dependencies
Add these exact dependencies via Swift Package Manager:
```
https://github.com/kishikawakatsumi/KeychainAccess.git (version 4.2.2+)
https://github.com/siteline/SwiftUI-Introspect.git (version 1.1.3+)
```

### 3. Structure Implementation
Follow the complete structure defined in `Documentation/PROJECT_SETUP.md`. Create these exact folder hierarchies within the main app target:

```
NoBuddy/
├── App/
├── Models/
├── Views/
│   ├── TokenManagement/
│   ├── Dashboard/
│   ├── Settings/
│   └── Common/
├── ViewModels/
├── Services/
├── Extensions/
└── Resources/
```

### 4. Core Implementation Requirements

#### A. Token Management System (HIGH PRIORITY)
**File**: `Services/SecureTokenManager.swift`
- Implement complete CRUD operations for Notion tokens
- Use KeychainAccess dependency for secure storage
- Support multiple tokens per user
- Token validation against Notion API
- Error handling with user-friendly messages

**File**: `Models/TokenModel.swift`
```swift
struct NotionToken: Identifiable, Codable {
    let id: UUID
    var name: String
    let token: String
    var workspaceName: String?
    var workspaceIcon: String?
    let createdAt: Date
    var lastValidated: Date?
    var isValid: Bool
}
```

**File**: `Views/TokenManagement/TokenManagementView.swift`
- SwiftUI interface for token CRUD operations
- Add/Edit/Delete functionality
- Token validation status display
- Modern iOS design following HIG

#### B. Notion API Client (HIGH PRIORITY)
**File**: `Services/NotionAPIClient.swift`
- Complete REST API wrapper for Notion API v1
- Rate limiting implementation (3 requests/second)
- Comprehensive error handling
- Response caching for widget performance
- Support endpoints: databases, pages, blocks, users, search

**File**: `Models/NotionModels.swift`
- Swift structs for all Notion API objects
- Proper Codable implementation
- Nested object support (blocks, properties, etc.)

#### C. App Intents Implementation (MEDIUM PRIORITY)
**File**: `NoBuddyIntents/NotionIntents.swift`
Create these specific App Intents:
- `CreateNotionPageIntent`
- `QueryNotionDatabaseIntent` 
- `UpdateNotionPageIntent`
- `SearchNotionIntent`
- `AddDatabaseEntryIntent`

Requirements:
- Siri integration support
- Parameter validation and suggestions
- User-friendly error messages
- Support for complex parameters (filters, sorts)

#### D. Widget Implementation (MEDIUM PRIORITY)
**File**: `NoBuddyWidget/NoBuddyWidget.swift`
- Small, Medium, Large widget sizes
- Timeline provider for data updates
- Deep linking to app content
- User-configurable data sources
- Placeholder and error states

#### E. Core Data Implementation
**File**: `Models/CoreDataModel.xcdatamodeld`
Create entities:
- CachedDatabase
- CachedPage
- CachedBlock
- TokenEntity
- WidgetConfiguration

**File**: `Services/DataManager.swift`
- Core Data stack management
- App Group configuration for widget data sharing
- Background context handling
- Data synchronization logic

### 5. App Configuration

#### App Groups Setup
- Create shared App Group: `group.com.nobuddy.shared`
- Enable in all targets (main app, widget, intents)
- Configure shared UserDefaults and Core Data store

#### Info.plist Configuration
**Main App Info.plist** additions:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSUserActivityTypes</key>
<array>
    <string>viewNotionPage</string>
    <string>editNotionPage</string>
</array>
```

### 6. User Interface Implementation

#### Main App Views
**File**: `App/NoBuddyApp.swift`
- App entry point with proper navigation
- Environment setup for Core Data and services

**File**: `App/ContentView.swift`
- Main navigation structure
- Tab view or navigation view setup

**File**: `Views/Dashboard/DashboardView.swift`
- Overview of connected workspaces
- Recent activity display
- Quick actions

**File**: `Views/Settings/SettingsView.swift`
- App preferences
- Token management navigation
- Widget configuration options

### 7. Testing Implementation
Create comprehensive test files:
- `NoBuddyTests/Services/NotionAPIClientTests.swift`
- `NoBuddyTests/Services/SecureTokenManagerTests.swift`
- `NoBuddyTests/ViewModels/TokenViewModelTests.swift`
- `NoBuddyUITests/TokenManagementFlowTests.swift`

### 8. Security & Performance
- Implement Keychain storage with proper security settings
- Add certificate pinning for api.notion.com
- Implement proper loading states and error handling
- Add haptic feedback for user interactions
- Ensure accessibility compliance (VoiceOver, Dynamic Type)

## Immediate Deliverables
After implementation, the project should have:
1. ✅ Working Xcode project with all targets configured
2. ✅ Basic token management UI (add/edit/delete/validate tokens)
3. ✅ Functional Notion API connection test
4. ✅ One working App Intent (CreateNotionPageIntent)
5. ✅ One basic widget showing Notion data
6. ✅ Proper project documentation and inline code comments

## Development Standards
- Follow all guidelines in `Documentation/DEVELOPMENT_GUIDELINES.md`
- Use SwiftUI best practices and MVVM architecture
- Implement comprehensive error handling
- Add proper logging for debugging
- Follow Apple's Human Interface Guidelines
- Prepare for future localization (externalized strings)

## File References
All detailed specifications are available in:
- `Documentation/PROJECT_SETUP.md` (Complete technical requirements)
- `Documentation/DEVELOPMENT_GUIDELINES.md` (Code standards)
- `Documentation/API/NOTION_API_REFERENCE.md` (API details)
- `project_config.json` (Project configuration)
- `Scripts/setup.sh` (Additional setup automation)

## Success Criteria
The completed implementation should:
- Build and run successfully on iOS 16+ devices and simulators
- Successfully connect to Notion API with valid tokens
- Display real Notion data in at least one widget
- Execute at least one App Intent end-to-end
- Pass basic unit tests for core functionality
- Follow iOS app development best practices
- Be ready for App Store submission (with proper provisioning)

**Start with the Xcode project creation and token management system, then build incrementally following the priority order listed above.** 