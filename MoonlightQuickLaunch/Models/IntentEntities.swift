import AppIntents
import SwiftUI

enum WidgetLayout: String, AppEnum {
    case small
    case medium
    case large

    static var typeDisplayRepresentation: TypeDisplayRepresentation =
        "Widget layout"

    static var caseDisplayRepresentations:
        [WidgetLayout: DisplayRepresentation] = [
            .small: "Small",
            .medium: "Medium",
            .large: "Large",
        ]
}

enum BackgroundColorOption: String, AppEnum {
    case red, green, orange, blue, yellow, black, gray, white, pink

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Background color"
    static var caseDisplayRepresentations: [BackgroundColorOption: DisplayRepresentation] = [
        .black: "Black",
        .red: "Red",
        .green: "Green",
        .orange: "Orange",
        .blue: "Blue",
        .yellow: "Yellow",
        .gray: "Gray",
        .white: "White",
        .pink: "Pink",
    ]

    var color: Color {
        switch self {
        case .black:
            return .black
        case .red:
            return .red
        case .green:
            return .green
        case .orange:
            return .orange
        case .blue:
            return .blue
        case .yellow:
            return .yellow
        case .gray:
            return .gray
        case .white:
            return .white
        case .pink:
            return .pink
        }
    }
}

struct ApplicationEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation =
        "Application"

    var id: String
    var name: String
    var hostName: String
    var hostUUID: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(hostName)"
        )
    }

    static var defaultQuery = ApplicationEntityQuery()

    init(host: HostPayload, app: AppPayload) {
        id = app.id
        name = app.name
        hostName = host.name
        hostUUID = host.uuid
    }
}

struct ApplicationEntityQuery: EntityQuery {
    func suggestedEntities() async throws -> [ApplicationEntity] {
        try sortedApps()
    }

    func entities(for identifiers: [ApplicationEntity.ID]) async throws
        -> [ApplicationEntity]
    {
        let all = try sortedApps()
        let wanted = Set(identifiers)
        return all.filter { wanted.contains($0.id) }
    }

    private func sortedApps() throws -> [ApplicationEntity] {
        let hosts = WidgetSnapshotStore.getHosts()

        let applications = hosts.flatMap { host in
            host.apps.map { app in
                ApplicationEntity(host: host, app: app)
            }
        }
        .sorted(by: sortApplications)

        return applications
    }

    private func sortApplications(
        _ a: ApplicationEntity,
        _ b: ApplicationEntity
    ) -> Bool {
        if a.hostName == b.hostName {
            return a.name.localizedCaseInsensitiveCompare(b.name)
                == .orderedAscending
        }
        return a.hostName.localizedCaseInsensitiveCompare(b.hostName)
            == .orderedAscending
    }
}
