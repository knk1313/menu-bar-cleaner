import Foundation
import ServiceManagement

/// ログイン時の自動起動。SMAppService（macOS 13 以降）で、アプリ本体をログイン項目に登録する。
enum LoginItem {
    /// .app として起動しているときだけ登録できる（`swift run` で直接起動したときは使えない）
    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 承認待ち（システム設定で許可が必要）か
    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
