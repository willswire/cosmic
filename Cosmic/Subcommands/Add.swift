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
        
        @Argument(help: "The name of the package to add.") var packageName: String
        
        enum AddError: Error {
            case packageNotFound
            case executeProcessFailed
            case downloadFailed
            case invalidPackage
            case missingExecutablePath
        }
                
        /// Command's main entry when run is executed, adding the package by process of locating, downloading, validating, unpacking, testing, and installing.
        mutating func run() async throws {
            let package = try await locate(packageName: packageName)
            let downloadLocation = try await download(package: package)
            try validate(package: package, at: downloadLocation)
            let unpackedLocation = try unpack(package: package, at: downloadLocation)
            try execute(package: package, at: unpackedLocation)
            try await install(package: package, from: unpackedLocation)
        }
        
        /// Locates the package manifest and loads the package information.
        /// - Parameter packageName: The name of the package to locate.
        /// - Returns: The located `Package.Module`.
        /// - Throws: `AddError.manifestNotFound` if the manifest URL is incorrect or cannot be found.
        func locate(packageName: String) async throws -> Package.Module {
            log("Locating package...")
            
            let manifestURL = URL(string: "https://raw.githubusercontent.com/willswire/cosmic-pkgs/refs/tags/v0.0.2/\(packageName).pkl")!
            
            // Check if the manifest exists by performing a HEAD request.
            let (_, response) = try await URLSession.shared.data(from: manifestURL)
            
            // Check the response status code to ensure the manifest exists.
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw AddError.packageNotFound
            }
            
            // Load the package from the URL.
            let package = try await Package.loadFrom(source: .url(manifestURL))
            log(debug: "Located package \(package.name) with version: \(package.version)")
            
            return package
        }
        
        
        /// Downloads the package.
        /// - Parameter package: The package module to download.
        /// - Returns: URL where the package is downloaded.
        /// - Throws: `AddError.downloadFailed` if the package cannot be downloaded.
        func download(package: Package.Module) async throws -> URL {
            log("Downloading package...", debug: "Remote URL: \(package.url)")
            
            let packageURL = URL(string: package.url)!
            
            do {
                let (location, response) = try await sharedSession.download(from: packageURL)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    throw AddError.downloadFailed
                }
                log(debug: "Downloaded \(package.name) to: \(location.path)")
                return location
            } catch {
                throw AddError.downloadFailed
            }
        }
        
        /// Validates the downloaded package by checking its hash.
        /// - Parameters:
        ///   - package: The package module to validate.
        ///   - url: URL where the downloaded package is located.
        /// - Throws: `AddError.downloadFailed` if the hash does not match.
        func validate(package: Package.Module, at url: URL) throws {
            let data = try Data(contentsOf: url)
            let calculatedHash = SHA256.hash(data: data).hexStr
            log(
                "Validating package...",
                debug: "Calculated hash: \(calculatedHash), Expected hash: \(package.hash)")
            guard package.hash.caseInsensitiveCompare(calculatedHash) == .orderedSame else {
                throw AddError.invalidPackage
            }
            log(debug: "Validation successful for \(package.name)")
        }
        
        /// Unpacks the downloaded package.
        /// - Parameters:
        ///   - package: The package module to unpack.
        ///   - url: URL where the downloaded package is located.
        /// - Returns: URL where the package is unpacked.
        /// - Throws: IOException if the package could not be unpacked.
        func unpack(package: Package.Module, at url: URL) throws -> URL {
            log("Unpacking package...", debug: "Package type: \(package.type.rawValue)")
            let resultURL: URL
            switch package.type {
            case .binary:
                resultURL = url
            case .zip:
                resultURL = try unzip(from: url.path(), for: package.name)
            case .archive:
                resultURL = try unarchive(
                    from: url.path(), for: package.name, strip: package.isBundle)
            }
            log(debug: "Unpacked \(package.name) to: \(resultURL.path)")
            return resultURL
        }
        
        func execute(package: Package.Module, at url: URL) throws {
                    log(
                        debug: "Executable paths: \(package.executablePaths.joined(separator: "\n"))"
                    )
                    
                    var terminationStatusProduct: Int = 0
                    
                    for executablePath in package.executablePaths {
                        log(debug: "Executable path: \(executablePath)")
                        
                        let fileURL = url.appendingPathComponent(executablePath)
                        
                        log(debug: "Setting executable permissions for file: \(fileURL.path)...")
                        try setExecutablePermission(for: fileURL)
                        
                        let process = Process()
                        
                        if package.type != .binary {
                            log(debug: "Setting current directory to \(url.path)")
                            process.currentDirectoryURL = url
                        }
                        
                        process.executableURL = fileURL
                        process.arguments = package.testArgs
                        process.standardOutput = nil
                        process.standardError = nil
                        
                        log(debug: "Running process for file: \(fileURL.path)...")
                        try process.run()
                        process.waitUntilExit()
                        
                        log(debug: "Process exited with status: \(process.terminationStatus)")
                        terminationStatusProduct *= Int(process.terminationStatus)
                    }
                    
                    guard terminationStatusProduct == 0 else {
                        throw AddError.executeProcessFailed
                    }
                    
            log(debug: "All executables were successfully installed")
                }
        
        /// Installs the package to the home directory.
        /// - Parameters:
        ///   - package: The package module to install.
        ///   - url: URL where the unpacked package is located.
        /// - Returns: `true` if installation is successful, `false` otherwise.
        /// - Throws: `IOException` if the package cannot be installed.
        func install(package: Package.Module, from url: URL) async throws {
            log("Installing package...")
            let homePackagesPath = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Packages")
            
            if !fileManager.fileExists(atPath: homePackagesPath.path) {
                try fileManager.createDirectory(
                    at: homePackagesPath, withIntermediateDirectories: true)
            }
            
            let destination: URL
            if package.isBundle {
                destination = homePackagesPath.appendingPathComponent("_" + package.name)
                try fileManager.moveItem(at: url, to: destination)
                try createSymlinks(for: package, at: destination, in: homePackagesPath)
            } else {
                destination = homePackagesPath.appendingPathComponent(package.name)
                try fileManager.moveItem(
                    at: url.appendingPathComponent(package.executablePaths.first ?? ""),
                    to: destination)
            }
            
            let allInstalled = package.executablePaths.allSatisfy { path in
                fileManager.isExecutableFile(
                    atPath: homePackagesPath.appendingPathComponent(
                        String(path.split(separator: "/").last ?? "")
                    ).path)
            }
            
            log(allInstalled ? "Installation complete!" : "Installation failed.")
        }
        
        /// Creates symlinks for executable paths within the installed package.
        /// - Parameters:
        ///   - package: The package module containing executables.
        ///   - destination: URL where the package is installed.
        ///   - homePackagesPath: Path to the home packages directory.
        /// - Throws: `IOException` if symlink creation fails or executable path is missing.
        func createSymlinks(
            for package: Package.Module, at destination: URL, in homePackagesPath: URL
        ) throws {
            for path in package.executablePaths {
                guard let executable = path.split(separator: "/").last else {
                    throw AddError.missingExecutablePath
                }
                log(debug: "Creating symlink for \(executable)")
                try fileManager.createSymbolicLink(
                    at: homePackagesPath.appendingPathComponent(String(executable)),
                    withDestinationURL: destination.appending(path: path))
            }
        }
        
        /// Logs messages to console based on the configured log level.
        /// - Parameters:
        ///   - info: Information message to log.
        ///   - debug: Debug message to log.
        func log(_ info: String? = nil, debug: String? = nil) {
            if let info {
                print(info)
            }
            
            if let debug {
                if options.verbose {
                    print(debug)
                }
            }
        }
    }
}
