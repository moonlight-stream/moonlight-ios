import SwiftUI
import WidgetKit

struct MoonlightQuickLaunch: Widget {
    let kind: String = "MoonlightQuickLaunch"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationIntent.self,
            provider: WidgetTimelineProvider()
        ) { entry in
            ContentView(entry: entry)
        }
    }
}
