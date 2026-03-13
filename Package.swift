// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TeamAIManager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TeamAIManager", targets: ["TeamAIManager"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0")
    ],
    targets: [
        .executableTarget(
            name: "TeamAIManager",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources"
        )
    ]
)
