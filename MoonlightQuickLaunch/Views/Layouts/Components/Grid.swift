import SwiftUI

struct Grid: View {
    let widgetApps: [WidgetApp]
    let maxNumberOfItems: Int

    private let maxColumnCount: Int = 3

    private var maxNumberOfRow: Int {
        maxNumberOfItems / maxColumnCount
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: maxColumnCount)
    }

    var body: some View {
        GeometryReader { geo in
            let cellHeight = (geo.size.height) / CGFloat(maxNumberOfRow)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(widgetApps.prefix(maxNumberOfItems), id: \.id) { widgetApp in
                    Link(destination: widgetApp.deeplinkURL!) {
                        AppIcon(widgetApp: widgetApp)
                            .frame(height: cellHeight)
                    }
                }
            }
        }
    }
}
