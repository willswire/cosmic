//
//  CosmicTests.swift
//  CosmicTests
//
//  Created by Will Walker on 9/16/24.
//

import PklSwift
import Testing

@testable import Cosmic

struct CosmicTests {
    @Test(
        "Install a package",
        arguments: [
            "k9s",
            "zarf",
            "age",
            "hermes",
        ])
    func installPackage(packageName: String) async throws {
        let addCommand = Cosmic.Add()

        let package = try await Package.loadFrom(
            source: .url(addCommand.packageManifestPath(for: packageName)))
        print("parsed package: \(package.name)")
        #expect(package.name == packageName)

        let downloadLocation = try await addCommand.download(package: package)
        print("package downloaded to: \(downloadLocation.path)")
        #expect(downloadLocation.isFileURL)

        try addCommand.validate(package: package, at: downloadLocation)
        print("package is valid")

        let unpackedLocation = try addCommand.unpack(package: package, at: downloadLocation)
        print("package unpacked to: \(unpackedLocation.path)")
        #expect(unpackedLocation.isFileURL)

        let exitCode = try addCommand.execute(package: package, at: unpackedLocation)
        print("package exited with code: \(exitCode)")
        #expect(exitCode == 0)

        let isInstalled = try await addCommand.install(package: package, from: unpackedLocation)
        print("package installed: \(isInstalled)")
        #expect(isInstalled)
    }
}
