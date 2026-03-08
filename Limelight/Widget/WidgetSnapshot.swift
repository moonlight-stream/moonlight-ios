import Foundation
import WidgetKit

@objcMembers
final class WidgetSnapshot: NSObject {
    private static let iconsRootDir = "icons"

    @objc(exportSnapshotFromHosts:)
    static func exportSnapshot(from hostsArray: NSArray) {
        let hosts = hostsArray as? [TemporaryHost] ?? []

        let payloadHosts: [HostPayload] = hosts.map { host in
            let appsSet = host.appList as? Set<TemporaryApp> ?? []

            let appPayloads: [AppPayload] = appsSet.compactMap { app in
                generateAppPayloadWithIcon(app: app, host: host)
            }

            return HostPayload(
                uuid: host.uuid,
                name: host.name,
                apps: appPayloads
            )
        }

        persistSnapshotAndReloadWidgets(payloadHosts)
    }

    // MARK: - Private

    private static func generateAppPayloadWithIcon(
        app: TemporaryApp,
        host: TemporaryHost
    ) -> AppPayload? {
        guard let appId = app.id,
              let appName = app.name,
              let container = FileManager.default.containerURL(
                  forSecurityApplicationGroupIdentifier: WidgetShared.appGroupId
              ),
              let iconSrcPath = AppAssetManager.boxArtPath(for: app),
              FileManager.default.fileExists(atPath: iconSrcPath)
        else { return nil }

        let iconsRoot = container.appendingPathComponent(
            iconsRootDir,
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: iconsRoot,
            withIntermediateDirectories: true
        )

        let copiedIconPath = copyIconIfNeeded(
            srcPath: iconSrcPath,
            hostUuid: host.uuid,
            appId: appId,
            containerIconsRoot: iconsRoot
        )

        return AppPayload(id: appId, name: appName, iconPath: copiedIconPath)
    }

    private static func persistSnapshotAndReloadWidgets(_ hosts: [HostPayload]) {
        let root = SnapshotRoot(
            version: 1,
            generatedAt: Int64(Date().timeIntervalSince1970),
            hosts: hosts
        )

        guard let json = try? JSONEncoder().encode(root) else { return }

        let shared = UserDefaults(suiteName: WidgetShared.appGroupId)
        shared?.set(json, forKey: WidgetShared.snapshotKey)

        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private static func copyIconIfNeeded(
        srcPath: String,
        hostUuid: String,
        appId: String,
        containerIconsRoot: URL
    ) -> String? {
        let destinationDirectory = containerIconsRoot.appendingPathComponent(hostUuid, isDirectory: true)
        try? FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let destinationURL = destinationDirectory.appendingPathComponent(appId).appendingPathExtension("png")

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        do {
            try FileManager.default.copyItem(atPath: srcPath, toPath: destinationURL.path)
            return "\(iconsRootDir)/\(hostUuid)/\(appId).png"
        } catch {
            return nil
        }
    }
}
