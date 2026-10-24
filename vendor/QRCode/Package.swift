// swift-tools-version: 5.5

import PackageDescription

let package = Package(
	name: "QRCode",
	platforms: [
		.macOS(.v10_13),
		.iOS(.v11),
		.tvOS(.v13),
		.watchOS("9.0")
	],
	products: [
		.library(name: "QRCode", targets: ["QRCode"]),
	],
	dependencies: [
	],
	targets: [
		// The QRCode core library (vendored from dagronf/QRCode 20.5.0, MIT)
		.target(
			name: "QRCode",
			dependencies: [
				"SwiftImageReadWrite",
				"QRCodeGenerator",
			],
			resources: [
				.copy("PrivacyInfo.xcprivacy"),
			]
		),
		// Vendored from dagronf/swift-qrcode-generator 2.0.2, MIT
		// (Nayuki's reference QR code generator; see LICENSE-QRCodeGenerator)
		.target(
			name: "QRCodeGenerator",
			dependencies: []
		),
		// Vendored from dagronf/SwiftImageReadWrite 1.9.2, MIT
		// (see LICENSE-SwiftImageReadWrite)
		.target(
			name: "SwiftImageReadWrite",
			resources: [
				.copy("PrivacyInfo.xcprivacy"),
			]
		),
	]
)
