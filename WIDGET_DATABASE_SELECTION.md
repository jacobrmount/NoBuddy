# Widget Database Selection Implementation

## Overview

The widget database selection has been implemented to mirror the main app's "Select databases" functionality. Here's how it works:

## Architecture

### Main App Side

1. **Database Loading & Caching**:
   - When databases are fetched from Notion API in `EditTokenView.loadDatabases()`, they are now cached for widget use
   - The caching happens via `WidgetUpdateHelper.cacheDatabasesFromAPI()`
   - Databases are stored in shared UserDefaults under the key `"available_databases_cache"`

2. **Database Selection Storage**:
   - Selected databases are stored separately under `"database_selection_config"`
   - This allows the widget to show all available databases, not just selected ones

### Widget Side

1. **Database Options Provider**:
   - `DatabaseOptionsProvider` fetches all available databases using `WidgetSupport.getAvailableDatabasesFromCache()`
   - If no databases are cached, it shows: "Open NoBuddy app to sync databases"
   - This provides a helpful message guiding users on what to do

2. **Widget Configuration**:
   - Each widget instance can select ONE database from all available databases
   - This is different from the main app where multiple databases can be selected
   - The widget shows tasks from the single selected database

## Data Flow

1. User opens Edit Token view in main app
2. App fetches databases from Notion API
3. Databases are cached to shared UserDefaults (available_databases_cache)
4. User selects databases for the main app (stored in database_selection_config)
5. Widget reads from available_databases_cache to show all databases
6. User configures widget to show one specific database
7. Widget displays tasks from that database

## Testing Instructions

### 1. Clear Existing Data (Optional)
```swift
// Add this temporarily to your app to clear caches
WidgetUpdateHelper.clearDatabasesCache()
```

### 2. Load Databases in Main App
1. Open the NoBuddy app
2. Go to Settings → Token Management
3. Edit your token or add a new one
4. The databases should load automatically
5. Select which databases you want to use in the main app

### 3. Verify Cache State
Add this debug code temporarily to check if databases are cached:

```swift
// In your app's viewDidAppear or similar
WidgetDebugHelper.debugWidgetSetup()
```

This will print the cache state to console.

### 4. Configure Widget
1. Long press home screen → Add widget
2. Select NoBuddy widget
3. Long press the widget → Edit Widget
4. The database dropdown should show all your Notion databases
5. Select the database you want to display

## Troubleshooting

### Widget shows "Open NoBuddy app to sync databases"
This means no databases are cached. To fix:
1. Open the main app
2. Go to Edit Token view
3. Ensure databases load successfully
4. If needed, tap the Refresh button

### Widget shows old/stale databases
The cache might be outdated. To refresh:
1. In Edit Token view, tap the Refresh button
2. This clears the cache and fetches fresh data

### Debug Commands

Check what's in the shared UserDefaults:
```bash
# List all data in the app group
defaults read group.com.nobuddy.app
```

## Key Files

- `NoBuddy/Services/WidgetUpdateHelper.swift` - Handles caching databases for widgets
- `NoBuddy/Views/TokenManagement/EditTokenView.swift` - Now caches databases when loading
- `NoBuddyWidget/WidgetSupport.swift` - Reads cached databases for widget
- `NoBuddyWidget/DatabaseSelection.swift` - Contains DatabaseOptionsProvider
- `NoBuddy/Debug/WidgetDebugHelper.swift` - Debug utilities

## Implementation Details

The key change was ensuring that ALL available databases are cached when fetched from the API, not just the selected ones. This allows the widget configuration to show all databases the user has access to, matching the behavior of the main app's "Select databases" screen.

The widget configuration uses iOS 17's `AppIntentConfiguration` with a dynamic options provider that reads from the cache. If no cache exists, it provides a helpful message instead of showing an empty list.
