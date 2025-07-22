import SwiftUI
import WidgetKit

struct SimpleNoBuddyWidget: Widget {
    let kind: String = "SimpleNoBuddyWidget"

    var body: some WidgetConfiguration {
        return StaticConfiguration(kind: kind, provider: SimpleNoBuddyProvider()) { entry in
            SimpleNoBuddyWidgetView(entry: entry)
        }
        .configurationDisplayName("NoBuddy Tasks")
        .description("Shows your Notion tasks and to-dos")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SimpleNoBuddyProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleNoBuddyEntry {
        print("🔴 [SimpleNoBuddyProvider] placeholder called")
        // Return empty state for placeholder
        return SimpleNoBuddyEntry(date: Date(), tasks: [], error: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleNoBuddyEntry) -> ()) {
        print("🔴 [SimpleNoBuddyProvider] getSnapshot called")
        
        Task {
            do {
                let widgetTasks = try await WidgetTaskLoader.shared.loadCachedTasks(limit: 6)
                print("🔴 [SimpleNoBuddyProvider] Loaded \(widgetTasks.count) real tasks for snapshot")
                
                let tasks = widgetTasks.map { widgetTask in
                    SimpleTaskItem(
                        title: widgetTask.title,
                        isCompleted: widgetTask.isCompleted,
                        priority: widgetTask.priority.displayName
                    )
                }
                
                let entry = SimpleNoBuddyEntry(date: Date(), tasks: tasks, error: nil)
                completion(entry)
            } catch {
                print("🔴 [SimpleNoBuddyProvider] Failed to load real tasks: \(error)")
                // Return empty tasks array with error instead of sample data
                let entry = SimpleNoBuddyEntry(date: Date(), tasks: [], error: error)
                completion(entry)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleNoBuddyEntry>) -> ()) {
        print("🔴 [SimpleNoBuddyProvider] getTimeline called")
        
        Task {
            do {
                let widgetTasks = try await WidgetTaskLoader.shared.loadCachedTasks(limit: 6)
                print("🔴 [SimpleNoBuddyProvider] Loaded \(widgetTasks.count) real tasks for timeline")
                
                let tasks = widgetTasks.map { widgetTask in
                    SimpleTaskItem(
                        title: widgetTask.title,
                        isCompleted: widgetTask.isCompleted,
                        priority: widgetTask.priority.displayName
                    )
                }
                
                let entry = SimpleNoBuddyEntry(date: Date(), tasks: tasks, error: nil)
                let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))) // Refresh every 15 minutes
                completion(timeline)
            } catch {
                print("🔴 [SimpleNoBuddyProvider] Failed to load real tasks: \(error)")
                // Return empty tasks array with error instead of sample data
                let entry = SimpleNoBuddyEntry(date: Date(), tasks: [], error: error)
                let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(5 * 60))) // Retry in 5 minutes
                completion(timeline)
            }
        }
    }
}

struct SimpleNoBuddyEntry: TimelineEntry {
    let date: Date
    let tasks: [SimpleTaskItem]
    let error: Error?
}

struct SimpleNoBuddyWidgetView: View {
    var entry: SimpleNoBuddyProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .medium))
                
                Text("NoBuddy")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(entry.tasks.filter { !$0.isCompleted }.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.bottom, 8)
            
            // Task List or Empty State
            if entry.tasks.isEmpty {
                VStack(spacing: 8) {
                    if entry.error != nil {
                        // Error state
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.title2)
                        
                        Text("Unable to load tasks")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Try opening NoBuddy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if WidgetSupport.widgetNeedsConfiguration() {
                        // Configuration needed
                        Image(systemName: "gear")
                            .foregroundColor(.orange)
                            .font(.title2)
                        
                        Text("Setup Required")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Select databases in app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        // All caught up
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        Text("All caught up!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("No pending tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.tasks.prefix(maxTasksForFamily), id: \.id) { task in
                        TaskRowView(task: task)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill, for: .widget)
    }
    
    private var maxTasksForFamily: Int {
        switch widgetFamily {
        case .systemSmall: return 3
        case .systemMedium: return 4  
        case .systemLarge: return 6
        default: return 4
        }
    }
}

struct TaskRowView: View {
    let task: SimpleTaskItem
    
    var body: some View {
        HStack(spacing: 8) {
            // Checkbox
            Circle()
                .fill(task.isCompleted ? .green : .clear)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(task.isCompleted ? .green : .gray.opacity(0.6), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(task.isCompleted ? 1 : 0)
                )
            
            // Task content
            Text(task.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(task.isCompleted ? .secondary : .primary)
                .strikethrough(task.isCompleted)
                .lineLimit(1)
            
            Spacer()
            
            // Priority indicator
            if task.priority == "Urgent" {
                Circle()
                    .fill(.red)
                    .frame(width: 4, height: 4)
            } else if task.priority == "High" {
                Circle()
                    .fill(.orange)
                    .frame(width: 4, height: 4)
            } else if task.priority == "Medium" {
                Circle()
                    .fill(.yellow)
                    .frame(width: 4, height: 4)
            }
        }
    }
}

struct SimpleTaskItem: Identifiable {
    let id = UUID()
    let title: String
    let isCompleted: Bool
    let priority: String
}

// Sample data removed - widget now uses real Core Data
