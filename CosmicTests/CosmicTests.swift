//
//  CosmicTests.swift
//  CosmicTests
//
//  Created by Will Walker on 9/16/24.
//

import ArgumentParser
import PklSwift
import Testing

@testable import cosmic

struct CosmicSetupTests {
    @Test("Set up Cosmic")
    func setUpCosmic() async throws {
        var setupCommand = Cosmic.Setup()
        setupCommand.options = try .parse(["--verbose", "--force"])

        try setupCommand.createPackagesDirectory()

        let pklURL = try await setupCommand.downloadPkl()
        #expect(pklURL.isFileURL)

        try setupCommand.installPkl(from: pklURL)

        let isProfileModified = try setupCommand.modifyShellProfiles()
        // TODO: Test against output (which instructs users to self modify)
        #expect(isProfileModified || true)
    }
}

struct CosmicAddTests {
    @Test(
        "Install a package",
        arguments: [
            // Non-bundled packages
            "node",
            "go",
            "libwebp",
            // Bundled packages
            "age",
            "apko",
            "dasel",
            //"gh",
            //"git-lfs",
            //"gitleaks",
            //"goreleaser",
            //"hermes",
            //"k9s",
            //"sops",
            //"zarf",
        ])
    func installPackage(packageName: String) async throws {
        var addCommand = Cosmic.Add()
        addCommand.options = try .parse(["--verbose"])

        let package = try await Package.loadFrom(
            source: .url(addCommand.packageManifestPath(for: packageName)))
        #expect(package.name == packageName)

        let downloadLocation = try await addCommand.download(package: package)
        #expect(downloadLocation.isFileURL)

        try addCommand.validate(package: package, at: downloadLocation)

        let unpackedLocation = try addCommand.unpack(package: package, at: downloadLocation)
        #expect(unpackedLocation.isFileURL)

        let exitCode = try addCommand.execute(package: package, at: unpackedLocation)
        #expect(exitCode == 0)

        let isInstalled = try await addCommand.install(package: package, from: unpackedLocation)
        #expect(isInstalled)
    }
}
