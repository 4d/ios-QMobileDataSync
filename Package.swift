// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QMobileDataSync",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v14)
    ],
    products: [
        .library(name: "QMobileDataSync", targets: ["QMobileDataSync"]),
    ],
    dependencies: [
        .package(url: "https://gitlab-4d.private.4d.fr/qmobile/QMobileAPI.git", .revision("HEAD")),
        .package(url: "https://gitlab-4d.private.4d.fr/qmobile/QMobileDataStore.git", .revision("HEAD")),

        .package(url: "https://github.com/nvzqz/FileKit.git", from: "6.0.0"),

        .package(url: "https://github.com/DaveWoodCom/XCGLogger.git", from: "7.0.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),
        .package(url: "https://github.com/phimage/Prephirences.git", from: "5.1.0"),

        .package(url: "https://github.com/phimage/DeviceKit.git", .branch("feature/macos")),
        .package(url: "https://github.com/Alamofire/Alamofire.git", .revision("5.0.0")),
        .package(url: "https://github.com/Moya/Moya.git", .revision("14.0.0")),
    ],
    targets: [
        .target(
            name: "QMobileDataSync",
            dependencies: [
                "QMobileAPI",
                "QMobileDataStore",
                "FileKit",
                "XCGLogger",
                "Alamofire",
                "Moya",
                "SwiftyJSON",
                "Prephirences",
                "DeviceKit"
            ],
            path: "Sources"),
        .testTarget(
            name: "QMobileDataSyncTests",
            dependencies: ["QMobileDataSync"],
            path: "Tests")
    ]
)
