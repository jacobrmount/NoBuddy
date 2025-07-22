# Widget Task Caching System

This document explains how to use the efficient caching system to share Notion database data between the main app and widget.

## Overview

The caching system solves the fundamental challenge that **widgets cannot make network calls** and have **limited execution time**. It uses:

- **Core Data** as the source of truth in the main app
- **Shared UserDefaults** for fast widget access
- **Minimal data structures** to respect UserDefaults size limits
- **Staleness checking** to ensure data freshness

## Architecture

```
Main App                    Shared UserDefaults              Widget
┌─────────────────────┐    ┌──────────────────────┐         ┌────────────────┐
│ Core Data          │    │ WidgetTasksCache     │         │ Widget Views   │
│ ├─ TaskCache       │───▶│ ├─ Database ID       │────────▶│ ├─ Timeline     │
│ ├─ CDDatabase      │    │ ├─ Tasks (limited)   │         │ ├─ Entries     │
│ └─ Properties      │    │ ├─ Cached timestamp  │         │ └─ Display     │
└─────────────────────┘    │ └─ Version info     │         └────────────────┘
                           └──────────────────────┘
```

## Core Data Models

### WidgetTask (Optimized for UserDefaults)
```swift
struct WidgetTask: Identifiable, Codable {
    let id: String              // Notion page ID
    let title: String           // Task title
    let isComplete: Bool        // Completion status
    let dueDate: Date?          // Due date (optional)
    let priority: TaskCache.Priority   // Priority level
    let status: TaskCache.TaskStatus   // Current status
    let lastUpdated: Date       // Last modified time
    let isOverdue: Bool         // Computed overdue status
    let isDueToday: Bool        // Computed today status
}
```

### WidgetTasksCache (Cache Container)
```swift
struct WidgetTasksCache: Codable {
    let databaseId: String      // Database identifier
    let databaseName: String    // Human-readable name
    let tasks: [WidgetTask]     // Limited task array (max 10)
    let cachedAt: Date          // Cache timestamp
    let version: Int            // Cache format version
}
```

## Usage Examples

### 1. Caching Tasks from Main App

```swift
import CoreData

// In your sync/update code
func syncCompletedForDatabase(_ databaseId: String, _ databaseName: String) {
    let context = CoreDataManager.shared.viewContext
    
    // Update widget cache with latest data
    WidgetTaskCaching.updateAndRefreshWidget(
        databaseId: databaseId,
        databaseName: databaseName,
        context: context
    )
}

// After bulk data updates
func handleSyncCompletion() {
    let context = CoreDataManager.shared.viewContext
    WidgetTaskCaching.handleDataUpdate(context: context)
}

// When user changes database selection
func databaseSelectionChanged() {
    let context = CoreDataManager.shared.viewContext
    WidgetTaskCaching.handleDatabaseSelectionChange(context: context)
}
```

### 2. Retrieving Cached Tasks in Widget

```swift
// In your widget's TimelineProvider
struct TaskTimelineProvider: TimelineProvider {
    
    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> ()) {
        // Get cached tasks for all selected databases
        let allTasks = WidgetDataManager.getAllCachedTasks()
        
        let entry = TaskEntry(
            date: Date(),
            tasks: allTasks.values.flatMap { $0 },
            isLoading: false
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> ()) {
        // Get cached tasks with staleness check (5 minutes)
        let allTasks = WidgetDataManager.getAllCachedTasks(maxAge: 300)
        
        if allTasks.isEmpty {
            // No valid cache - show placeholder
            let entry = TaskEntry(date: Date(), tasks: [], isLoading: true)
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))
            completion(timeline)
            return
        }
        
        // Create timeline entries
        var entries: [TaskEntry] = []
        let currentDate = Date()
        
        for hourOffset in 0..<5 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: hourOffset * 15, to: currentDate)!
            let entry = TaskEntry(
                date: entryDate,
                tasks: allTasks.values.flatMap { $0 },
                isLoading: false
            )
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}
```

### 3. Widget View Implementation

