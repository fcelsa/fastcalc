// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "fastcalc",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "FastCalcCore", targets: ["FastCalcCore"]),
        .library(name: "FastCalcUI", targets: ["FastCalcUI"]),
        .executable(name: "fastcalc", targets: ["fastcalc"])
    ],
    dependencies: [
        // Necessario con CLT: il modulo Testing non è importabile senza questo pacchetto
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        .target(
            name: "FastCalcCore"
        ),
        .target(
            name: "FastCalcUI",
            dependencies: ["FastCalcCore"]
        ),
        .executableTarget(
            name: "fastcalc",
            dependencies: ["FastCalcUI"]
        ),
        .testTarget(
            name: "FastCalcCoreTests",
            dependencies: [
                "FastCalcCore",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
