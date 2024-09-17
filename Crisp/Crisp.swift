//
//  Crisp.swift
//  Crisp
//
//  Created by Will Walker on 9/16/24.
//

import Foundation
import ArgumentParser
import PklSwift
import CryptoKit

@main struct Crisp: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
            abstract: "A package manager for macOS.",
            subcommands: [Add.self])
}

extension Crisp {
    struct Add: AsyncParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Add a package.")
        @Argument(help: "The name of the package to add.") var package: String
        
        struct Error: LocalizedError {}
        
        mutating func run() async throws {
            let package = try await fetch(packageName: package)
            print("package fetched as \(package.name)")
            let location = try await download(package: package)
            print("package downloaded to \(location.path)")
            let isValid = try validate(package: package, at: location)
            print("package is valid: \(isValid)")
        }
        
        func fetch(packageName: String) async throws -> Package.Module {
            let k9sPath = "/Users/willwalker/Downloads/Crisp/Packages/k9s.pkl"
            let k9sPackage = try await Package.loadFrom(source: .path(k9sPath))
            return k9sPackage
        }
        
        func download(package: Package.Module) async throws -> URL {
            if let packageURL = URL(string: package.url) {
                let (location, _) = try await URLSession.shared.download(from: packageURL)
                return location
            } else {
                throw Add.Error()
            }
        }
        
        func validate(package: Package.Module, at url: URL) throws -> Bool {
            // calculate the SHA256 hash of the file at the URL
            let data = try Data(contentsOf: url)
            let calculatedHash = SHA256.hash(data: data)
            return package.hash.caseInsensitiveCompare(calculatedHash.hexStr) == .orderedSame
        }
    }
}

// CryptoKit.Digest utils
extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }

    var hexStr: String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }
}
