import CoreGraphics
import Foundation

/// 1つの要素（左スティック／十字キー／ABXY）の位置・サイズ情報。
struct OverlayElementLayout: Codable {
    var anchorX: String
    var offsetX: CGFloat
    var anchorY: String
    var offsetY: CGFloat
    var scale: CGFloat
}

/// オーバーレイ全体のレイアウト。
struct OverlayLayout: Codable {
    var leftStick: OverlayElementLayout
    var dpad: OverlayElementLayout
    var abxy: OverlayElementLayout
    /// ボタンスロット("abxy_top"等) → 割り当てるOverlayButtonのmappingKey
    var buttonMapping: [String: String]

    static let defaultButtonMapping: [String: String] = [
        "abxy_top": "y", "abxy_left": "x", "abxy_right": "b", "abxy_bottom": "a",
        "dpad_up": "dpadUp", "dpad_down": "dpadDown", "dpad_left": "dpadLeft", "dpad_right": "dpadRight"
    ]

    static let defaultLayout = OverlayLayout(
        leftStick: OverlayElementLayout(anchorX: "leading", offsetX: 80, anchorY: "bottom", offsetY: 120, scale: 1.0),
        dpad: OverlayElementLayout(anchorX: "trailing", offsetX: 260, anchorY: "bottom", offsetY: 100, scale: 1.0),
        abxy: OverlayElementLayout(anchorX: "trailing", offsetX: 90, anchorY: "bottom", offsetY: 120, scale: 1.0),
        buttonMapping: defaultButtonMapping
    )

    func resolvedPosition(for element: OverlayElementLayout, in size: CGSize) -> CGPoint {
        let x = element.anchorX == "leading" ? element.offsetX : size.width - element.offsetX
        let y = element.anchorY == "top" ? element.offsetY : size.height - element.offsetY
        return CGPoint(x: x, y: y)
    }
}

/// レイアウトをJSONファイルとして端末に保存・読み込みする。
final class OverlayLayoutStore {
    static let shared = OverlayLayoutStore()

    private let fileURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("overlay_layout.json")
    }

    func load() -> OverlayLayout {
        guard let data = try? Data(contentsOf: fileURL),
              let layout = try? JSONDecoder().decode(OverlayLayout.self, from: data) else {
            return .defaultLayout
        }
        return layout
    }

    func save(_ layout: OverlayLayout) {
        guard let data = try? JSONEncoder().encode(layout) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
