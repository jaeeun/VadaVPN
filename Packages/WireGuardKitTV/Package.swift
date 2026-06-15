// swift-tools-version:5.9
// WireGuardKit for tvOS.
//
// The Swift/C sources are vendored from the official wireguard-apple repository
// (https://git.zx2c4.com/wireguard-apple, master @ 1.0.16-27). Upstream does not
// support tvOS, so instead of the WireGuardKitGo target (which requires a Go
// toolchain and an External Build System target in Xcode), this package links
// the prebuilt libwg-go.a from partout-io/wg-go-apple, which ships tvOS slices.
//
// Local changes vs upstream:
//  - WireGuardAdapter.swift: `import WireGuardKitGo` -> `import wg_go`
//  - TunnelConfiguration+WgQuickConfig.swift (from Sources/Shared/Model) is
//    included in the WireGuardKit target with its API made public.

import PackageDescription

let package = Package(
    name: "WireGuardKitTV",
    platforms: [
        .tvOS(.v17),
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "WireGuardKit", targets: ["WireGuardKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/partout-io/wg-go-apple", exact: "0.0.20260530")
    ],
    targets: [
        .target(
            name: "WireGuardKit",
            dependencies: [
                "WireGuardKitC",
                .product(name: "wg-go-apple", package: "wg-go-apple")
            ]
        ),
        .target(
            name: "WireGuardKitC",
            publicHeadersPath: "."
        )
    ]
)
