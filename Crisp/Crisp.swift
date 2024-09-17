//
//  Crisp.swift
//  Crisp
//
//  Created by Will Walker on 9/16/24.
//

import ArgumentParser
import CryptoKit
import Foundation
import PklSwift
import AppKit

@main struct Crisp: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A package manager for macOS.",
        subcommands: [Add.self])
    
    struct Options: ParsableArguments {
        @Flag(name: [.long, .customShort("v")]) var verbose = false
    }
}

extension Crisp {
    struct Add: AsyncParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Add a package.")
        @OptionGroup var options: Crisp.Options
        
        @Argument(help: "The name of the package to add.") var package: String
        
        enum AddError: Error {
            case executeProcessFailed(String)
            case downloadFailed(String)
        }
        
        mutating func run() async throws {
            let package = try await fetch(packageName: package)
            if options.verbose {
                print("package fetched as \(package.name)")
            }
            
            let location = try await download(package: package)
            if options.verbose {
                print("package downloaded to \(location.path)")
            }
            
            let isValid = try validate(package: package, at: location)
            if options.verbose {
                print("package is valid: \(isValid)")
            }
            
            let unpackedLocation = try unpack(package: package, at: location)
            if options.verbose {
                print("package unpacked: \(unpackedLocation)")
            }
            
            let exitCode = try execute(package: package, at: unpackedLocation)
            if options.verbose {
                print("\(package.name) terminated with status: \(exitCode)")
            }
                        
            let installResult = try await install(package: package, from: unpackedLocation)
            if options.verbose {
                print("\(package.name) installed: \(installResult)")
            }
        }
        
        func fetch(packageName: String) async throws -> Package.Module {
            let k9sPath = "/Users/willwalker/Developer/crisp/Packages/k9s.pkl"
            let k9sPackage = try await Package.loadFrom(source: .path(k9sPath))
            return k9sPackage
        }
        
        func download(package: Package.Module) async throws -> URL {
            if let packageURL = URL(string: package.url) {
                let (location, _) = try await URLSession.shared.download(from: packageURL)
                return location
            } else {
                throw AddError.downloadFailed("Could not download package from \(package.url)")
            }
        }
        
        func validate(package: Package.Module, at url: URL) throws -> Bool {
            let data = try Data(contentsOf: url)
            let calculatedHash = SHA256.hash(data: data)
            return package.hash.caseInsensitiveCompare(calculatedHash.hexStr) == .orderedSame
        }
        
        func unpack(package: Package.Module, at url: URL) throws -> URL {
            return try extract(from: url.path(), for: package.name)
        }
        
        func execute(package: Package.Module, at url: URL) throws -> Int {
            let process = Process()
            process.executableURL = url.appending(component: package.executablePath)
            process.arguments = package.testArgs
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                print("Extraction completed successfully!")
            } else {
                throw AddError.executeProcessFailed("Unexpected termination status: \(process.terminationStatus)")
            }
            
            return Int(process.terminationStatus)
        }
        
        func install(package: Package.Module, from url: URL) async throws -> Bool {
            
            let fileManager = FileManager.default
            
            let destinationDirectory = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Packages/")
            if !fileManager.fileExists(atPath: destinationDirectory.path()) {
                try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            }
            
            let destination = destinationDirectory.appendingPathComponent(package.name)
            try fileManager.moveItem(at: url.appending(component: package.executablePath), to: destination)
            return fileManager.isExecutableFile(atPath: destination.path())
        }
    }
}
