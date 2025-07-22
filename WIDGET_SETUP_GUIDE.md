# NoBuddy Widget Setup Guide

## Prerequisites
- NoBuddy app installed and running
- Valid Notion API token
- At least one Notion database with tasks

## Step-by-Step Setup

### 1. Configure Notion Token
1. Open NoBuddy app
2. Go to Settings → Token Management
3. Add your Notion API token if you haven't already
4. Ensure the token status shows as "Active"

### 2. Select Databases for Widget
1. In the main app, navigate to the database selection screen
2. You should see a list of available Notion databases
3. **Select the databases** you want to display in the widget by:
   - Tapping on each database to select it
   - Look for a checkmark or selection indicator
   - The app should save your selection automatically

### 3. Sync Tasks from Notion
After selecting databases, the app needs to sync tasks:

1. **Trigger Initial Sync**:
   - Look for a "Sync" or "Refresh" button in the app
   - Or pull-to-refresh on the main task list
   - The app should fetch tasks from your selected Notion databases

2. **Wait for Sync Completion**:
   - Watch for sync status indicators
   - Check that tasks appear in the main app's task list
   - Ensure no sync errors are displayed

### 4. Verify Core Data Population
The widget reads from Core Data cache. To verify it's populated:

1. In the main app, confirm you can see tasks from your Notion database
2. Tasks should persist even when offline (indicating they're cached)

### 5. Add and Configure Widget
1. **Add Widget to Home Screen**:
   - Long press on home screen
   - Tap the "+" button
   - Search for "NoBuddy"
   - Select widget size (small, medium, or large)
   - Add to home screen

2. **Widget Should Display**:
   - If setup correctly: Your actual Notion tasks
   - If databases not selected: "Setup Required - Select databases in NoBuddy app"
   - If no tasks exist: "All caught up! - No pending tasks"

## Troubleshooting

### Widget Shows "All caught up!" but You Have Tasks

1. **Check Database Selection**:
   ```
   - Open NoBuddy app
   - Verify databases are selected (not just listed)
   - Re-select if needed
   ```

2. **Force Sync**:
   ```
   - Pull to refresh in main app
   - Or look for manual sync option
   - Wait for sync to complete
   ```

3. **Verify Task Status**:
   - Widget filters out completed tasks
   - Check if your tasks have status "Done" in Notion
   - Widget only shows pending/active tasks

4. **Check Task Properties**:
   - Ensure tasks have proper status field
   - Status should not be "Done" or "Completed"
   - Tasks need a title to display

### Widget Shows "Setup Required"

1. **Database Selection Issue**:
   - Databases must be explicitly selected, not just fetched
   - Look for a selection UI in the app
   - Selected databases should be saved to UserDefaults

2. **App Group Issue**:
   - Rebuild both app and widget targets
   - Ensure App Group capability is enabled for both targets
   - App Group ID should be: `group.com.nobuddy.app`

### Debug Steps

1. **Check App Group Container**:
   ```bash
   ls -la ~/Library/Group\ Containers/ | grep nobuddy
   ```
   Should show: `group.com.nobuddy.app`

2. **Check UserDefaults**:
   ```bash
   defaults read group.com.nobuddy.app
   ```
   Should show database configuration data

3. **Check Core Data Store**:
   ```bash
   ls -la ~/Library/Group\ Containers/group.com.nobuddy.app/
   ```
   Should show `NoBuddy.sqlite` files

## Code Integration Points

### Main App Responsibilities

1. **Save Database Selection** (`WidgetDataManager.swift`):
   ```swift
   WidgetDataManager.updateWidgetData(
       from: selectedDatabases,
       tokenId: tokenId,
       workspaceName: workspaceName
   )
   ```

2. **Sync Tasks to Core Data** (`TaskCacheManager.swift`):
   ```swift
   try await taskCacheManager.refreshTasks(
       for: database,
       using: apiClient
   )
   ```

3. **Update Widget Timeline**:
   ```swift
   WidgetCenter.shared.reloadAllTimelines()
   ```

### Widget Responsibilities

1. **Check Configuration** (`WidgetSupport.swift`):
   ```swift
   let databases = WidgetSupport.getSelectedDatabasesForWidget()
   ```

2. **Load Cached Tasks** (`WidgetTaskLoader.swift`):
   ```swift
   let tasks = try await WidgetTaskLoader.shared.loadCachedTasks(limit: 10)
   ```

## Expected Data Flow

1. User selects databases in main app
2. Main app saves selection to shared UserDefaults
3. Main app syncs tasks from Notion API
4. Tasks are saved to Core Data in shared container
5. Widget reads database selection from UserDefaults
6. Widget loads tasks from Core Data
7. Widget displays tasks or appropriate empty state

## Next Steps

After completing setup:
1. Widget should refresh every 15 minutes automatically
2. Force refresh by editing widget on home screen
3. Tasks will update when main app syncs

## Common Issues

1. **No databases showing in app**:
   - Verify Notion API token is valid
   - Check token has correct permissions
   - Ensure databases are shared with integration

2. **Tasks not syncing**:
   - Check network connection
   - Verify Notion API is accessible
   - Look for sync errors in app

3. **Widget not updating**:
   - iOS limits widget update frequency
   - Try removing and re-adding widget
   - Restart device if needed
