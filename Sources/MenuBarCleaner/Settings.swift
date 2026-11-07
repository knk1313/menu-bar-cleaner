import Foundation

/// アプリの設定。UserDefaults に保存し、再起動後も復元する。
///
/// どのアイコンを隠すか（区切りの左右どちらに置くか）は、ここではなく macOS が保存する。
/// NSStatusItem.autosaveName を付けた状態アイコンの位置は、macOS がアプリの defaults に書き込む。
final class Settings {
    private let defaults: UserDefaults

    private enum Key {
        static let autoCollapse = "autoCollapse"
        static let hotKeyEnabled = "hotKeyEnabled"
        static let didShowIntroduction = "didShowIntroduction"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.autoCollapse: true,
            Key.hotKeyEnabled: true,
            Key.didShowIntroduction: false,
        ])
    }

    /// 展開してから一定時間がたったら、自動で折りたたむ
    var autoCollapse: Bool {
        get { defaults.bool(forKey: Key.autoCollapse) }
        set { defaults.set(newValue, forKey: Key.autoCollapse) }
    }

    /// グローバルショートカットで展開・折りたたみをする
    var hotKeyEnabled: Bool {
        get { defaults.bool(forKey: Key.hotKeyEnabled) }
        set { defaults.set(newValue, forKey: Key.hotKeyEnabled) }
    }

    /// 初回の使い方の案内を出したか
    var didShowIntroduction: Bool {
        get { defaults.bool(forKey: Key.didShowIntroduction) }
        set { defaults.set(newValue, forKey: Key.didShowIntroduction) }
    }
}
