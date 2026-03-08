import Foundation

struct WidgetApp: Identifiable {
    var id: String { "\(host.uuid)-\(app.id)" }
    let app: AppPayload
    let host: HostPayload

    var deeplinkURL: URL? {
        var components = URLComponents()
        components.scheme = "moonlight"
        components.host = "launch"
        components.queryItems = [
            URLQueryItem(name: "host", value: host.uuid),
            URLQueryItem(name: "app", value: app.id),
        ]

        return components.url
    }
}
