// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sift-ios",
    platforms: [
        .iOS(.v8)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.-
        .library(
            name: "sift-ios",
            targets: ["sift-ios"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
//        .target(
//            name: "Sift",
//            dependencies: [],
//            path: "."),
        .target(
            name: "sift-ios",
            dependencies: ["Sift"]),
        .target(
            name: "Sift",
            dependencies: [],
            path: "Sift",
//            sources: ["Core", "Dependencies/OneDependency/OneDependency.m"]
            publicHeadersPath: "."),
        .testTarget(
            name: "sift-iosTests",
            dependencies: ["sift-ios"]),
    ]
)

