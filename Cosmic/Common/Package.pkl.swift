// Code generated from Pkl module `Package`. DO NOT EDIT.
import PklSwift

public enum Package {}

extension Package {
    /// The distribution type
    public enum DistributionType: String, CaseIterable, Decodable, Hashable {
        case binary = "Binary"
        case archive = "Archive"
        case zip = "Zip"
    }

    public struct Module: PklRegisteredType, Decodable, Hashable {
        public static var registeredIdentifier: String = "Package"

        /// The name of this package.
        public var name: String

        /// The pre-built binary URL of this package.
        public var url: String

        /// The package url
        public var purl: String

        /// The version of the binary.
        public var version: String

        /// The SHA-256 hash of the binary.
        public var hash: String

        /// The path of the executable (relative to the resulting URL resource)
        public var executablePaths: [String]

        /// Arguments to pass to the executable to validate its functionality
        public var testArgs: [String]

        public var type: DistributionType

        /// Indicate if the package contains more than a single executable
        public var isBundle: Bool

        public init(
            name: String,
            url: String,
            purl: String,
            version: String,
            hash: String,
            executablePaths: [String],
            testArgs: [String],
            type: DistributionType,
            isBundle: Bool
        ) {
            self.name = name
            self.url = url
            self.purl = purl
            self.version = version
            self.hash = hash
            self.executablePaths = executablePaths
            self.testArgs = testArgs
            self.type = type
            self.isBundle = isBundle
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