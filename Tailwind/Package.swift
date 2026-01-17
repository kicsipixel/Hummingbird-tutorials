// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tailwind",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18)],
    products: [
        .executable(name: "App", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0", traits: [.defaults, "CommandLineArguments"]),
        // Mustache
        .package(url: "https://github.com/hummingbird-project/swift-mustache.git", from: "2.0.2"),
        // Styling
        .package(url: "https://github.com/kicsipixel/SwiftKaze.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "CSSSetup",
            dependencies: [
                .product(name: "SwiftKaze", package: "SwiftKaze")
            ],
            path: "Sources/CSSSetup"
        ),
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "Hummingbird", package: "hummingbird"),
                // Mustache
                .product(name: "Mustache", package: "swift-mustache"),
                // Styling
                .product(name: "SwiftKaze", package: "SwiftKaze"),
                "CSSSetup",
            ],
            path: "Sources/App",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "PrepareCSS",
            dependencies: [
                "CSSSetup"
            ],
            path: "Sources/PrepareCSS"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .byName(name: "App"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ],
            path: "Tests/AppTests"
        ),
    ]
)
