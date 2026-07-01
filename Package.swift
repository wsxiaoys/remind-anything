// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RemindAnything",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RemindAnything", targets: ["RemindAnything"])
    ],
    targets: [
        .executableTarget(
            name: "RemindAnything",
            path: "Sources/RemindAnything",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
