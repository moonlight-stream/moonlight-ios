import SwiftUI

struct AppIcon: View {
    let widgetApp: WidgetApp

    var body: some View {
        Group {
            if let image = WidgetSnapshotStore.getImage(
                widgetApp.app.iconPath
            ) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.secondary.opacity(0.2))
                    Text(widgetApp.app.name)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(4)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
