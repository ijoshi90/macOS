// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PackagesInstaller",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PackagesInstaller",
            path: "Sources/PackagesInstaller",
            exclude: ["Resources/Info.plist"],
            resources: [
                .copy("Resources/packages.json"),
                .copy("Resources/install_core.sh"),
                .process("Resources/AppIcon.png"),
            ]
        )
    ]
)
