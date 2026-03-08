import Foundation

enum WidgetShared {
    static let appGroupId = "group.com.moonlight-stream.widget"
    static let snapshotKey = "moonlight.widget.snapshot"
}

struct AppPayload: Codable {
    let id: String
    let name: String
    let iconPath: String?
}

struct HostPayload: Codable {
    let uuid: String
    let name: String
    let apps: [AppPayload]
}

struct SnapshotRoot: Codable {
    let version: Int
    let generatedAt: Int64
    let hosts: [HostPayload]
}
