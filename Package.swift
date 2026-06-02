// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RecyclerView",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "RecyclerView",
            targets: ["RecyclerView"]
        ),
    ],
    dependencies: [
        // Bu paket heç bir xarici kitabxanadan (3rd party dependency) asılı deyil.
    ],
    targets: [
        .target(
            name: "RecyclerView",
            dependencies: [],
            path: "Sources"
        )
    ]
)