```swift
struct TaskWidgetView: View {
    var entry: TaskEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
                
                Text("Tasks")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(entry.incompleteTasks.count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            // Task List
            if entry.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entry.tasks.isEmpty {
                Text("No tasks")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.topTasks) { task in
                        TaskRowView(task: task)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .containerBackground(.fill, for: .widget)
    }
}

struct TaskRowView: View {
    let task: WidgetTask
    
    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(task.isComplete ? .green : .gray.opacity(0.3))
                .frame(width: 8, height: 8)
            
            // Task title
            Text(task.title)
                .font(.caption)
                .lineLimit(1)
                .strikethrough(task.isComplete)
                .foregroundColor(task.isComplete ? .secondary : .primary)
            
            Spacer()
            
            // Priority indicator
            if task.priority != .none {
                Text(task.priority.emoji)
                    .font(.caption2)
            }
            
            // Due date indicator
            if task.isDueToday {
                Text("Today")
                    .font(.caption2)
                    .foregroundColor(.orange)
            } else if task.isOverdue {
                Text("Overdue")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }
}

// Entry model for timeline
struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
    let isLoading: Bool
    
    var incompleteTasks: [WidgetTask] {
        tasks.filter { !$0.isComplete }
    }
    
    var topTasks: [WidgetTask] {
        incompleteTasks.prefix(5).map { $0 }
    }
}
```

## Cache Management

### Key Features

1. **Automatic Staleness**: Caches expire after 5 minutes by default
2. **Size Optimization**: Only top 10 tasks per database are cached
3. **Efficient Storage**: Uses JSON encoding for compact UserDefaults storage
4. **Version Control**: Cache format versioning for future compatibility

### Storage Keys

- Tasks: `widget_tasks_<databaseId>`
- Timestamps: `widget_db_timestamp_<databaseId>`
- Config: `database_selection_config`

### Cache Lifecycle

```swift
// 1. Main app updates data
WidgetTaskCaching.cacheTasksForWidget(databaseId: "db123", databaseName: "Tasks", tasks: taskArray)

// 2. Widget reads cache
let cachedTasks = WidgetDataManager.getCachedTasks(for: "db123")

// 3. Check staleness
if cachedTasks == nil {
    // Cache miss or stale - show loading state
    showLoadingState()
}

// 4. Automatic cleanup
WidgetTaskCaching.clearStaleTaskCaches() // Called periodically
```

## Performance Considerations

### Optimizations
- **Limited Data**: Only 5-10 most important tasks per database
- **Computed Properties**: Overdue/today status pre-calculated
- **Batch Updates**: All selected databases updated together
- **Lazy Loading**: Widget only loads what it needs to display

### Memory Usage
- Each `WidgetTask`: ~200 bytes
- Cache for 10 tasks: ~2KB
- Multiple databases: Still well under UserDefaults limits

## Integration Points

### Main App Integration
```swift
// Call after significant data changes
NotificationCenter.default.post(name: .dataDidUpdate, object: nil)

// In your observer
@objc func dataDidUpdate() {
    WidgetTaskCaching.handleDataUpdate(context: coreDataContext)
}
```

### Widget Integration
```swift
// In widget configuration
@main
struct TaskWidget: Widget {
    let kind: String = "TaskWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskTimelineProvider()) { entry in
            TaskWidgetView(entry: entry)
        }
        .configurationDisplayName("Tasks")
        .description("Shows your most important tasks")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

## Debugging & Monitoring

```swift
// Print cache status for debugging
WidgetTaskCaching.printCacheStatus()

// Output:
// [WidgetTaskCaching] 📊 Cache Status:
//   - db123: ["taskCount": 5, "cachedAt": 2025-01-15 10:30:00, "ageSeconds": 45, "isStale": false]
//   - db456: ["taskCount": 8, "cachedAt": 2025-01-15 10:29:30, "ageSeconds": 75, "isStale": false]
```

This caching system ensures your widget always has access to fresh task data while respecting iOS widget constraints and performance requirements.