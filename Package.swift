// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QMobileDataSync",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(name: "QMobileDataSync", targets: ["QMobileDataSync"]),
    ],
    dependencies: [
        .package(url: "http://srv-git:3000/qmobile/QMobileAPI.git", .revision("HEAD")),
        .package(url: "http://srv-git:3000/qmobile/QMobileDataStore.git", .revision("HEAD")),

        .package(url: "https://github.com/Thomvis/BrightFutures.git", from: "8.0.1"),
        .package(url: "https://github.com/nvzqz/FileKit.git", from: "6.0.0"),
        .package(url: "https://github.com/DaveWoodCom/XCGLogger.git", from: "7.0.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", .revision("HEAD")),
        .package(url: "https://github.com/Moya/Moya.git", .revision("HEAD")),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),
        .package(url: "https://github.com/phimage/Prephirences.git", .revision("HEAD")),
        .package(url: "https://github.com/devicekit/DeviceKit.git", from: "2.1.0")
    ],
    targets: [
        .target(
            name: "QMobileDataSync",
            dependencies: [
                "QMobileAPI",
                "QMobileDataStore",
                "BrightFutures",
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
