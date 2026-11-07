// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenuBarCleaner",
    platforms: [.macOS(.v13)],
    targets: [
        // OS に依存しない判定（区切りの長さ、並び順、隠れている項目の判定）
        .target(name: "MenuBarCleanerCore"),
        // メニューバーに常駐するアプリ本体（AppKit）
        .executableTarget(
            name: "MenuBarCleaner",
            dependencies: ["MenuBarCleanerCore"]
        ),
        .testTarget(
            name: "MenuBarCleanerCoreTests",
            dependencies: ["MenuBarCleanerCore"]
        ),
    ]
)
