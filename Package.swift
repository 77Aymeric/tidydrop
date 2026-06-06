// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TidyDrop",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "TidyDrop", targets: ["TidyDrop"])
    ],
    targets: [
        .executableTarget(
            name: "TidyDrop",
            path: "Sources/TidyDrop"
        )
    ]
)
