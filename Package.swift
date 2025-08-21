// swift-tools-version:5.9
//
//  Package.swift
//  LatencyKit
//
//  Created by 김수환 on 8/27/25.
//

import PackageDescription

let package = Package(
    name: "LatencyKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "LatencyKit", targets: ["LatencyKit"]),
    ],
    targets: [
        .target(name: "LatencyKit", path: "Sources", resources: []),
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
