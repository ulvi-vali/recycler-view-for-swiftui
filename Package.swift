// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RecyclerView",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "RecyclerView", targets: ["RecyclerView"])
    ],
    targets: [
        .target(name: "RecyclerView"),
        .testTarget(name: "RecyclerViewTests", dependencies: ["RecyclerView"])
    ]
)
