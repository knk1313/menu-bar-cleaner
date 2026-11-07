import AppKit
import MenuBarCleanerCore

/// メニューバーに置く 2 つの状態アイコンを管理する。
///
/// - トグル（‹ / ›）：クリックで、隠した項目の表示と折りたたみを切り替える。右クリックでメニュー
/// - 区切り（|）：これより左にある項目が、折りたたんだときに隠れる
///
/// 隠すときは、区切りを画面の幅より長くし、その左の項目を画面の外へ押し出す。
/// トグル自体を伸ばして区切りを兼ねさせることはできない。macOS 26 では、長く伸ばした状態アイコンは
/// まるごと描かれなくなり、トグルが見えなくなるため（docs/research.md）。
///
/// 利用者は ⌘ を押しながら他アプリのアイコンをドラッグし、区切りの左右に振り分ける（macOS の標準の操作）。
/// 区切りとトグルの位置は autosaveName により macOS が保存するため、再起動後も振り分けが残る。
final class StatusBarController: NSObject {
    private let settings: Settings
    private let toggleItem: NSStatusItem
    private let separatorItem: NSStatusItem
    private var hotKey: HotKey?
    private var autoCollapseTimer: Timer?
    private var lastHotKeyError: String?

    private(set) var isCollapsed = false

    /// 展開してから自動で折りたたむまでの秒数
    private let autoCollapseInterval: TimeInterval = 15

    init(settings: Settings) {
        self.settings = settings
        // 後から作った状態アイコンほど左に並ぶ。トグルを先に作り、区切りをその左に置く
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggleItem.autosaveName = "MenuBarCleaner.Toggle"
        separatorItem = NSStatusBar.system.statusItem(withLength: Layout.expandedSeparatorLength)
        separatorItem.autosaveName = "MenuBarCleaner.Separator"
        super.init()

        configureToggle()
        configureSeparator()
        applyHotKeySetting()
    }

    // MARK: - 見た目

    private func configureToggle() {
        guard let button = toggleItem.button else { return }
        button.target = self
        button.action = #selector(toggleClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateToggleImage()
    }

    private func configureSeparator() {
        guard let button = separatorItem.button else { return }
        button.image = Self.separatorImage
        button.setAccessibilityLabel("Menu Bar Cleaner の区切り。これより左の項目を隠す")
        // 区切りはクリックしても何もしない（折りたたみ中は、空いたメニューバーの大部分を覆うため）
        button.cell?.isEnabled = false
    }

    private func updateToggleImage() {
        guard let button = toggleItem.button else { return }
        let symbol = isCollapsed ? "chevron.left" : "chevron.right"
        let label = isCollapsed ? "隠した項目を表示" : "項目を隠す"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        image?.isTemplate = true
        button.image = image
        button.toolTip = "\(label)（\(HotKey.defaultDisplay)）。右クリックでメニュー"
    }

    private static let separatorImage: NSImage = {
        let image = NSImage(size: NSSize(width: 4, height: 16), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 2, height: rect.height - 2),
                         xRadius: 1, yRadius: 1).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()

    // MARK: - 展開と折りたたみ

    /// 区切りがトグルの左にあるか。位置が取れないときは、正しいものとみなす
    var isOrderValid: Bool {
        guard let separatorFrame = separatorItem.button?.window?.frame,
              let toggleFrame = toggleItem.button?.window?.frame else { return true }
        return Layout.isOrderValid(separatorMinX: separatorFrame.minX, toggleMinX: toggleFrame.minX)
    }

    /// 区切りの左端の x。これより左の項目が「隠れている」
    var separatorMinX: CGFloat? {
        separatorItem.button?.window?.frame.minX
    }

    func toggle() {
        isCollapsed ? expand() : collapse()
    }

