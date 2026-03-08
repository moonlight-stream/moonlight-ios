import SwiftUI
import WidgetKit

struct ContentView: View {
    let entry: WidgetTimelineProvider.Entry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.widgetApps.isEmpty {
                VStack(spacing: 10) {
                    VStack(spacing: 2) {
                        Image("MoonlightIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("Moonlight")
                            .font(.headline)

                        Text("Edit widget to add apps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .multilineTextAlignment(.center)
                .padding()
            } else {
                switch family {
                case .systemSmall:
                    SmallWidget(widgetApps: entry.widgetApps)
                case .systemMedium:
                    MediumWidget(
                        widgetApps: entry.widgetApps,
                        backgroundColor: entry.backgroundColor
                    )
                case .systemLarge:
                    LargeWidget(
                        widgetApps: entry.widgetApps,
                        backgroundColor: entry.backgroundColor
                    )
                default: EmptyView()
                }
            }
        }
    }
}
