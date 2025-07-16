# NoBuddy Project Setup Guide

This document provides comprehensive instructions for setting up the NoBuddy iOS project from scratch.

## Project Overview

NoBuddy is an iOS companion app for Notion that provides:
- Secure token management for Notion integrations
- iOS Shortcuts (App Intents) for Notion API operations
- iOS Widgets for displaying Notion data
- Native iOS integration with WidgetKit and App Intents

## Technical Specifications

### Requirements
- **iOS Deployment Target**: 16.0+
- **Xcode Version**: 15.0+
- **Swift Version**: 5.9+
- **Architecture**: MVVM with Combine
- **UI Framework**: SwiftUI (primary) + UIKit (when needed)

### Bundle Configuration
- **Main App Bundle ID**: `com.nobuddy.app`
- **Widget Extension**: `com.nobuddy.app.widget`
- **App Intents Extension**: `com.nobuddy.app.intents`

## Project Structure

```
NoBuddy.xcodeproj/
├── NoBuddy/ (Main App Target)
│   ├── App/
│   │   ├── NoBuddyApp.swift
│   │   └── ContentView.swift
│   ├── Models/
│   │   ├── NotionModels.swift
│   │   ├── TokenModel.swift
│   │   └── CoreDataModel.xcdatamodeld
│   ├── Views/
│   │   ├── TokenManagement/
│   │   ├── Dashboard/
│   │   ├── Settings/
│   │   └── Common/
│   ├── ViewModels/
│   │   ├── TokenViewModel.swift
│   │   ├── DashboardViewModel.swift
│   │   └── SettingsViewModel.swift
│   ├── Services/
│   │   ├── NotionAPIClient.swift
│   │   ├── TokenManager.swift
│   │   ├── DataManager.swift
│   │   └── NetworkService.swift
│   ├── Extensions/
│   │   ├── String+Extensions.swift
│   │   ├── View+Extensions.swift
│   │   └── Date+Extensions.swift
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Localizable.strings
│       └── Info.plist
├── NoBuddyWidget/ (Widget Extension)
│   ├── NoBuddyWidget.swift
│   ├── WidgetProvider.swift
│   ├── WidgetViews.swift
│   └── Info.plist
├── NoBuddyIntents/ (App Intents Extension)
│   ├── NotionIntents.swift
│   ├── IntentHandlers.swift
│   └── Info.plist
├── NoBuddyTests/
│   ├── ModelTests/
│   ├── ServiceTests/
│   └── ViewModelTests/
└── NoBuddyUITests/
    ├── TokenManagementTests.swift
    └── DashboardTests.swift
```

## Core Dependencies (Swift Package Manager)

Add these dependencies to the project:

```swift
dependencies: [
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
    .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", from: "1.1.3")
]
```

## Key Implementation Requirements

### 1. Token Management System

**SecureTokenManager.swift**
- Use Keychain Services for secure storage
- Support multiple tokens per user
- Token validation with Notion API
- CRUD operations with proper error handling

**TokenModel.swift**
```swift
struct NotionToken {
    let id: UUID
    let name: String
    let token: String
    let workspaceName: String?
    let workspaceIcon: String?
    let createdAt: Date
    let lastValidated: Date?
    let isValid: Bool
}
```

### 2. Notion API Integration

**NotionAPIClient.swift**
- Complete REST API wrapper
- Rate limiting (3 requests per second)
- Comprehensive error handling
- Response caching for widgets
- Support for all major endpoints:
  - Databases
  - Pages
  - Blocks
  - Users
  - Search

### 3. iOS Shortcuts (App Intents)

**Required App Intents:**
- `CreateNotionPageIntent`
- `QueryNotionDatabaseIntent`
- `UpdateNotionPageIntent`
- `SearchNotionIntent`
- `AddDatabaseEntryIntent`

**Implementation Requirements:**
- Parameter validation and suggestions
- Siri integration
- Error handling with user-friendly messages
- Support for complex parameters (filters, sorts)

### 4. iOS Widgets

**Widget Configurations:**
- Small: Single metric or quick info
- Medium: List view (3-5 items)
- Large: Detailed view with multiple sections

**Widget Provider Requirements:**
- Timeline updates every 15-30 minutes
- Deep linking to app content
- User-configurable data sources
- Placeholder and error states

### 5. Data Layer

**Core Data Model:**
```swift
// Entities
- CachedDatabase
- CachedPage
- CachedBlock
- TokenEntity
- WidgetConfiguration
```

**Data Flow:**
1. API calls cache responses locally
2. Widgets read from cache for performance
3. Background refresh updates cache
4. Conflict resolution for offline changes

## Build Configuration

### Info.plist Requirements

**Main App:**
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

**Widget Extension:**
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
</dict>
```

**App Intents Extension:**
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.appintents-extension</string>
</dict>
```

### App Groups Configuration
- Create shared App Group: `group.com.nobuddy.shared`
- Enable in all targets for data sharing
- Use for shared UserDefaults and Core Data store

## Security Implementation

### Keychain Configuration
```swift
// Use these settings for token storage
let keychain = Keychain(service: "com.nobuddy.tokens")
    .accessibility(.whenUnlockedThisDeviceOnly)
    .synchronizable(false)
```

### Network Security
- Certificate pinning for api.notion.com
- Request/response encryption validation
- No sensitive data in logs

## Testing Strategy

### Unit Tests (Required Coverage: 80%+)
- All service classes
- ViewModels
- Data models
- API client methods

### UI Tests
- Token management flow
- Widget configuration
- App Intent execution
- Error handling scenarios

## Performance Requirements

### App Performance
- Launch time: < 2 seconds
- API response handling: < 5 seconds
- Memory usage: < 50MB baseline

### Widget Performance
- Timeline generation: < 3 seconds
- Memory usage: < 30MB
- Background refresh efficiency

## Accessibility Requirements

- VoiceOver support for all interactive elements
- Dynamic Type support
- High contrast mode compatibility
- Reduced motion respect

## Localization Preparation

Structure for future localization:
- All user-facing strings in Localizable.strings
- Date/number formatting with locale awareness
- RTL layout consideration

## Next Steps After Setup

1. Implement basic token management UI
2. Create Notion API test connection
3. Build first App Intent (Create Quick Note)
4. Develop basic widget (Database Entry List)
5. Add comprehensive error handling
6. Implement offline data caching

## Development Best Practices

- Use SwiftLint for code style consistency
- Implement comprehensive error handling
- Follow Apple's Human Interface Guidelines
- Use Combine for reactive programming
- Implement proper loading states
- Add haptic feedback for user interactions

This setup provides a solid foundation for building a professional, scalable iOS companion app for Notion that integrates seamlessly with the iOS ecosystem. 