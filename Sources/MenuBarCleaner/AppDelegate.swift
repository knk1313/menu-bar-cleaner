import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = StatusBarController(settings: settings)
        statusBar = controller

        if settings.didShowIntroduction {
            controller.collapseAfterLaunch()
        } else {
            settings.didShowIntroduction = true
            DispatchQueue.main.async { controller.showHelp() }
        }
    }
}
