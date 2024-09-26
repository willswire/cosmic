//
//  Setup.swift
//  Cosmic
//
//  Created by Will Walker on 9/20/24.
//

import AppKit
import ArgumentParser
import CryptoKit
import Foundation
import Network
import PklSwift
import SystemConfiguration

extension Cosmic {
    struct Setup: AsyncParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Setup cosmic.")
        @OptionGroup var options: Cosmic.Options
        
        enum SetupError: Error {
            case pklError(String)
            case directoryCreationFailed(String)
            case downloadFailed(String)
            case installationFailed(String)
            case profileModificationFailed(String)
            case permissionSettingFailed(String)
        }
        
        /// Main entry point for the `setup` subcommand.
        mutating func run() async throws {
            // Check if setup has been run before
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: "hasRunSetup") && !options.force {
                log("Setup has already been run. Are you sure you want to run it again?")
                log("If so, append `--force` to the command to force setup.")
                // You can ask the user for confirmation here or exit early if desired.
                return
            }
            
            // Create Packages directory if it doesn't exist
            try createPackagesDirectory()
            
            // Download and install PKL
            let pklURL = try await downloadPkl()
            log("Downloaded pkl to \(pklURL)")
            
            try installPkl(from: pklURL)
            log("Pkl installed successfully.")
            
            // Add Cosmic Packages to PATH
            let isProfileModified = try modifyShellProfiles()
            log(isProfileModified ? "Profile modified." : "Unable to modify profile!")
            
            // Mark setup as completed
            defaults.set(true, forKey: "hasRunSetup")
            log("Setup completed successfully.")
        }
        
        /// Creates the `Packages` directory in the user's home directory if it does not exist.
        func createPackagesDirectory() throws {
            let fm = FileManager.default
            let homePackagesPath = fm.homeDirectoryForCurrentUser.appendingPathComponent("Packages")
            
            if !fm.fileExists(atPath: homePackagesPath.path) {
                do {
                    try fm.createDirectory(at: homePackagesPath, withIntermediateDirectories: true)
                } catch {
                    throw SetupError.directoryCreationFailed(
                        "Failed to create directory at \(homePackagesPath.path)")
                }
            }
        }
        
        /// Downloads the PKL binary from GitHub.
        /// - Returns: A `URL` pointing to the downloaded PKL binary.
        func downloadPkl() async throws -> URL {
            let pklURLString =
            "https://github.com/apple/pkl/releases/download/0.26.3/pkl-macos-aarch64"
            
            guard let url = URL(string: pklURLString) else {
                throw SetupError.pklError("Invalid PKL download URL.")
            }
            
            do {
                let (location, _) = try await sharedSession.download(from: url)
                return location
            } catch {
                throw SetupError.downloadFailed(
                    "Failed to download PKL binary from \(pklURLString)")
            }
        }
        
        /// Installs the PKL binary by moving it to the `Packages` directory and setting executable permissions.
        func installPkl(from url: URL) throws {
            let fm = FileManager.default
            let homePackagesPath = fm.homeDirectoryForCurrentUser.appendingPathComponent("Packages")
            let pklDestinationPath = homePackagesPath.appendingPathComponent("pkl")
            
            if !fm.fileExists(atPath: pklDestinationPath.path) {
                do {
                    try fm.moveItem(at: url, to: pklDestinationPath)
                } catch {
                    throw SetupError.installationFailed(
                        "Failed to move PKL binary to \(pklDestinationPath.path)")
                }
            }
            
            do {
                try setExecutablePermission(for: pklDestinationPath)
            } catch {
                throw SetupError.permissionSettingFailed(
                    "Failed to set executable permissions for \(pklDestinationPath.path)")
            }
        }
        
        /// Adds executable permission to the PKL binary.
        func setExecutablePermission(for file: URL) throws {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: file.path)
        }
        
        /// Modifies common shell profiles by adding the Cosmic Packages directory to the user's PATH.
        /// - Returns: A `Bool` indicating whether any profiles were modified.
        func modifyShellProfiles() throws -> Bool {
            let fm = FileManager.default
            let homeDirectory = fm.homeDirectoryForCurrentUser
            let homePackagesPath = homeDirectory.appendingPathComponent("Packages").path
            let pathEntry = "\n# Added by Cosmic\nexport PATH=\"$PATH:\(homePackagesPath)\"\n"
            let shellProfiles = [".bashrc", ".zshrc", ".profile", ".bash_profile"]
            var profileModified = false
            
            for profile in shellProfiles {
                let profilePath = homeDirectory.appendingPathComponent(profile).path
                var resolvedProfilePath = profilePath
                
                // Resolve symlink if the profile is a symlink
                if fm.fileExists(atPath: profilePath),
                   let resolvedPath = try? fm.destinationOfSymbolicLink(atPath: profilePath)
                {
                    resolvedProfilePath = resolvedPath
                }
                
                if fm.fileExists(atPath: resolvedProfilePath) {
                    profileModified = true
                    do {
                        try backupProfile(resolvedProfilePath)
                        try appendToFile(pathEntry, at: resolvedProfilePath)
                        log("Added \(homePackagesPath) to \(profile)")
                    } catch {
                        throw SetupError.profileModificationFailed(
                            "Failed to modify profile: \(profile)")
                    }
                }
            }
            
            if !profileModified {
                log(
                    "No common shell profile found. Please manually add the following to your shell profile:"
                )
                log(pathEntry)
            }
            
            return profileModified
        }
        
        /// Appends the given string to the specified file.
        func appendToFile(_ text: String, at filePath: String) throws {
            if let data = text.data(using: .utf8) {
                let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: filePath))
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        }
        
        /// Creates a backup of the given shell profile by copying it with a `.bak` extension.
        func backupProfile(_ profilePath: String) throws {
            let timestamp = Date().formatted(Date.ISO8601FormatStyle().dateSeparator(.dash))
            let backupPath = profilePath + "." + timestamp + ".bak"
            try FileManager.default.copyItem(atPath: profilePath, toPath: backupPath)
        }
        
        /// Logs a message if the verbose option is enabled.
        func log(_ message: String) {}
    }
}
