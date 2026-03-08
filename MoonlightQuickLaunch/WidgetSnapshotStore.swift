import Foundation
import UIKit

enum WidgetSnapshotStore {
    static func getHosts() -> [HostPayload] {
        guard
            let shared = UserDefaults(suiteName: WidgetShared.appGroupId),
            let data = shared.data(forKey: WidgetShared.snapshotKey),
            let snapshot = try? JSONDecoder().decode(
                SnapshotRoot.self,
                from: data
            )
        else {
            return []
        }

        return snapshot.hosts
    }

    static func getImage(_ iconPath: String?) -> UIImage? {
        guard
            let iconPath,
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: WidgetShared.appGroupId
            )
        else { return nil }

        let url = container.appendingPathComponent(iconPath)
        return UIImage(contentsOfFile: url.path)
    }
}
