import SwiftUI
import CoreData

/// Example view demonstrating TaskCache usage
struct TaskCacheExampleView: View {
    @StateObject private var taskManager = TaskCacheManager.shared
    @StateObject private var tokenManager = SecureTokenManager()
    
    @State private var selectedDatabase: CDDatabase?
    @State private var selectedToken: NotionToken?
    @State private var apiClient: NotionAPIClient?
    @State private var tasks: [TaskCache] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
                // Database Selection
                Section("Select Database") {
                    if let database = selectedDatabase {
                        HStack {
                            Text(database.icon ?? "📋")
                            Text(database.title)
                            Spacer()
                            Button("Change") {
                                selectedDatabase = nil
                            }
                        }
                    } else {
                        Button("Select a Database") {
                            // Show database picker
                        }
                    }
                }
                
                // Task List
                if !tasks.isEmpty {
                    Section("Tasks") {
                        ForEach(tasks, id: \.notionPageID) { task in
                            TaskRow(task: task)
                        }
                    }
                    
                    // Task Statistics
                    Section("Statistics") {
                        HStack {
                            Label("\(overdueCount) Overdue", systemImage: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Spacer()
                        }
                        HStack {
                            Label("\(todayCount) Due Today", systemImage: "calendar")
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        HStack {
                            Label("\(highPriorityCount) High Priority", systemImage: "flag.fill")
                                .foregroundColor(.yellow)
                            Spacer()
                        }
                    }
                }
                
                // Cache Status
                Section("Cache Status") {
                    if let database = selectedDatabase {
                        HStack {
                            Text("Last Updated")
                            Spacer()
                            Text(database.cachedAt, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Refresh Tasks") {
                        Task {
                            await refreshTasks()
                        }
                    }
                    .disabled(isLoading || selectedDatabase == nil)
                }
            }
            .navigationTitle("Task Cache Example")
            .overlay {
                if isLoading {
                    ProgressView("Loading tasks...")
                        .padding()
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
        .task {
            await setupAPIClient()
            await loadTasks()
        }
    }
    
    // MARK: - Computed Properties
    
    var overdueCount: Int {
        tasks.filter { $0.isOverdue }.count
    }
    
    var todayCount: Int {
        tasks.filter { $0.isDueToday }.count
    }
    
    var highPriorityCount: Int {
        tasks.filter { $0.priorityLevel == .high || $0.priorityLevel == .urgent }.count
    }
    
    // MARK: - Methods
    
    private func loadTasks() async {
        guard let database = selectedDatabase else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            tasks = try await taskManager.fetchTasks(for: database)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func refreshTasks() async {
        guard let database = selectedDatabase,
              let apiClient = apiClient else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await taskManager.refreshTasks(for: database, using: apiClient)
            tasks = try await taskManager.fetchTasks(for: database)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func setupAPIClient() async {
        // In a real app, you would select a token from available tokens
        // For this example, we'll use the first available token
        await tokenManager.loadTokens()
        if let firstToken = tokenManager.tokens.first {
            selectedToken = firstToken
            apiClient = NotionAPIClient(token: firstToken.token)
        }
    }
}

// MARK: - Task Row View

struct TaskRow: View {
    let task: TaskCache
    
    var body: some View {
        HStack {
            // Status Icon
            Text(task.taskStatus.emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(task.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    // Priority
                    Label(task.priorityLevel.displayName, systemImage: "flag.fill")
                        .font(.caption)
                        .foregroundColor(priorityColor)
                    
                    // Due Date
                    if let dueDate = task.dueDate {
                        Text(dueDate, style: .date)
                            .font(.caption)
                            .foregroundColor(dueDateColor)
                    }
                    
                    // Assignee
                    if let assignee = task.assignee {
                        Label(assignee, systemImage: "person.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Sync Status
            if task.taskSyncStatus != .synced {
                Image(systemName: syncStatusIcon)
                    .foregroundColor(syncStatusColor)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var priorityColor: Color {
        switch task.priorityLevel {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        case .none: return .gray
        }
    }
    
    private var dueDateColor: Color {
        if task.isOverdue {
            return .red
        } else if task.isDueToday {
            return .orange
        } else {
            return .secondary
        }
    }
    
    private var syncStatusIcon: String {
        switch task.taskSyncStatus {
        case .pending: return "arrow.triangle.2.circlepath"
        case .syncing: return "arrow.triangle.2.circlepath.circle.fill"
        case .failed: return "exclamationmark.circle"
        case .conflict: return "exclamationmark.triangle"
        case .synced: return "checkmark.circle"
        }
    }
    
    private var syncStatusColor: Color {
        switch task.taskSyncStatus {
        case .pending, .syncing: return .blue
        case .failed, .conflict: return .red
        case .synced: return .green
        }
    }
}

// MARK: - Preview

#Preview {
    TaskCacheExampleView()
}

// MARK: - Usage Example in Widget

struct TaskWidgetExample: View {
    @State private var widgetTasks: [WidgetTask] = []
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(widgetTasks) { task in
                HStack {
                    Text(task.status.emoji)
                    
                    VStack(alignment: .leading) {
                        Text(task.title)
                            .font(.caption)
                            .lineLimit(1)
                        
                        if let dueDate = task.dueDate {
                            Text(dueDate, style: .relative)
                                .font(.caption2)
                                .foregroundColor(task.isOverdue ? .red : .secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Text(task.priority.emoji)
                        .font(.caption2)
                }
            }
        }
        .task {
            do {
                widgetTasks = try await TaskCacheManager.shared.fetchTasksForWidget(limit: 3)
            } catch {
                print("Failed to fetch widget tasks: \(error)")
            }
        }
    }
}
