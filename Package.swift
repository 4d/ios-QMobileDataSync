// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QMobileDataSync",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v14)
    ],
    products: [
        .library(name: "QMobileDataSync", targets: ["QMobileDataSync"]),
    ],
    dependencies: [
        .package(url: "https://gitlab-4d.private.4d.fr/4d/qmobile/ios/QMobileAPI.git", .revision("HEAD")),
        .package(url: "https://gitlab-4d.private.4d.fr/4d/qmobile/ios/QMobileDataStore.git", .revision("HEAD")),

        .package(url: "https://github.com/nvzqz/FileKit.git", from: "6.1.0"),

        .package(url: "https://github.com/DaveWoodCom/XCGLogger.git", from: "7.0.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.1"),
        .package(url: "https://github.com/phimage/Prephirences.git", from: "5.4.0"),

        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.6.4"),
        .package(url: "https://github.com/Moya/Moya.git",  from:"15.0.3"),
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
                "Prephirences"
            ],
            path: "Sources"),
        .testTarget(
            name: "QMobileDataSyncTests",
            dependencies: ["QMobileDataSync"],
            path: "Tests")
    ]
)
