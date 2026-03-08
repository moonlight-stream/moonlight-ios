import Foundation

enum DeepLinkAction: CustomStringConvertible {
    case unknown
    case launch(hostUUID: String?, appId: String?)

    var description: String {
        switch self {
        case .unknown:
            return "unknown"

        case let .launch(hostUUID, appId):
            return
                "launch(hostUUID: \(hostUUID ?? "nil"), appId: \(appId ?? "nil"))"
        }
    }

    func execute(appDelegate: AppDelegate) {
        switch self {
        case .unknown:
            break

        case let .launch(hostUUID, appId):
            appDelegate.setValue(hostUUID, forKey: "pcUuidToLoad")
            appDelegate.setValue(appId, forKey: "pendingAppIdToLoad")
        }
    }
}

@objcMembers
final class DeepLinkManager: NSObject {
    static func parseURL(_ url: URL?) -> DeepLinkAction? {
        guard let url else { return nil }

        guard
            let components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )
        else {
            return nil
        }

        let action: DeepLinkAction

        switch components.host {
        case "launch":
            // Example: moonlight://launch?host=<uuid>&app=<appId>
            let hostUUID = components.queryItems?.first { $0.name == "host" }?
                .value
            let appId = components.queryItems?.first { $0.name == "app" }?.value
            action = .launch(hostUUID: hostUUID, appId: appId)

        default:
            action = .unknown
        }

        LogTagSwift(
            LOG_I,
            "DeepLink",
            "URL=\(url.absoluteString), action=\(action)"
        )

        return action
    }

    static func handleURL(
        _ url: URL?,
        application _: UIApplication,
        appDelegate: AppDelegate
    ) -> Bool {
        guard let action = parseURL(url) else {
            return false
        }

        switch action {
        case .unknown:
            return false

        default:
            action.execute(appDelegate: appDelegate)
            return true
        }
    }
}
