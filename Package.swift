// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CalcBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CalcBar", targets: ["CalcBar"])
    ],
    targets: [
        .executableTarget(
            name: "CalcBar",
            path: "Sources/CalcBar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        )
    ]
)
