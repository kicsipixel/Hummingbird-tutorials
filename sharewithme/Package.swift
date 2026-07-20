// swift-tools-version:6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sharewithme",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18)],
    products: [
        .executable(name: "sharewithme", targets: ["sharewithme"])
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.25.0"),
        .package(
            url: "https://github.com/apple/swift-configuration.git",
            from: "1.0.0",
            traits: [.defaults, "CommandLineArguments"]
        ),
        // OCIKit
        .package(url: "https://github.com/iliasaz/oci-swift-sdk.git", branch: "main"),
        // Mustache
        .package(url: "https://github.com/hummingbird-project/swift-mustache.git", from: "2.0.0"),
        // Multipart form decoding
        .package(url: "https://github.com/vapor/multipart-kit.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-http-structured-headers.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "sharewithme",
            dependencies: [
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "Hummingbird", package: "hummingbird"),
                // OCIKit
                .product(name: "OCIKit", package: "oci-swift-sdk"),
                // Mustache
                .product(name: "Mustache", package: "swift-mustache"),
                // Multipart form decoding
                .product(name: "MultipartKit", package: "multipart-kit"),
                .product(name: "StructuredFieldValues", package: "swift-http-structured-headers"),
            ],
            path: "Sources/App",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "sharewithmeTests",
            dependencies: [
                .byName(name: "sharewithme"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ],
            path: "Tests/AppTests"
        ),
    ]
)
