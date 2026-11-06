// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "PadelScore", products: [.library(name: "PadelCore", targets: ["PadelCore"])], targets: [.target(name: "PadelCore"), .testTarget(name: "PadelCoreTests", dependencies: ["PadelCore"])])
