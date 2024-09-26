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
            let package = try await locate(packageName: package)
            
            let downloadLocation = try await download(package: package)
            
            try validate(package: package, at: downloadLocation)
            
            let unpackedLocation = try unpack(package: package, at: downloadLocation)
            
            _ = try execute(package: package, at: unpackedLocation)
            
            _ = try await install(package: package, from: unpackedLocation)
        }
        
        func locate(packageName: String) async throws -> Package.Module {
            log(infoMsg: "Locating...")
            guard let manifestURL = URL(string: "https://raw.githubusercontent.com/willswire/cosmic-pkgs/refs/tags/v0.0.2/\(packageName).pkl")
            else {
                throw AddError.manifestNotFound(
                    "Could not find a valid package manifest for \(packageName)")
            }

            let package = try await Package.loadFrom(source: .url(manifestURL))
            log(
                debugMsg: "Located package \(package.name) with version: \(package.version)"
            )
            return package
        }
        
        func download(package: Package.Module) async throws -> URL {
            log(
                infoMsg: "Downloading...",
                debugMsg: "Remote package URL: \(package.url)"
            )
            guard let packageURL = URL(string: package.url) else {
                throw AddError.downloadFailed("Could not download package from \(package.url)")
            }
            let (location, _) = try await sharedSession.download(from: packageURL)
            log(
                debugMsg: "Downloaded \(package.name) temporarily to: \(location.path)"
            )
            return location
        }
        
        func validate(package: Package.Module, at url: URL) throws {
            let data = try Data(contentsOf: url)
            let calculatedHash = SHA256.hash(data: data).hexStr
            log(
                infoMsg: "Validating...",
                debugMsg: "Calculated hash: \(calculatedHash)"
            )
            log(debugMsg: "Expected hash: \(package.hash)")
            guard package.hash.caseInsensitiveCompare(calculatedHash) == .orderedSame else {
                throw AddError.downloadFailed("Hash mismatch")
            }
            log(
                debugMsg: "Hashes match! Validated \(package.name)"
            )
        }
        
        func unpack(package: Package.Module, at url: URL) throws -> URL {
            log(
                infoMsg: "Unpacking...",
                debugMsg: "Package type: \(package.type.rawValue)"
            )
            
            let resultURL: URL
            switch package.type {
            case .binary:
                resultURL = url
            case .zip:
                resultURL = try unzip(from: url.path(), for: package.name)
            case .archive:
                resultURL = try unarchive(from: url.path(), for: package.name, strip: package.isBundle)
            }
            
            log(
                debugMsg: "Unpacked \(package.name) to: \(resultURL.path)"
            )
            return resultURL
        }
        
        func execute(package: Package.Module, at url: URL) throws -> Int {
            log(
                debugMsg: "Executable paths: \(package.executablePaths.joined(separator: "\n"))"
            )
            
            var terminationStatusProduct: Int = 0
            
            for executablePath in package.executablePaths {
                log(debugMsg: "Executable path: \(executablePath)")
                
                let fileURL = url.appendingPathComponent(executablePath)
                
                log(debugMsg: "Setting executable permissions for file: \(fileURL.path)...")
                try setExecutablePermission(for: fileURL)
                
                let process = Process()
                
                if package.type != .binary {
                    log(debugMsg: "Setting current directory to \(url.path)")
                    process.currentDirectoryURL = url
                }
                
                process.executableURL = fileURL
                process.arguments = package.testArgs
                process.standardOutput = nil
                process.standardError = nil
                
                log(debugMsg: "Running process for file: \(fileURL.path)...")
                try process.run()
                process.waitUntilExit()
                
                log(debugMsg: "Process exited with status: \(process.terminationStatus)")
                terminationStatusProduct *= Int(process.terminationStatus)
            }
            
            guard terminationStatusProduct == 0 else {
                throw AddError.executeProcessFailed(
                    "No succesful executables were found")
            }
            
            log(debugMsg: "All executables were successfully installed")
            return terminationStatusProduct
        }
        
        func install(package: Package.Module, from url: URL) async throws -> Bool {
            log(infoMsg: "Installing...")
            
            let fm = FileManager.default
            let homePackagesPath = fm.homeDirectoryForCurrentUser.appendingPathComponent("Packages")
            if !fm.fileExists(atPath: homePackagesPath.path) {
                try fm.createDirectory(at: homePackagesPath, withIntermediateDirectories: true)
            }
            
            if package.isBundle {
                log(debugMsg: "Installing bundle...")
                let destination = homePackagesPath.appendingPathComponent("_" + package.name)
                
                try fm.moveItem(at: url, to: destination)
                
                for path in package.executablePaths {
                    guard let executable = path.split(separator: "/").last else {
                        throw AddError.missingExecutablePath(destination.path())
                    }
                    log(debugMsg: "Creating symlink for \(executable)")
                    try fm.createSymbolicLink(at: homePackagesPath.appendingPathComponent(String(executable)), withDestinationURL: destination.appending(path: path))
                }
                
            } else {
                let destination = homePackagesPath.appendingPathComponent(package.name)
                
                guard let primaryExecutablePath = package.executablePaths.first else {
                    throw AddError.missingExecutablePath(destination.path())
                }
                log(debugMsg: "Identified primary executable path: \(primaryExecutablePath)")
                
                log(debugMsg: "Moving \(primaryExecutablePath) to \(destination.path())...")
                try fm.moveItem(at: url.appendingPathComponent(primaryExecutablePath), to: destination)
            }
            
            let finalResult = package.executablePaths.reduce(true) { partialResult, next in
                let executable = String(next.split(separator: "/").last ?? "")
                return partialResult && fm.isExecutableFile(atPath: homePackagesPath.appendingPathComponent(executable).path)
            }
            log(infoMsg: finalResult ? "Done!" : "Error!")
            return finalResult
        }
        
        func log(errorMsg: String = "", warningMsg: String = "", infoMsg: String = "", debugMsg: String = "") {
            switch options.logLevel {
            case .debug:
                debugMsg.isEmpty ? () : print(debugMsg)
                fallthrough
            case .info:
                infoMsg.isEmpty ? () : print(infoMsg)
                fallthrough
            case .warning:
                warningMsg.isEmpty ? () : print(warningMsg)
                fallthrough
            case .error:
                errorMsg.isEmpty ? () : print(errorMsg)
            }
        }
    }
}
