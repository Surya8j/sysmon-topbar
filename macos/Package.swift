// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SysMonTopBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SysMonTopBar",
            path: "Sources/SysMonTopBar"
        )
    ]
)
