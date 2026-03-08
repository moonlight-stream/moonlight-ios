import SwiftUI
import WidgetKit

struct LargeWidget: View {
    let widgetApps: [WidgetApp]
    let backgroundColor: Color

    private let maxNumberOfApp: Int = 6

    var body: some View {
        Grid(widgetApps: widgetApps, maxNumberOfItems: maxNumberOfApp)
            .containerBackground(backgroundColor, for: .widget)
    }
}
