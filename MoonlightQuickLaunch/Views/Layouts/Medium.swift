import SwiftUI
import WidgetKit

struct MediumWidget: View {
    let widgetApps: [WidgetApp]
    let backgroundColor: Color

    private let maxNumberOfApp: Int = 3

    var body: some View {
        Grid(widgetApps: widgetApps, maxNumberOfItems: maxNumberOfApp)
            .containerBackground(backgroundColor, for: .widget)
    }
}
