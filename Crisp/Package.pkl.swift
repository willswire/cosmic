// Code generated from Pkl module `Package`. DO NOT EDIT.
import PklSwift

public enum Package {}

extension Package {
    public struct Module: PklRegisteredType, Decodable, Hashable {
        public static var registeredIdentifier: String = "Package"

        /// The name of this package.
        public var name: String

        /// The pre-built binary URL of this package.
        public var url: String

        /// The version of the binary.
        public var version: String

        /// The SHA-256 hash of the binary.
        public var hash: String

        public var executablePath: String

        public var testArgs: [String]

        public init(
            name: String,
            url: String,
            version: String,
            hash: String,
            executablePath: String,
            testArgs: [String]
        ) {
            self.name = name
            self.url = url
            self.version = version
            self.hash = hash
            self.executablePath = executablePath
            self.testArgs = testArgs
        }
    }

    /// Load the Pkl module at the given source and evaluate it into `Package.Module`.
    ///
    /// - Parameter source: The source of the Pkl module.
    public static func loadFrom(source: ModuleSource) async throws -> Package.Module {
        try await PklSwift.withEvaluator { evaluator in
            try await loadFrom(evaluator: evaluator, source: source)
        }
    }

    /// Load the Pkl module at the given source and evaluate it with the given evaluator into
    /// `Package.Module`.
    ///
    /// - Parameter evaluator: The evaluator to use for evaluation.
    /// - Parameter source: The module to evaluate.
    public static func loadFrom(
        evaluator: PklSwift.Evaluator,
        source: PklSwift.ModuleSource
    ) async throws -> Package.Module {
        try await evaluator.evaluateModule(source: source, as: Module.self)
    }
}