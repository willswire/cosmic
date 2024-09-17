//
//  Utils.swift
//  Crisp
//
//  Created by Will Walker on 9/16/24.
//

import Foundation
import CryptoKit

extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }

    var hexStr: String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }
}

enum ExtractionError: Error {
    case fileDoesNotExist(String)
    case failedToCreateDirectory(String)
    case extractionFailed(Int32)
    case extractionProcessFailed(String)
}

func extract(from sourcePath: String, for name: String) throws -> URL {
    let fileManager = FileManager.default
    
    // Ensure the source file exists
    guard fileManager.fileExists(atPath: sourcePath) else {
        throw ExtractionError.fileDoesNotExist("File does not exist at \(sourcePath)")
    }
    
    // Use the system's temporary directory for extraction
    let temporaryDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent(name)
    
    let destinationPath = temporaryDirectoryURL.path
    do {
        try fileManager.createDirectory(atPath: destinationPath, withIntermediateDirectories: true, attributes: nil)
    } catch {
        throw ExtractionError.failedToCreateDirectory("Failed to create destination directory: \(error.localizedDescription)")
    }
    
    // Create the `tar` process
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
    process.arguments = ["-xzf", sourcePath, "-C", destinationPath]
    
    do {
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            print("Extraction completed successfully!")
        } else {
            throw ExtractionError.extractionFailed(process.terminationStatus)
        }
    } catch {
        throw ExtractionError.extractionProcessFailed("Failed to run extraction process: \(error.localizedDescription)")
    }
    
    return temporaryDirectoryURL
}

