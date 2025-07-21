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
        .supportedFamilies([.systemLarge])
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
        // In a real implementation, this would fetch from Notion API
        // For now, return sample data
        return sampleTasks
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
    
    var body: some View {
        ZStack {
            // Background with glass morphism effect
            backgroundView
            
            if entry.isLoading {
                loadingView
            } else if entry.tasks.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
    }
    
    // MARK: - Background View
    
    private var backgroundView: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.black.opacity(0.8), Color(white: 0.05)]
                        : [Color(white: 0.95), Color.white.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
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
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
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
                .background(.ultraThinMaterial)
                .padding(.horizontal, 16)
            
            // Task list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(entry.tasks.prefix(6)) { task in
                        TaskRowWidget(task: task)
                    }
                    
                    if entry.tasks.count > 6 {
                        moreTasksView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            // Icon and title
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "list.bullet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text("Task List")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Task count
            if !entry.tasks.isEmpty {
                Text("\(entry.tasks.filter { !$0.isCompleted }.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                    )
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
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
    }
}

// MARK: - Task Row Widget

struct TaskRowWidget: View {
    let task: TaskItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox - Simple tap without intent for now
            Button(action: {
                // For now, just a regular button without App Intent
                // In a real implementation, this would trigger a local update
            }) {
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
            }
            .buttonStyle(PlainButtonStyle())
            
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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial.opacity(0.3))
        )
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

