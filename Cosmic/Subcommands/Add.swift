//
//  Add.swift
//  Cosmic
//
//  Created by Will Walker on 9/20/24.
//

import AppKit
import ArgumentParser
import CryptoKit
import Foundation
import PklSwift

extension Cosmic {
    struct Add: AsyncParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Add a package.")
        @OptionGroup var options: Cosmic.Options
        @Argument(help: "The name of the package to add.") var package: String

        enum AddError: Error {
            case manifestNotFound(String)
            case executeProcessFailed(String)
            case downloadFailed(String)
            case missingExecutablePath(String)
        }

        mutating func run() async throws {
            let package = try await Package.loadFrom(
                source: .url(packageManifestPath(for: package)))
            log("package fetched as \(package.name)")

            let downloadLocation = try await download(package: package)
            log("package downloaded to \(downloadLocation.path)")

            try validate(package: package, at: downloadLocation)
            log("package is valid: \(true)")

            let unpackedLocation = try unpack(package: package, at: downloadLocation)
            log("package unpacked: \(unpackedLocation.path)")

            let exitCode = try execute(package: package, at: unpackedLocation)
            log("\(package.name) terminated with status: \(exitCode)")

            let installResult = try await install(package: package, from: unpackedLocation)
            log("\(package.name) installed: \(installResult)")
        }

        func packageManifestPath(for packageName: String) throws -> URL {
            guard
                let manifestURL = URL(
                    string:
                        "https://raw.githubusercontent.com/willswire/cosmic-pkgs/refs/tags/v0.0.2/\(packageName).pkl"
                )
            else {
                throw AddError.manifestNotFound(
                    "Could not find a valid package manifest for \(packageName)")
            }
            return manifestURL
        }

        func download(package: Package.Module) async throws -> URL {
            guard let packageURL = URL(string: package.url) else {
                throw AddError.downloadFailed("Could not download package from \(package.url)")
            }
            let (location, _) = try await sharedSession.download(from: packageURL)
            return location
        }

        func validate(package: Package.Module, at url: URL) throws {
            let data = try Data(contentsOf: url)
            let calculatedHash = SHA256.hash(data: data).hexStr
            guard package.hash.caseInsensitiveCompare(calculatedHash) == .orderedSame else {
                throw AddError.downloadFailed("Hash mismatch")
            }
        }

        func unpack(package: Package.Module, at url: URL) throws -> URL {
            switch package.type {
            case .binary:
                return url
            case .zip:
                return try unzip(from: url.path(), for: package.name)
            case .archive:
                return try unarchive(from: url.path(), for: package.name, strip: package.isBundle)
            }
        }

        func execute(package: Package.Module, at url: URL) throws -> Int {
            var terminationStatusProduct: Int = 0
            
            for executablePath in package.executablePaths {
                
                let fileURL = url.appendingPathComponent(executablePath)
                
                try setExecutablePermission(for: fileURL)
                
                let process = Process()
                
                if package.type != .binary {
                    process.currentDirectoryURL = url
                }
                
                process.executableURL = fileURL
                process.arguments = package.testArgs
                process.standardOutput = nil
                process.standardError = nil
                
                try process.run()
                process.waitUntilExit()
                
                terminationStatusProduct *= Int(process.terminationStatus)
            }

            guard terminationStatusProduct == 0 else {
                throw AddError.executeProcessFailed(
                    "No succesful executables were found")
            }
            
            return terminationStatusProduct
        }

        func install(package: Package.Module, from url: URL) async throws -> Bool {
            let fm = FileManager.default
            let homePackagesPath = fm.homeDirectoryForCurrentUser.appendingPathComponent("Packages")
            if !fm.fileExists(atPath: homePackagesPath.path) {
                try fm.createDirectory(at: homePackagesPath, withIntermediateDirectories: true)
            }
                        
            if package.isBundle {
                let destination = homePackagesPath.appendingPathComponent("_" + package.name)
                
                try fm.moveItem(at: url, to: destination)
                
                for path in package.executablePaths {
                    guard let executable = path.split(separator: "/").last else {
                        throw AddError.missingExecutablePath(destination.path())
                    }
                    try fm.createSymbolicLink(at: homePackagesPath.appendingPathComponent(String(executable)), withDestinationURL: destination.appending(path: path))
                }
                
            } else {
                let destination = homePackagesPath.appendingPathComponent(package.name)
                
                guard let primaryExecutablePath = package.executablePaths.first else {
                    throw AddError.missingExecutablePath(destination.path())
                }
                
                try fm.moveItem(at: url.appendingPathComponent(primaryExecutablePath), to: destination)
            }
            
            return package.executablePaths.reduce(true) { partialResult, next in
                let executable = String(next.split(separator: "/").last ?? "")
                return partialResult && fm.isExecutableFile(atPath: homePackagesPath.appendingPathComponent(executable).path)
            }
        }

        func log(_ message: String) {
            if options.verbose {
                print(message)
            }
        }
    }
}
