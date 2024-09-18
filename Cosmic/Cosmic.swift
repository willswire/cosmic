//
//  Cosmic.swift
//  Cosmic
//
//  Created by Will Walker on 9/16/24.
//

import AppKit
import ArgumentParser
import CryptoKit
import Foundation
import PklSwift

@main struct Cosmic: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A package manager for macOS.",
        subcommands: [Add.self])
    
    struct Options: ParsableArguments {
        @Flag(name: [.long, .customShort("v")]) var verbose = false
    }
}

extension Cosmic {
    struct Add: AsyncParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Add a package.")
        @OptionGroup var options: Cosmic.Options
        @Argument(help: "The name of the package to add.") var package: String
        
        enum AddError: Error {
            case manifestNotFound(String)
            case executeProcessFailed(String)
            case downloadFailed(String)
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
#if DEBUG
            let manifestURL = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Packages/\(packageName).pkl")
#else
            
            guard let manifestURL = URL(string: "https://raw.githubusercontent.com/willswire/Cosmic/refs/heads/main/Packages/\(packageName).pkl") else {
                throw AddError.manifestNotFound("Could not find a valid package manifest for \(packageName)")
            }
#endif
            return manifestURL
        }
        
        func download(package: Package.Module) async throws -> URL {
            guard let packageURL = URL(string: package.url) else {
                throw AddError.downloadFailed("Could not download package from \(package.url)")
            }
            let (location, _) = try await URLSession.shared.download(from: packageURL)
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
                return try unarchive(from: url.path(), for: package.name)
            }
        }
        
        func execute(package: Package.Module, at url: URL) throws -> Int {
            let fileURL = url.appendingPathComponent(package.executablePath)
            
            try setExecutablePermission(for: fileURL)
            
            let process = Process()
            process.executableURL = fileURL
            process.arguments = package.testArgs
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw AddError.executeProcessFailed(
                    "Unexpected termination status: \(process.terminationStatus)")
            }
            
            return Int(process.terminationStatus)
        }
        
        func setExecutablePermission(for fileURL: URL) throws {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let permissions = attributes[.posixPermissions] as? NSNumber {
                let newPermissions = NSNumber(value: permissions.intValue | 0o111)
                try FileManager.default.setAttributes(
                    [.posixPermissions: newPermissions], ofItemAtPath: fileURL.path)
            }
        }
        
        func install(package: Package.Module, from url: URL) async throws -> Bool {
            let fm = FileManager.default
            let homePackagesPath = fm.homeDirectoryForCurrentUser.appendingPathComponent("Packages")
            if !fm.fileExists(atPath: homePackagesPath.path) {
                try fm.createDirectory(at: homePackagesPath, withIntermediateDirectories: true)
            }
            
            let destination = homePackagesPath.appendingPathComponent(package.name)
            try fm.moveItem(at: url.appendingPathComponent(package.executablePath), to: destination)
            
            return fm.isExecutableFile(atPath: destination.path)
        }
        
        func log(_ message: String) {
            if options.verbose {
                print(message)
            }
        }
    }
}
