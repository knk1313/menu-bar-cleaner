import Carbon.HIToolbox

/// グローバルショートカット。
///
/// Carbon の RegisterEventHotKey を使う。古い API だが、現行の macOS でも公開 API として動き、
/// アクセシビリティや入力監視の権限を求めない（NSEvent のグローバル監視は入力監視の権限が要る）。
final class HotKey {
    /// 既定のショートカット：⌃⌥⌘B
    static let defaultKeyCode = UInt32(kVK_ANSI_B)
    static let defaultModifiers = UInt32(controlKey | optionKey | cmdKey)
    static let defaultDisplay = "⌃⌥⌘B"

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let keyCode: UInt32
    private let modifiers: UInt32
    private let action: () -> Void

    init(keyCode: UInt32 = HotKey.defaultKeyCode,
         modifiers: UInt32 = HotKey.defaultModifiers,
         action: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.action = action
    }

    deinit { unregister() }

    /// 登録できたら true。ほかのアプリが同じ組み合わせを先に取っていると失敗する。
    @discardableResult
    func register() -> Bool {
        guard hotKeyRef == nil else { return true }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            hotKey.action()
            return noErr
        }, 1, &spec, userData, &handlerRef)
        guard installStatus == noErr else { return false }

        let id = EventHotKeyID(signature: OSType(0x4D42_4331), id: 1) // "MBC1"
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            unregister()
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }
}
