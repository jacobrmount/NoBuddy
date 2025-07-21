import SwiftUI
import WidgetKit

/// NoBuddy Widget for displaying Notion data on the home screen
@available(iOSApplicationExtension 17.0, *)
struct NoBuddyWidget: Widget {
    let kind: String = "NoBuddyWidget"

    @available(iOSApplicationExtension 17.0, *)
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskListProvider()) { entry in
            TaskListWidgetView(entry: entry)
        }
        .configurationDisplayName("Task List")
        .description("Shows your Notion tasks and to-dos")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Provider

struct TaskListProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskListEntry {
        TaskListEntry(date: Date(), tasks: sampleTasks, isLoading: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskListEntry) -> ()) {
        let entry = TaskListEntry(date: Date(), tasks: sampleTasks, isLoading: false)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskListEntry>) -> ()) {
        var entries: [TaskListEntry] = []

        // Generate timeline entries (refresh every 15 minutes)
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: hourOffset * 15, to: currentDate)!
            let entry = TaskListEntry(date: entryDate, tasks: loadTasksFromNotionAPI(), isLoading: false)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func loadTasksFromNotionAPI() -> [TaskItem] {
        // Check if user has selected databases
        let selectedDatabases = WidgetSupport.getSelectedDatabasesForWidget()
        
        if selectedDatabases.isEmpty {
            // No databases selected - return placeholder data
            return [
                TaskItem(
                    title: "Select databases in NoBuddy app",
                    isCompleted: false,
                    priority: .medium,
                    projectName: "Setup"
                )
            ]
        }
        
        // TODO: In a real implementation, this would fetch from selected Notion databases
        // For now, return sample data but indicate it's from selected databases
        
        // NOTE: Widget extensions have strict execution time limits (30 seconds)
        // Network requests in widgets should be handled carefully with timeouts
        // and fallback to cached/sample data to prevent "Connection invalidated" errors
        
        // Show tasks "from" the selected databases
        var tasks = sampleTasks
        if let firstDatabase = selectedDatabases.first {
            tasks = tasks.map { task in
                TaskItem(
                    id: task.id,
                    title: task.title,
                    isCompleted: task.isCompleted,
                    dueDate: task.dueDate,
                    priority: task.priority,
                    projectName: firstDatabase.name
                )
            }
        }
        
        return tasks
    }
}

// MARK: - Widget Entry

struct TaskListEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskItem]
    let isLoading: Bool
}

// MARK: - Widget View

struct TaskListWidgetView: View {
    var entry: TaskListProvider.Entry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        // Remove the ZStack and background - let the system handle the widget container
        if entry.isLoading {
            loadingView
        } else if entry.tasks.isEmpty {
            emptyStateView
        } else {
            contentView
        }
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
                Image(systemName: "list.bullet")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Tasks")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Task count
                Text("\(entry.tasks.filter { !$0.isCompleted }.count)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            
            // Top 3 tasks
            VStack(spacing: 4) {
                ForEach(entry.tasks.filter { !$0.isCompleted }.prefix(3)) { task in
                    CompactTaskRow(task: task)
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
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                    
                    Text("Task List")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Task count
                Text("\(entry.tasks.filter { !$0.isCompleted }.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Task list (more compact)
            VStack(spacing: 6) {
                ForEach(entry.tasks.prefix(4)) { task in
                    MediumTaskRow(task: task)
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
            
            Text("Loading tasks...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.green)
            
            Text("All caught up!")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("No tasks to show")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Task List View
    
    private var taskListView: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
                .padding(.horizontal, 16)
            
            // Task list
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
                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("NoBuddy")
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
            
            // Task count or configuration needed indicator
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
            Text("+ \(entry.tasks.count - 6) more tasks")
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
}

// MARK: - Compact Task Row (Small Widget)

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

// MARK: - Medium Task Row

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

// MARK: - Sample Data

let sampleTasks: [TaskItem] = [
    TaskItem(
        title: "Review project proposal",
        isCompleted: false,
        dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
        priority: .high,
        projectName: "Work"
    ),
    TaskItem(
        title: "Buy groceries",
        isCompleted: false,
        dueDate: Date(),
        priority: .medium,
        projectName: "Personal"
    ),
    TaskItem(
        title: "Complete iOS app design",
        isCompleted: true,
        dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
        priority: .high,
        projectName: "Development"
    ),
    TaskItem(
        title: "Schedule dentist appointment",
        isCompleted: false,
        dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
        priority: .low,
        projectName: "Health"
    ),
    TaskItem(
        title: "Prepare presentation slides",
        isCompleted: false,
        dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
        priority: .medium,
        projectName: "Work"
    ),
    TaskItem(
        title: "Update LinkedIn profile",
        isCompleted: false,
        priority: .low,
        projectName: "Career"
    ),
    TaskItem(
        title: "Read chapter 5",
        isCompleted: true,
        priority: .medium,
        projectName: "Learning"
    ),
    TaskItem(
        title: "Fix bug in authentication",
        isCompleted: false,
        dueDate: Date(),
        priority: .high,
        projectName: "Development"
    )
]
