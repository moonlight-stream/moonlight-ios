import SwiftUI
import WidgetKit

struct WidgetTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in _: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), widgetApps: [], backgroundColor: .gray)
    }

    func snapshot(
        for configuration: ConfigurationIntent,
        in _: Context
    ) async -> WidgetEntry {
        WidgetEntry(
            date: Date(),
            widgetApps: resolveApplications(configuration: configuration),
            backgroundColor: configuration.backgroundColor.color
        )
    }

    func timeline(
        for configuration: ConfigurationIntent,
        in _: Context
    ) async -> Timeline<WidgetEntry> {
        let entry = WidgetEntry(
            date: Date(),
            widgetApps: resolveApplications(configuration: configuration),
            backgroundColor: configuration.backgroundColor.color
        )
        return Timeline(entries: [entry], policy: .never)
    }

    private func resolveApplications(configuration: ConfigurationIntent)
        -> [WidgetApp]
    {
        let hosts = WidgetSnapshotStore.getHosts()

        return configuration.selectedApplications.compactMap { selectedApp in
            guard
                let host = hosts.first(where: {
                    $0.uuid == selectedApp.hostUUID
                }),
                let app = host.apps.first(where: { $0.id == selectedApp.id })
            else {
                return nil
            }

            return WidgetApp(app: app, host: host)
        }
    }
}
