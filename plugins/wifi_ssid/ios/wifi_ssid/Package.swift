// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "wifi_ssid",
    platforms: [
        .iOS("14.0")
    ],
    products: [
        .library(name: "wifi-ssid", targets: ["wifi_ssid"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "wifi_ssid",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            path: "Sources/wifi_ssid",
            linkerSettings: [
                .linkedFramework("CoreLocation"),
                .linkedFramework("NetworkExtension")
            ]
        )
    ]
)
