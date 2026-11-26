// swift-tools-version:5.9
import PackageDescription

var targets: [Target] = [
    // Reine Logik (nur Foundation) – läuft auch auf Linux und ist voll getestet.
    .target(name: "VorratCore"),
    .testTarget(name: "VorratCoreTests", dependencies: ["VorratCore"]),
]

var products: [Product] = [
    .library(name: "VorratCore", targets: ["VorratCore"]),
]

#if os(macOS)
// Die eigentliche SwiftUI/SwiftData-App gibt es nur auf macOS.
targets.append(.executableTarget(name: "Vorrat", dependencies: ["VorratCore"]))
products.append(.executable(name: "Vorrat", targets: ["Vorrat"]))
#endif

let package = Package(
    name: "Vorrat",
    defaultLocalization: "de",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
