//
//  AppIntent.swift
//  NoBuddyWidget
//
//  Created by Jacob Mount on 7/18/25.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Widget Configuration" }
    static var description: IntentDescription { "Choose which Notion database to display in your widget." }

    // Database selection parameter
    @Parameter(title: "Notion Database")
    var database: DatabaseSelection?
    
    // Optional: Keep the emoji parameter for backwards compatibility or remove it
    @Parameter(title: "Widget Icon", default: "📋")
    var widgetIcon: String
}
