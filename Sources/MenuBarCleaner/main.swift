import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Dock にアイコンを出さない、メニューバー常駐のアプリにする
app.setActivationPolicy(.accessory)
app.run()
