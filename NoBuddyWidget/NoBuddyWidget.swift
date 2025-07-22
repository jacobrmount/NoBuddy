import SwiftUI
import WidgetKit
import CoreData

/// NoBuddy Widget for displaying Notion database information on the home screen
struct NoBuddyWidget: Widget {
    let kind: String = "NoBuddyWidget"
    
    init() {
        print("[NoBuddyWidget] ✅ Widget initialized")
    }

    var body: some WidgetConfiguration {
        print("[NoBuddyWidget] Creating widget configuration")
        return AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: NotionDatabaseProvider()) { entry in
            NotionDatabaseWidgetView(entry: entry)
                .containerBackground(.fill, for: .widget)
        }
        .configurationDisplayName("Notion Database Widget")
        .description("Shows your Notion database information")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Provider

struct NotionDatabaseProvider: AppIntentTimelineProvider {
    typealias Intent = ConfigurationAppIntent
    typealias Entry = NotionDatabaseEntry
    
    init() {
        print("[NotionDatabaseProvider] ✅ Provider initialized")
        
        // Check available databases from real app data
        let availableDatabases = WidgetSupport.getAvailableDatabasesFromCache()
        print("[NotionDatabaseProvider] Found \(availableDatabases.count) cached databases from main app")
        
        if availableDatabases.isEmpty {
            print("[NotionDatabaseProvider] ⚠️ No databases cached. User needs to open main app and sync databases.")
        } else {
            for db in availableDatabases {
                print("[NotionDatabaseProvider]   - \(db.icon) \(db.name) (ID: \(db.id))")
            }
        }
    }
    
    func placeholder(in context: Context) -> NotionDatabaseEntry {
        print("[NotionDatabaseProvider] placeholder called")
        // Return loading state for placeholder
        return NotionDatabaseEntry(date: Date(), tasks: [], isLoading: true, databaseId: nil, databaseName: nil)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> NotionDatabaseEntry {
        print("[NotionDatabaseProvider] snapshot called")
        print("[NotionDatabaseProvider] Selected database: \(configuration.database?.name ?? "None")")
        
        let tasks = await loadTasksFromCache(for: configuration.database)
        print("[NotionDatabaseProvider] snapshot loaded \(tasks.count) tasks")
        
        return NotionDatabaseEntry(
            date: Date(),
            tasks: tasks,
            isLoading: false,
            databaseId: configuration.database?.id,
            databaseName: configuration.database?.name
        )
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<NotionDatabaseEntry> {
        print("[NotionDatabaseProvider] timeline called")
        print("[NotionDatabaseProvider] Selected database: \(configuration.database?.name ?? "None")")
        
        let tasks = await loadTasksFromCache(for: configuration.database)
        print("[NotionDatabaseProvider] timeline loaded \(tasks.count) tasks")
        
        var entries: [NotionDatabaseEntry] = []
        let currentDate = Date()
        
        // Generate timeline entries (refresh every 15 minutes)
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: hourOffset * 15, to: currentDate)!
            let entry = NotionDatabaseEntry(
                date: entryDate,
                tasks: tasks,
                isLoading: false,
                databaseId: configuration.database?.id,
                databaseName: configuration.database?.name
            )
            entries.append(entry)
        }
        
        return Timeline(entries: entries, policy: .atEnd)
    }
    
    private func loadTasksFromCache(for selectedDatabase: DatabaseSelection?) async -> [TaskItem] {
        print("[NotionDatabaseProvider] loadTasksFromCache called for database: \(selectedDatabase?.name ?? "None")")
        
        // If a specific database is selected via configuration, use it
        if let selectedDatabase = selectedDatabase {
            // For now, we'll still load from Core Data but filter by database if possible
            // In a future update, you could implement database-specific filtering
            print("[NotionDatabaseProvider] Widget configured for database: \(selectedDatabase.name) (ID: \(selectedDatabase.id))")
        }
        
        // Check Core Data store availability first
        let storeAvailable = WidgetTaskLoader.shared.isDataAvailable()
        print("[NotionDatabaseProvider] Core Data store available: \(storeAvailable)")
        
        // Check if user has selected databases
        let selectedDatabases = WidgetSupport.getSelectedDatabasesForWidget()
        print("[NotionDatabaseProvider] Selected databases count: \(selectedDatabases.count)")
        for db in selectedDatabases {
            print("[NotionDatabaseProvider] Database: \(db.name) (ID: \(db.id))")
        }
        
        if selectedDatabase == nil && selectedDatabases.isEmpty {
            print("[NotionDatabaseProvider] No databases selected or configured, returning empty array")
            // No databases selected - return empty array (UI will show setup prompt)
            return []
        }
        
        if !storeAvailable {
            print("[NotionDatabaseProvider] Core Data store not available yet")
            // Return empty array - this is normal on first launch
            return []
        }
        
        do {
            print("[NotionDatabaseProvider] Attempting to load cached tasks")
            // Load tasks from Core Data cache
            let widgetTasks = try await WidgetTaskLoader.shared.loadCachedTasks(limit: 10)
            print("[NotionDatabaseProvider] Loaded \(widgetTasks.count) widget tasks from cache")
            
            if widgetTasks.isEmpty {
                print("[NotionDatabaseProvider] No cached tasks found")
                // No cached tasks - return empty array
                return []
            }
            
            // Convert WidgetTask to TaskItem
            print("[NotionDatabaseProvider] Converting \(widgetTasks.count) widget tasks to TaskItems")
            let taskItems = widgetTasks.map { widgetTask in
                TaskItem(
                    id: widgetTask.id,
                    title: widgetTask.title,
                    isCompleted: widgetTask.isCompleted,
                    dueDate: widgetTask.dueDate,
                    priority: convertPriority(widgetTask.priority),
                    projectName: selectedDatabase?.name ?? selectedDatabases.first?.name ?? "Database"
                )
            }
            
            print("[NotionDatabaseProvider] Successfully converted tasks:")
            for task in taskItems {
                print("[NotionDatabaseProvider]   - \(task.title) (completed: \(task.isCompleted))")
            }
            
            return taskItems
        } catch {
            print("[NotionDatabaseProvider] Failed to load cached tasks: \(error)")
            // Return empty array - UI will handle error display
            return []
        }
    }
    
