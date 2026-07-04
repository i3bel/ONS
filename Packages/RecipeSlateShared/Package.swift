// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RecipeSlateShared",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "RecipeSlateShared",
            targets: ["RecipeSlateShared"]
        ),
    ],
    targets: [
        .target(name: "RecipeSlateShared"),
    ]
)
