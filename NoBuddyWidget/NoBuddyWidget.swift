import WidgetKit
import SwiftUI
import Intents

// MARK: - Widget Entry

struct NoBuddyWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let data: WidgetData?
    let error: String?
    
    static let placeholder = NoBuddyWidgetEntry(
        date: Date(),
        configuration: ConfigurationIntent(),
        data: WidgetData.placeholder,
        error: nil
    )
}

// MARK: - Widget Data Model

struct WidgetData {
    let tokenName: String
    let workspaceName: String
    let databases: [WidgetDatabase]
    let pages: [WidgetPage]
    let lastUpdated: Date
    
    static let placeholder = WidgetData(
        tokenName: "My Workspace",
        workspaceName: "Personal",
        databases: [
            WidgetDatabase(id: "1", title: "Tasks", itemCount: 12, lastModified: Date()),
            WidgetDatabase(id: "2", title: "Notes", itemCount: 8, lastModified: Date()),
            WidgetDatabase(id: "3", title: "Projects", itemCount: 3, lastModified: Date())
        ],
        pages: [
            WidgetPage(id: "1", title: "Meeting Notes", lastModified: Date()),
            WidgetPage(id: "2", title: "Project Roadmap", lastModified: Date()),
            WidgetPage(id: "3", title: "Weekly Review", lastModified: Date())
        ],
        lastUpdated: Date()
    )
}

struct WidgetDatabase {
    let id: String
    let title: String
    let itemCount: Int
    let lastModified: Date
}

struct WidgetPage {
    let id: String
    let title: String
    let lastModified: Date
}

// MARK: - Timeline Provider

struct NoBuddyWidgetTimelineProvider: IntentTimelineProvider {
    
    func placeholder(in context: Context) -> NoBuddyWidgetEntry {
        return .placeholder
    }
    
    func getSnapshot(
        for configuration: ConfigurationIntent,
        in context: Context,
        completion: @escaping (NoBuddyWidgetEntry) -> Void
    ) {
        let entry = NoBuddyWidgetEntry.placeholder
        completion(entry)
    }
    
    func getTimeline(
        for configuration: ConfigurationIntent,
        in context: Context,
        completion: @escaping (Timeline<NoBuddyWidgetEntry>) -> Void
    ) {
        Task {
            await generateTimeline(configuration: configuration, completion: completion)
        }
    }
    
    private func generateTimeline(
        configuration: ConfigurationIntent,
        completion: @escaping (Timeline<NoBuddyWidgetEntry>) -> Void
    ) async {
        let now = Date()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now
        
        // Load data from shared container
        let widgetData = await loadWidgetData(for: configuration)
        
        let entry = NoBuddyWidgetEntry(
            date: now,
            configuration: configuration,
            data: widgetData,
            error: nil
        )
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadWidgetData(for configuration: ConfigurationIntent) async -> WidgetData? {
        // In a real implementation, this would load from the shared App Group container
        // For now, return placeholder data
        return WidgetData.placeholder
    }
}

// MARK: - Widget Views

struct NoBuddyWidgetView: View {
    let entry: NoBuddyWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        Group {
            if let error = entry.error {
                ErrorView(error: error)
            } else if let data = entry.data {
                switch family {
                case .systemSmall:
                    SmallWidgetView(data: data)
                case .systemMedium:
                    MediumWidgetView(data: data)
                case .systemLarge:
                    LargeWidgetView(data: data)
                default:
                    SmallWidgetView(data: data)
                }
            } else {
                PlaceholderView()
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Size-Specific Views

struct SmallWidgetView: View {
    let data: WidgetData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("NoBuddy")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(data.workspaceName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            Spacer()
            
            // Quick Stats
            VStack(alignment: .leading, spacing: 4) {
                Text("\(data.databases.count)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Databases")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Updated \(data.lastUpdated.formatted(.relative(presentation: .numeric)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
    }
}

struct MediumWidgetView: View {
    let data: WidgetData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NoBuddy")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(data.workspaceName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(data.databases.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Text("databases")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Recent Databases
            if !data.databases.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(data.databases.prefix(3), id: \.id) { database in
                        HStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 6, height: 6)
                            
                            Text(database.title)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(database.itemCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Footer
            HStack {
                Text("Updated \(data.lastUpdated.formatted(.relative(presentation: .numeric)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct LargeWidgetView: View {
    let data: WidgetData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NoBuddy")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(data.workspaceName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(data.databases.count)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("databases")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Databases Section
            if !data.databases.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Databases")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ForEach(data.databases.prefix(4), id: \.id) { database in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(database.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                Text("\(database.itemCount) items")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(database.lastModified.formatted(.relative(presentation: .numeric)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            
            // Recent Pages Section
            if !data.pages.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Pages")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ForEach(data.pages.prefix(3), id: \.id) { page in
                        HStack {
                            Text(page.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(page.lastModified.formatted(.relative(presentation: .numeric)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Footer
            HStack {
                Text("Last updated \(data.lastUpdated.formatted(.relative(presentation: .numeric)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Supporting Views

struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.title)
                .foregroundColor(.gray)
            
            Text("NoBuddy")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Configure your widget")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct ErrorView: View {
    let error: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding()
    }
}

// MARK: - Widget Configuration

struct NoBuddyWidget: Widget {
    let kind: String = "NoBuddyWidget"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: ConfigurationIntent.self,
            provider: NoBuddyWidgetTimelineProvider()
        ) { entry in
            NoBuddyWidgetView(entry: entry)
        }
        .configurationDisplayName("NoBuddy")
        .description("Stay connected to your Notion workspace")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle

@main
struct NoBuddyWidgetBundle: WidgetBundle {
    var body: some Widget {
        NoBuddyWidget()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    NoBuddyWidget()
} timeline: {
    NoBuddyWidgetEntry.placeholder
}

#Preview(as: .systemMedium) {
    NoBuddyWidget()
} timeline: {
    NoBuddyWidgetEntry.placeholder
}

#Preview(as: .systemLarge) {
    NoBuddyWidget()
} timeline: {
    NoBuddyWidgetEntry.placeholder
}