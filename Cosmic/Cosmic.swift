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
        subcommands: [Setup.self, Add.self])
    
    enum LogLevel: EnumerableFlag {
        case debug
        case info
        case warning
        case error
    }

    struct Options: ParsableArguments {
        @Flag var logLevel: LogLevel = .info
        @Flag var force: Bool = false
    }
}
