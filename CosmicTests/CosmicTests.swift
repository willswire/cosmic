//
//  CosmicTests.swift
//  CosmicTests
//
//  Created by Will Walker on 9/16/24.
//

import ArgumentParser
import Foundation
import PklSwift
import Testing

@testable import cosmic

struct CosmicAddTests {
    
    var cmd: Cosmic.Add
    
    init() {
        cmd = Cosmic.Add()
        guard let options = try? Cosmic.Options.parse(["--verbose"]) else {
            fatalError("Unable to parse arguments for the add command!")
        }
        cmd.options = options
    }
    
    @Test("Add integration test", arguments: [
        "k9s",
        "go"
    ])
    func testRun(_ packageName: String) async {
        var localCmd = Cosmic.Add()
        localCmd.options = self.cmd.options
        localCmd.packageName = packageName
        
        await #expect(throws: Never.self) {
            localCmd.packageName = packageName
            try await localCmd.run()
        }
    }
    
    @Test("Locate a package")
    func testLocate() async {
        
        await #expect(throws: Never.self) {
            let k9sPackage = try await cmd.locate(packageName: "k9s")
            #expect(k9sPackage.name == "k9s")
        }
        
        await #expect(throws: Cosmic.Add.AddError.packageNotFound) {
            try await cmd.locate(packageName: "not-a-package")
        }
    }
    
    @Test("Download a package")
    func testDownload() async {
        let k9sPackage = Package.Module(
            name: "k9s",
            url: "https://github.com/derailed/k9s/releases/download/v0.26.0/k9s_Darwin_arm64.tar.gz",
            purl: "pkg:golang/github.com/derailed/k9s@0.26.0",
            version: "0.26.0",
            hash: "43df569e527141dbfc53d859d7675b71c2cfc597ffa389a20f91297c6701f255",
            executablePaths: ["/k9s"],
            testArgs: ["version", "--short"],
            type: .archive,
            isBundle: false
        )
        
        await #expect(throws: Never.self) {
            let downloadedPackage = try await cmd.download(package: k9sPackage)
            #expect(FileManager.default.fileExists(atPath: downloadedPackage.path))
        }
        
        let brokenPackage = Package.Module(
            name: "k9s",
            url: "https://github.com/derailed/k9s/releases/download/v0.26.0/k9s_Darwin_arm64.rar",
            purl: "pkg:golang/github.com/derailed/k9s@0.26.0",
            version: "0.26.0",
            hash: "43df569e527141dbfc53d859d7675b71c2cfc597ffa389a20f91297c6701f255",
            executablePaths: ["/k9s"],
            testArgs: ["version", "--short"],
            type: .archive,
            isBundle: false
        )
        
        await #expect(throws: Cosmic.Add.AddError.downloadFailed) {
            _ = try await cmd.download(package: brokenPackage)
        }
    }
    
    @Test("Validate a package")
    func testValidate() async {
        let k9sPackage = Package.Module(
            name: "k9s",
            url: "https://github.com/derailed/k9s/releases/download/v0.26.0/k9s_Darwin_arm64.tar.gz",
            purl: "pkg:golang/github.com/derailed/k9s@0.26.0",
            version: "0.26.0",
            hash: "43df569e527141dbfc53d859d7675b71c2cfc597ffa389a20f91297c6701f255",
            executablePaths: ["/k9s"],
            testArgs: ["version", "--short"],
            type: .archive,
            isBundle: false
        )
        
        let brokenPackage = Package.Module(
            name: "k9s",
            url: "https://github.com/derailed/k9s/releases/download/v0.26.0/k9s_Darwin_arm64.tar.gz",
            purl: "pkg:golang/github.com/derailed/k9s@0.26.0",
            version: "0.26.0",
            hash: "43df569e57141dbfc53d859d7675b71c2cfc597ffa389a20f91297c6701f255",
            executablePaths: ["/k9s"],
            testArgs: ["version", "--short"],
            type: .archive,
            isBundle: false
        )
        
        guard let url = try? await cmd.download(package: k9sPackage) else {
            return
        }
        
        #expect(throws: Never.self) {
            try cmd.validate(package: k9sPackage, at: url)
        }
        
        #expect(throws: Cosmic.Add.AddError.invalidPackage) {
            try cmd.validate(package: brokenPackage, at: url)
        }
    }
    
    @Test("Unpack a package")
    func testUnpack() async {
        let binaryPkg = Package.Module(
            name: "dasel",
            url: "https://github.com/TomWright/dasel/releases/download/v2.8.1/dasel_darwin_arm64",
            purl: "pkg:golang/github.com/tomwright/dasel@2.8.1",
            version: "2.8.1",
            hash: "cf976164cf5f929abe25b6924285c27db439dbcc58bac923ee0cbc921a463307",
            executablePaths: [""],
            testArgs: ["help"],
            type: .binary,
            isBundle: false
        )
        
        guard let binaryPkgURL = try? await cmd.download(package: binaryPkg) else {
            fatalError("Unable to download binary package")
        }
        
        #expect(throws: Never.self) {
            let unpackedBinaryPkg = try cmd.unpack(package: binaryPkg, at: binaryPkgURL)
            FileManager.default.fileExists(atPath: unpackedBinaryPkg.path())
        }
        
        let archivePkg = Package.Module(
            name: "k9s",
            url: "https://github.com/derailed/k9s/releases/download/v0.26.0/k9s_Darwin_arm64.tar.gz",
            purl: "pkg:golang/github.com/derailed/k9s@0.26.0",
            version: "0.26.0",
            hash: "43df569e527141dbfc53d859d7675b71c2cfc597ffa389a20f91297c6701f255",
            executablePaths: ["/k9s"],
            testArgs: ["version", "--short"],
            type: .archive,
            isBundle: false
        )
        
        guard let archivePkgURL = try? await cmd.download(package: archivePkg) else {
            fatalError("Unable to download archive package")
        }
        
        #expect(throws: Never.self) {
            let unpackedArchivePkg = try cmd.unpack(package: archivePkg, at: archivePkgURL)
            FileManager.default.fileExists(atPath: unpackedArchivePkg.path())
        }
        
        let zipPkg = Package.Module(
            name: "k9s",
            url: "https://github.com/derailed/k9s/releases/download/v0.26.0/k9s_Darwin_arm64.tar.gz",
            purl: "pkg:golang/github.com/derailed/k9s@0.26.0",
            version: "0.26.0",
            hash: "43df569e527141dbfc53d859d7675b71c2cfc597ffa389a20f91297c6701f255",
            executablePaths: ["/k9s"],
            testArgs: ["version", "--short"],
            type: .zip,
            isBundle: false
        )

        guard let zipPkgURL = try? await cmd.download(package: zipPkg) else {
            fatalError("Unable to download zip package")
        }

        #expect(throws: Cosmic.Add.AddError.invalidPackage) {
            _ = try cmd.unpack(package: zipPkg, at: zipPkgURL)
        }
    }
}
