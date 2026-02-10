// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MoveNow",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "MoveNow", targets: ["MoveNow"]),
    ],
    targets: [
        .executableTarget(
            name: "MoveNow",
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
