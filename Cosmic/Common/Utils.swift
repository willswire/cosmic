//
//  Utils.swift
//  Cosmic
//
//  Created by Will Walker on 9/16/24.
//

import CryptoKit
import Foundation

/// Shared, configured URL Session
let sharedSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    return URLSession(configuration: configuration)
}()

/// Shared, default File Manager
let fileManager: FileManager = .default

/// Extension providing utility properties to `Digest`.
extension Digest {
    /// Array of bytes representing the digest.
    var bytes: [UInt8] { Array(makeIterator()) }

    /// Hexadecimal string representation of the digest.
    var hexStr: String { bytes.map { String(format: "%02X", $0) }.joined() }
}

/// Enumerates errors that might occur during extraction.
enum ExtractionError: Error {
    case fileDoesNotExist(String)
    case failedToCreateDirectory(String)
    case extractionFailed(Int32)
    case extractionProcessFailed(String)
}

/// Extracts a compressed (tar.gz) file to a temporary directory.
///
/// - Parameters:
///   - sourcePath: Path of the compressed file.
///   - name: Name of the package being extracted.
/// - Returns: URL of the extracted files' directory.
/// - Throws: `ExtractionError` in case of issues during the extraction.
func unarchive(from sourcePath: String, for name: String, strip: Bool) throws -> URL {
    let fileManager = FileManager.default

    // Check if the source file exists
    guard fileManager.fileExists(atPath: sourcePath) else {
        throw ExtractionError.fileDoesNotExist("File does not exist at \(sourcePath)")
    }

    // Set up the temporary directory path for extraction
    let destinationURL = fileManager.temporaryDirectory.appendingPathComponent(name)

    // Create the destination directory
    do {
        try fileManager.createDirectory(
            at: destinationURL, withIntermediateDirectories: true, attributes: nil)
    } catch {
        throw ExtractionError.failedToCreateDirectory(
            "Failed to create destination directory: \(error.localizedDescription)")
    }

    // Configure the `tar` process for extraction
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
    process.arguments = ["-xzf", sourcePath, "-C", destinationURL.path]
    
    if strip {
        process.arguments?.append("--strip-components=1")
    }
    
    process.standardOutput = nil
    process.standardError = nil

    // Execute the `tar` process and handle its result
    do {
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ExtractionError.extractionFailed(process.terminationStatus)
        }

        return destinationURL
    } catch {
        throw ExtractionError.extractionProcessFailed(
            "Failed to run extraction process: \(error.localizedDescription)")
    }
}

/// Extracts a compressed (zip) file to a temporary directory.
///
/// - Parameters:
///   - sourcePath: Path of the compressed file.
///   - name: Name of the package being extracted.
/// - Returns: URL of the extracted files' directory.
/// - Throws: `ExtractionError` in case of issues during the extraction.
//func unzip(from sourcePath: String, for name: String) throws -> URL {
//    let fileManager = FileManager.default
//
//    // Check if the source file exists
//    guard fileManager.fileExists(atPath: sourcePath) else {
//        throw ExtractionError.fileDoesNotExist("File does not exist at \(sourcePath)")
//    }
//
//    // Set up the temporary directory path for extraction
//    let destinationURL = fileManager.temporaryDirectory.appendingPathComponent(name)
//
//    // Create the destination directory
//    do {
//        try fileManager.createDirectory(
//            at: destinationURL, withIntermediateDirectories: true, attributes: nil)
//    } catch {
//        throw ExtractionError.failedToCreateDirectory(
//            "Failed to create destination directory: \(error.localizedDescription)")
//    }
//
//    // Configure the `unzip` process for extraction
//    let process = Process()
//    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
//    process.arguments = [sourcePath, "-d", destinationURL.path]
//    process.standardOutput = nil
//    process.standardError = nil
//
//    // Execute the `unzip` process and handle its result
//    do {
//        try process.run()
//        process.waitUntilExit()
//
//        guard process.terminationStatus == 0 else {
//            throw ExtractionError.extractionFailed(process.terminationStatus)
//        }
//
//        return destinationURL
//    } catch {
//        throw ExtractionError.extractionProcessFailed(
//            "Failed to run extraction process: \(error.localizedDescription)")
//    }
//}

func setExecutablePermission(for fileURL: URL) throws {
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    if let permissions = attributes[.posixPermissions] as? NSNumber {
        let newPermissions = NSNumber(value: permissions.intValue | 0o111)
        try FileManager.default.setAttributes(
            [.posixPermissions: newPermissions], ofItemAtPath: fileURL.path)
    }
}
