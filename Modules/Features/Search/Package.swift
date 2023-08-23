// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "Search",
    platforms: [
        .macOS(.v10_15), .iOS(.v14)
    ],
    products: [
        .library(
            name: "Search",
            targets: ["Search"]
        ),
        .library(
            name: "SearchMock",
            targets: ["SearchMock"]
        )
        
    ],
    dependencies: [
        .package(path: "../../Domain/MEGADomain")
    ],
    targets: [
        .target(
            name: "Search",
            dependencies: [
                "MEGADomain"
            ],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        ),
        .target(
            name: "SearchMock",
            dependencies: ["Search"],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        ),
        .testTarget(
            name: "SearchTests",
            dependencies: ["Search"],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        )
    ]
)