    /// 起動直後に折りたたむ。
    /// 起動の直後は、macOS が状態アイコンを保存された位置へ並べ直す前で、位置が正しく取れない。
    /// そのため、並び順が正しくなるまで少し待ってから折りたたむ。待っても正しくなければ案内を出す。
    func collapseAfterLaunch(remainingAttempts: Int = 10) {
        if isOrderValid {
            collapse()
        } else if remainingAttempts > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.collapseAfterLaunch(remainingAttempts: remainingAttempts - 1)
            }
        } else {
            showOrderWarning()
        }
    }

    func collapse() {
        guard !isCollapsed else { return }
        guard isOrderValid else {
            showOrderWarning()
            return
        }
        cancelAutoCollapse()
        separatorItem.button?.image = nil
        separatorItem.length = Layout.collapsedSeparatorLength(
            screenWidths: NSScreen.screens.map { $0.frame.width }
        )
        isCollapsed = true
        updateToggleImage()
    }

    func expand() {
        guard isCollapsed else { return }
        separatorItem.length = Layout.expandedSeparatorLength
        separatorItem.button?.image = Self.separatorImage
        isCollapsed = false
        updateToggleImage()
        scheduleAutoCollapse()
    }

    private func scheduleAutoCollapse(after interval: TimeInterval? = nil) {
        cancelAutoCollapse()
        guard settings.autoCollapse else { return }
        autoCollapseTimer = Timer.scheduledTimer(withTimeInterval: interval ?? autoCollapseInterval,
                                                 repeats: false) { [weak self] _ in
            self?.autoCollapseFired()
        }
    }

    private func cancelAutoCollapse() {
        autoCollapseTimer?.invalidate()
        autoCollapseTimer = nil
    }

    private func autoCollapseFired() {
        // メニューを開いている途中や、メニューバーの上にポインタがあるときは待つ
        if Self.isAnyMenuOpen || Self.isPointerInMenuBar {
            scheduleAutoCollapse(after: 3)
            return
        }
        collapse()
    }

    /// 他アプリを含め、ポップアップメニューが画面に出ているか。
    /// ウィンドウの階層と位置だけを見るため、画面収録の権限は要らない
    private static var isAnyMenuOpen: Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        return windows.contains { ($0[kCGWindowLayer as String] as? Int) == menuLevel }
    }

    private static var isPointerInMenuBar: Bool {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) else { return false }
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        return location.y >= screen.frame.maxY - max(menuBarHeight, 24)
    }

    // MARK: - クリック

    @objc private func toggleClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isMenuClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        if isMenuClick {
            showMenu()
        } else {
            toggle()
        }
    }

    private func showMenu() {
        let menu = buildMenu()
        toggleItem.menu = menu
        toggleItem.button?.performClick(nil)
        toggleItem.menu = nil
    }

    // MARK: - メニュー

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let toggleTitle = isCollapsed ? "隠した項目を表示" : "項目を隠す"
        menu.addItem(item(toggleTitle, #selector(toggleFromMenu)))

        let hiddenItem = NSMenuItem(title: "隠れている項目", action: nil, keyEquivalent: "")
        hiddenItem.submenu = buildHiddenItemsMenu()
        menu.addItem(hiddenItem)

        menu.addItem(.separator())

        let autoCollapse = item("\(Int(autoCollapseInterval))秒後に自動で隠す", #selector(toggleAutoCollapse))
        autoCollapse.state = settings.autoCollapse ? .on : .off
        menu.addItem(autoCollapse)

        let hotKeyItem = item("ショートカット \(HotKey.defaultDisplay)", #selector(toggleHotKey))
        hotKeyItem.state = settings.hotKeyEnabled ? .on : .off
        if let lastHotKeyError {
            hotKeyItem.toolTip = lastHotKeyError
            hotKeyItem.title += "（使用できません）"
        }
        menu.addItem(hotKeyItem)

        let login = item("ログイン時に起動", #selector(toggleLoginItem))
        if LoginItem.isAvailable {
            login.state = LoginItem.isEnabled ? .on : .off
            if LoginItem.requiresApproval {
                login.title += "（システム設定で許可が必要）"
                login.state = .mixed
            }
        } else {
            login.isEnabled = false
            login.toolTip = ".app として起動したときだけ設定できます"
        }
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("使い方…", #selector(showHelp)))
        menu.addItem(item("Menu Bar Cleaner を終了", #selector(quit), key: "q"))
        return menu
    }

    /// 区切りより左にある項目の一覧。ノッチの裏や画面の外にある項目も、ここから開ける
    private func buildHiddenItemsMenu() -> NSMenu {
        let submenu = NSMenu()
        guard MenuBarItems.isTrusted else {
            let info = NSMenuItem(title: "一覧にはアクセシビリティの許可が必要です", action: nil, keyEquivalent: "")
            info.isEnabled = false
            submenu.addItem(info)
            submenu.addItem(item("許可する…", #selector(requestAccessibility)))
            return submenu
        }

        guard let separatorMinX else { return submenu }
        let hidden = MenuBarItems.all().filter {
            Layout.isHidden(itemFrame: $0.frame, boundaryMinX: separatorMinX)
        }
        if hidden.isEmpty {
            let empty = NSMenuItem(title: "隠れている項目はありません", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
            return submenu
        }
        for hiddenItem in hidden {
            let entry = item(hiddenItem.displayName, #selector(openHiddenItem(_:)))
            entry.representedObject = HiddenItemBox(hiddenItem)
            if let icon = hiddenItem.icon?.copy() as? NSImage {
                icon.size = NSSize(width: 16, height: 16)
                entry.image = icon
            }
            submenu.addItem(entry)
        }
        return submenu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        return menuItem
    }

    @objc private func toggleFromMenu() { toggle() }

    @objc private func openHiddenItem(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? HiddenItemBox else { return }
        // 展開して画面に出してから押す。ノッチの裏や画面の外に残っても、AXPress で開ける
        let wasCollapsed = isCollapsed
        expand()
        DispatchQueue.main.asyncAfter(deadline: .now() + (wasCollapsed ? 0.3 : 0)) {
            if !MenuBarItems.press(box.item) {
                NSSound.beep()
            }
        }
    }

    @objc private func toggleAutoCollapse() {
        settings.autoCollapse.toggle()
        if settings.autoCollapse, !isCollapsed {
            scheduleAutoCollapse()
        } else {
            cancelAutoCollapse()
        }
    }

    @objc private func toggleHotKey() {
        settings.hotKeyEnabled.toggle()
        applyHotKeySetting()
    }

    private func applyHotKeySetting() {
        lastHotKeyError = nil
        guard settings.hotKeyEnabled else {
            hotKey?.unregister()
            hotKey = nil
            return
        }
        let hotKey = HotKey { [weak self] in self?.toggle() }
        if hotKey.register() {
            self.hotKey = hotKey
        } else {
            lastHotKeyError = "\(HotKey.defaultDisplay) はほかのアプリが使っています"
        }
    }

    @objc private func toggleLoginItem() {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            showAlert(title: "ログイン項目を変更できませんでした", message: error.localizedDescription)
        }
    }

    @objc private func requestAccessibility() {
        MenuBarItems.requestPermission()
        MenuBarItems.openAccessibilitySettings()
    }

    @objc func showHelp() {
        showAlert(title: "Menu Bar Cleaner の使い方", message: Self.helpText)
    }

    @objc private func quit() {
        // 終了すると区切りも消えるため、隠していた項目は自動で画面に戻る
        NSApp.terminate(nil)
    }

    static let helpText = """
    1. ⌘キーを押したまま、隠したいアイコンを区切り「|」より左へドラッグします。
    2. 「‹」をクリックするか \(HotKey.defaultDisplay) を押すと、隠したアイコンを表示します。もう一度で隠します。
    3. 右クリックでメニューを開きます。ノッチの裏に入って見えない項目は「隠れている項目」から開けます（アクセシビリティの許可が必要）。

    区切りはトグル「‹」より左に置いてください。右にあると隠せません。
    """

    private func showOrderWarning() {
        showAlert(
            title: "区切りの位置を直してください",
            message: "区切り「|」がトグル「‹」の右にあるため、隠すとトグルも見えなくなります。⌘キーを押したまま、区切りをトグルの左へドラッグしてください。"
        )
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

/// NSMenuItem.representedObject に構造体を入れるための箱
private final class HiddenItemBox {
    let item: MenuBarItem
    init(_ item: MenuBarItem) { self.item = item }
}
