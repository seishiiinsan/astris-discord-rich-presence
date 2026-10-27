// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AstrisRPC",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "AstrisRPC", path: "Sources/AstrisRPC")
    ]
)
