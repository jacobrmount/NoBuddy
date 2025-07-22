# TaskCache Entity Configuration for Core Data Model

## Entity: TaskCache

### Attributes

| Attribute | Type | Optional | Default | Indexed | Notes |
|-----------|------|----------|---------|---------|-------|
| notionPageID | String | NO | - | YES | Unique identifier from Notion |
| title | String | NO | - | YES | Task title |
| status | String | YES | - | YES | Task status (e.g., "Not Started", "In Progress", "Done") |
| priority | Integer 16 | NO | 0 | YES | Priority level (0-4) |
| dueDate | Date | YES | - | YES | Task due date |
| assignee | String | YES | - | NO | Assignee name |
| assigneeID | String | YES | - | NO | Notion user ID of assignee |
| createdTime | Date | NO | - | NO | Task creation time in Notion |
| lastEditedTime | Date | NO | - | NO | Last edit time in Notion |
| createdBy | String | YES | - | NO | Creator's name |
| lastEditedBy | String | YES | - | NO | Last editor's name |
| url | String | YES | - | NO | Notion page URL |
| lastFetched | Date | NO | - | YES | Last time data was fetched from Notion |
| isStale | Boolean | NO | NO | NO | Flag indicating if cache needs refresh |
| syncStatus | String | NO | "synced" | YES | Sync status ("synced", "pending", "syncing", "failed", "conflict") |

### Relationships

| Name | Destination | Type | Delete Rule | Inverse | Notes |
|------|-------------|------|-------------|---------|-------|
| database | CDDatabase | To One | Nullify | tasks | The database this task belongs to |

### Fetch Indexes

1. **byStatus**: status
2. **byPriority**: priority, dueDate
3. **byDueDate**: dueDate, status
4. **byDatabase**: database, priority, dueDate
5. **staleTasks**: lastFetched, isStale

### Unique Constraints

- notionPageID (ensures no duplicate tasks)

### Validation Rules

- title: min length = 1
- priority: min = 0, max = 4
- syncStatus: regex pattern = "^(synced|pending|syncing|failed|conflict)$"

## Migration Notes

When adding this entity to the Core Data model:

1. Create a new model version
2. Add the TaskCache entity with all attributes listed above
3. Set up the relationship to CDDatabase
4. Add the inverse relationship "tasks" to CDDatabase (To Many, optional)
5. Configure fetch indexes for performance
6. Set the unique constraint on notionPageID
7. Enable lightweight migration in the persistent store options

## Usage Examples

```swift
// Fetch all tasks for a database
let tasks = try TaskCache.fetchTasks(for: database, context: context)

// Fetch overdue tasks
let overdueTasks = try TaskCache.fetchOverdueTasks(context: context)

// Update task from Notion
task.update(from: notionPage, databaseID: databaseID)

// Check if cache is stale
if task.isCacheStale {
    // Refresh from Notion
}
```
