// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FocusNote",
    platforms: [.macOS(.v26)],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "FocusNoteKit"),
        .executableTarget(
            name: "FocusNote",
            dependencies: ["FocusNoteKit"],
            // App code runs on the main thread unless you say otherwise.
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "FocusNoteKitTests", dependencies: ["FocusNoteKit"]),
    ]
)
