//
//  CrispTests.swift
//  CrispTests
//
//  Created by Will Walker on 9/16/24.
//

import Testing
import PklSwift
@testable import Crisp

struct CrispTests {
    @Test("Install a package", arguments: ["k9s"])
    func installPackage(packageName: String) async throws {
        let add = Crisp.Add()
        
        let package = try await add.fetch(packageName: packageName)
        print("feched package: \(package.name)")
        #expect(package.name == packageName)
        
        let location = try await add.download(package: package)
        print("package downloaded to: \(location.path)")
        #expect(location.isFileURL)
        
        let isValid = try add.validate(package: package, at: location)
        print("package is valid: \(isValid)")
        #expect(isValid)
        
        let unpackedLocation = try add.unpack(package: package, at: location)
        print("package unpacked to: \(unpackedLocation.path)")
        #expect(unpackedLocation.isFileURL)
    }
}
