import SwiftUI
import WidgetKit

struct SmallWidget: View {
    let widgetApps: [WidgetApp]

    var body: some View {
        if let widgetApp = widgetApps.first {
            VStack {
                Spacer()
            }
            .containerBackground(for: .widget) {
                AppIcon(widgetApp: widgetApp)
                    .scaledToFill()
            }
            .widgetURL(widgetApp.deeplinkURL)
        }
    }
}
