import SwiftUI
import WidgetKit

struct WidgetEntry: TimelineEntry {
    let date: Date
    let widgetApps: [WidgetApp]
    let backgroundColor: Color
}
