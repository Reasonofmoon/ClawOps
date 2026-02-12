// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OpenClawControlApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OpenClawControlApp", targets: ["OpenClawControlApp"])
    ],
    targets: [
        .executableTarget(
            name: "OpenClawControlApp",
            path: "Sources/OpenClawControlApp"
        )
    ]
)
