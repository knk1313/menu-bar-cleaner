import AppKit
import ApplicationServices

/// 他アプリのメニューバー項目（状態アイコン）。
struct MenuBarItem {
    let appName: String
    /// 項目の説明（VoiceOver 向けの説明。空のことが多い）
    let title: String
    /// 画面の左上を原点とする座標（x は Cocoa の座標と同じ）
    let frame: CGRect
    let icon: NSImage?
    fileprivate let element: AXUIElement

    var displayName: String {
        if title.isEmpty || title == appName { return appName }
        return "\(appName)（\(title)）"
    }
}

/// Accessibility API で、他アプリのメニューバー項目を読み取り、クリックする。
///
/// OS の内部の挙動に依存する箇所はこのファイルに集める。
/// - 各アプリの AXExtrasMenuBar 属性の子要素が、そのアプリの状態アイコンになる
/// - macOS 26 では、CGWindowList から見た状態アイコンのウィンドウの持ち主は
///   すべて「コントロールセンター」になり、どのアプリの項目か区別できない。そのため AX を使う
/// - アクセシビリティの権限が要る。権限がなくても、隠す・表示する機能そのものは動く
enum MenuBarItems {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// 権限の確認ダイアログを出す（システム設定のアクセシビリティを開く案内）
    static func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 表示中の全アプリのメニューバー項目を、左から順に返す。権限がなければ空。
    static func all() -> [MenuBarItem] {
        guard isTrusted else { return [] }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var result: [MenuBarItem] = []

        for app in NSWorkspace.shared.runningApplications where app.processIdentifier != ownPID {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            // 応答しないアプリでメニューが固まらないように、待つ時間を短くする
            AXUIElementSetMessagingTimeout(appElement, 0.2)

            guard let bar: AXUIElement = attribute(appElement, "AXExtrasMenuBar"),
                  let children: [AXUIElement] = attribute(bar, kAXChildrenAttribute) else { continue }

            for child in children {
                guard let frame = frame(of: child), frame.width > 0, frame.height > 0 else { continue }
                let title: String = attribute(child, kAXDescriptionAttribute)
                    ?? attribute(child, kAXTitleAttribute) ?? ""
                result.append(MenuBarItem(
                    appName: app.localizedName ?? "不明なアプリ",
                    title: title,
                    frame: frame,
                    icon: app.icon,
                    element: child
                ))
            }
        }
        return result.sorted { $0.frame.minX < $1.frame.minX }
    }

    /// 項目をクリックしたのと同じ操作（AXPress）をする。成功したら true。
    @discardableResult
    static func press(_ item: MenuBarItem) -> Bool {
        AXUIElementPerformAction(item.element, kAXPressAction as CFString) == .success
    }

    /// 項目の今の位置を読み直す（展開した後など、位置が変わったとき用）
    static func currentFrame(of item: MenuBarItem) -> CGRect? {
        frame(of: item.element)
    }

    // MARK: - AX の読み取り

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }
}
