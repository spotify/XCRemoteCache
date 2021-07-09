protocol Meta: Codable {
    /// Unique id of the artifact
    var fileKey: String { get }
}

struct MainArtifactMeta: Meta, Equatable {
    /// List of all files used in the compilation
    var dependencies: [String]
    var fileKey: String
    /// Dependencies files raw fingerprint digest
    var rawFingerprint: String
    /// Commit sha that generated a product
    var generationCommit: String
    /// Name of the target
    var targetName: String
    /// Configuration used in the build
    var configuration: String
    /// Platform used in the build
    var platform: String
    /// Xcode build number generated the product
    var xcode: String
    /// All compilation files
    var inputs: [String]
    /// Extra keys added by meta plugins
    var pluginsKeys: [String: String]
}
