//
//  DatabaseSelection.swift
//  NoBuddyWidget
//
//  Created by Assistant on 7/28/25.
//

import Foundation
import AppIntents

/// Represents a database selection for widget configuration
struct DatabaseSelection: AppEntity, Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let workspaceName: String?
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Database")
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: workspaceName.map { LocalizedStringResource(stringLiteral: $0) },
            image: .init(systemName: "folder")
        )
    }
    
    static var defaultQuery = DatabaseQuery()
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable conformance
    static func == (lhs: DatabaseSelection, rhs: DatabaseSelection) -> Bool {
        lhs.id == rhs.id
    }
}

/// Query handler for database selections
struct DatabaseQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DatabaseSelection] {
        // Get available databases from cache
        let availableDatabases = WidgetSupport.getAvailableDatabasesFromCache()
        
        return availableDatabases
            .filter { identifiers.contains($0.id) }
            .map { database in
                DatabaseSelection(
                    id: database.id,
                    name: database.name,
                    icon: database.icon,
                    workspaceName: database.workspaceName
                )
            }
    }
    
    func suggestedEntities() async throws -> [DatabaseSelection] {
        // Return all available databases from cache
        let availableDatabases = WidgetSupport.getAvailableDatabasesFromCache()
        
        return availableDatabases.map { database in
            DatabaseSelection(
                id: database.id,
                name: database.name,
                icon: database.icon,
                workspaceName: database.workspaceName
            )
        }
    }
    
    func defaultResult() async -> DatabaseSelection? {
        // Return the first available database as default
        let availableDatabases = WidgetSupport.getAvailableDatabasesFromCache()
        guard let firstDatabase = availableDatabases.first else { return nil }
        
        return DatabaseSelection(
            id: firstDatabase.id,
            name: firstDatabase.name,
            icon: firstDatabase.icon,
            workspaceName: firstDatabase.workspaceName
        )
    }
}

/// Options provider for database parameter
struct DatabaseOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [DatabaseSelection] {
        // Get available databases from cache
        let availableDatabases = WidgetSupport.getAvailableDatabasesFromCache()
        
        guard !availableDatabases.isEmpty else {
            // Return a helpful message if no databases are available
            return [DatabaseSelection(
                id: "none",
                name: "Open NoBuddy app to sync databases",
                icon: "📱",
                workspaceName: "No data available"
            )]
        }
        
        return availableDatabases.map { database in
            DatabaseSelection(
                id: database.id,
                name: database.name,
                icon: database.icon,
                workspaceName: database.workspaceName
            )
        }
    }
}
