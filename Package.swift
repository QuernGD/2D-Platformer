// swift-tools-version:5.9
import PackageDescription

// SpriteKit is an Apple-only framework, so this package only targets
// Apple platforms. Open the folder in Xcode (or drop Sources/Platformer
// into an existing iOS/macOS SpriteKit project) to build and run.
let package = Package(
    name: "Platformer",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13)
    ],
    products: [
        .library(name: "Platformer", targets: ["Platformer"])
    ],
    targets: [
        .target(
            name: "Platformer",
            path: "Sources/Platformer"
        )
    ]
)