    private func convertPriority(_ priority: WidgetTaskPriority) -> TaskPriority {
        switch priority {
        case .none, .low:
            return .low
        case .medium:
            return .medium
        case .high, .urgent:
            return .high
        }
    }
}

// MARK: - Widget Entry

struct NotionDatabaseEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskItem]
    let isLoading: Bool
    let databaseId: String?
    let databaseName: String?
}

// MARK: - Widget View

struct NotionDatabaseWidgetView: View {
    var entry: NotionDatabaseProvider.Entry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var widgetFamily
    
    init(entry: NotionDatabaseProvider.Entry) {
        self.entry = entry
        print("[NotionDatabaseWidgetView] ✅ View initialized with \(entry.tasks.count) tasks, isLoading: \(entry.isLoading)")
    }
    
    var body: some View {
        Group {
            if entry.isLoading {
                loadingView
            } else if entry.tasks.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(colorScheme == .dark ? .black : .white, for: .widget)
    }
    
    // MARK: - Content View (Family-aware)
    
    @ViewBuilder
    private var contentView: some View {
        switch widgetFamily {
        case .systemSmall:
            smallWidgetView
        case .systemMedium:
            mediumWidgetView
        case .systemLarge:
            taskListView
        default:
            taskListView
        }
    }
    
    // MARK: - Small Widget View
    
    private var smallWidgetView: some View {
        VStack(spacing: 8) {
            // Compact header
            HStack {
                Image(systemName: getDatabaseIcon())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                
                Text(getDatabaseTitle())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Item count
                Text("\(entry.tasks.filter { !$0.isCompleted }.count)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            
            // Top 3 items
            VStack(spacing: 4) {
                ForEach(entry.tasks.filter { !$0.isCompleted }.prefix(3)) { task in
                    // TODO: Replace with database-specific content display
                    TaskRowWidget(task: task)
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Medium Widget View
    
    private var mediumWidgetView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: getDatabaseIcon())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                    
                    Text(getDatabaseTitle())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Item count
                Text("\(entry.tasks.filter { !$0.isCompleted }.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Content list (more compact)
            VStack(spacing: 6) {
                ForEach(entry.tasks.prefix(4)) { task in
                    // TODO: Replace with database-specific content display
                    TaskRowWidget(task: task)
                }
                
                if entry.tasks.count > 4 {
                    HStack {
                        Text("+ \(entry.tasks.count - 4) more")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            if WidgetSupport.widgetNeedsConfiguration() {
                // No databases selected
                Image(systemName: "gear")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.orange)
                
                Text("Setup Required")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Select databases in NoBuddy app")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                // No tasks (Core Data might not be available yet, but databases are selected)
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.green)
                
                Text("All caught up!")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("No items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Task List View
    
    private var taskListView: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
                .padding(.horizontal, 16)
            
            // Content list
            VStack(spacing: 8) {
                ForEach(entry.tasks.prefix(6)) { task in
                    TaskRowWidget(task: task)
                }
                
                if entry.tasks.count > 6 {
                    moreTasksView
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            // Icon and title
            HStack(spacing: 8) {
                Image(systemName: getDatabaseIcon())
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(getDatabaseTitle())
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if !WidgetSupport.getSelectedDatabasesForWidget().isEmpty {
                        let selectedCount = WidgetSupport.getSelectedDatabaseCount()
                        Text("\(selectedCount) database\(selectedCount == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No databases selected")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Item count or configuration needed indicator
            if WidgetSupport.widgetNeedsConfiguration() {
                Image(systemName: "gear")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if !entry.tasks.isEmpty {
                Text("\(entry.tasks.filter { !$0.isCompleted }.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - More Tasks View
    
    private var moreTasksView: some View {
        HStack {
            Text("+ \(entry.tasks.count - 6) more items")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Functions
    
    /// Get the appropriate database icon based on selected databases
    private func getDatabaseIcon() -> String {
        let selectedDatabases = WidgetSupport.getSelectedDatabasesForWidget()
        
        if selectedDatabases.isEmpty {
            return "gear"
        } else if selectedDatabases.count == 1 {
            // Use the database's icon if available, otherwise default
            let database = selectedDatabases.first!
            return database.icon.isEmpty ? "list.bullet" : database.icon
        } else {
            // Multiple databases - use a general icon
            return "folder.badge.plus"
        }
    }
    
    /// Get the appropriate database title based on selected databases
    private func getDatabaseTitle() -> String {
        let selectedDatabases = WidgetSupport.getSelectedDatabasesForWidget()
        
        if selectedDatabases.isEmpty {
            return "Setup Required"
        } else if selectedDatabases.count == 1 {
            return selectedDatabases.first!.name
        } else {
            return "\(selectedDatabases.count) Databases"
        }
    }
}

// MARK: - Compact Database Row (Small Widget)
// TODO: Replace with database-specific content display

/*
struct CompactTaskRow: View {
    let task: TaskItem
    
    var body: some View {
        HStack(spacing: 6) {
            // Simple priority dot
            Circle()
                .fill(task.priority?.color ?? .gray)
                .frame(width: 6, height: 6)
            
            // Task title
            Text(task.title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(task.isCompleted ? .secondary : .primary)
                .strikethrough(task.isCompleted)
                .lineLimit(1)
            
            Spacer()
            
            // Due date (if today or overdue)
            if let dueDate = task.dueDate {
                let dayDiff = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                if dayDiff <= 0 {
                    Text(dayDiff == 0 ? "Today" : "\(abs(dayDiff))d ago")
                        .font(.caption2)
                        .foregroundColor(dayDiff == 0 ? .orange : .red)
                }
            }
        }
    }
}
*/

// MARK: - Medium Database Row
// TODO: Replace with database-specific content display

/*
struct MediumTaskRow: View {
    let task: TaskItem
    
    var body: some View {
        HStack(spacing: 8) {
            // Checkbox
            ZStack {
                Circle()
                    .fill(task.isCompleted ? .green : .clear)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(task.isCompleted ? .green : .gray, lineWidth: 1)
                    )
                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Task content
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(1)
                
                if let dueDate = task.dueDate {
                    Text(formatDueDate(dueDate))
                        .font(.caption2)
                        .foregroundColor(dueDateColor(dueDate))
                }
            }
            
            Spacer()
            
            // Priority indicator
            if let priority = task.priority {
                Circle()
                    .fill(priority.color)
                    .frame(width: 4, height: 4)
            }
        }
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func dueDateColor(_ date: Date) -> Color {
        let dayDiff = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        
        if dayDiff < 0 {
            return .red
        } else if dayDiff == 0 {
            return .orange
        } else if dayDiff <= 3 {
            return .yellow
        } else {
            return .secondary
        }
    }
}
*/

// MARK: - Task Row Widget

struct TaskRowWidget: View {
    let task: TaskItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            ZStack {
                Circle()
                    .fill(task.isCompleted ? .green : .clear)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(task.isCompleted ? .green : .gray, lineWidth: 1.5)
                    )
                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Task content
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(1)
                
                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(formatDueDate(dueDate))
                            .font(.caption)
                            .foregroundColor(dueDateColor(dueDate))
                    }
                }
            }
            
            Spacer()
            
            // Priority indicator
            if let priority = task.priority {
                priorityIndicator(priority)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func priorityIndicator(_ priority: TaskPriority) -> some View {
        Circle()
            .fill(priority.color)
            .frame(width: 6, height: 6)
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func dueDateColor(_ date: Date) -> Color {
        let dayDiff = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        
        if dayDiff < 0 {
            return .red
        } else if dayDiff == 0 {
            return .orange
        } else if dayDiff <= 3 {
            return .yellow
        } else {
            return .secondary
        }
    }
}

// MARK: - Task Models

struct TaskItem: Identifiable, Codable {
    let id: String
    let title: String
    let isCompleted: Bool
    let dueDate: Date?
    let priority: TaskPriority?
    let projectName: String?
    
    init(id: String = UUID().uuidString, title: String, isCompleted: Bool = false, dueDate: Date? = nil, priority: TaskPriority? = nil, projectName: String? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.priority = priority
        self.projectName = projectName
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

// MARK: - Preview Support

#Preview(as: .systemMedium) {
    NoBuddyWidget()
} timeline: {
    NotionDatabaseEntry(date: Date(), tasks: previewTasks, isLoading: false, databaseId: "preview-db", databaseName: "My Tasks")
    NotionDatabaseEntry(date: Date().addingTimeInterval(300), tasks: [], isLoading: false, databaseId: "preview-db", databaseName: "My Tasks")
}

// MARK: - Preview Data

private let previewTasks: [TaskItem] = [] 

