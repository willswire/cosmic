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
    
    struct Options: ParsableArguments {
        @Flag(name: [.long, .customShort("v")]) var verbose: Bool = false
    }
}
