/// Generates a fingerprint string of the environment (compilation context)
class EnvironmentFingerprintGenerator {
    /// Default ENV variables constituing the environment fingerprint
    private static let defaultEnvFingerprintKeys = [
        "GCC_PREPROCESSOR_DEFINITIONS",
        "CLANG_PROFILE_DATA_DIRECTORY",
        "TARGET_NAME",
        "CONFIGURATION",
        "PLATFORM_NAME",
        "XCODE_PRODUCT_BUILD_VERSION",
        "CURRENT_PROJECT_VERSION",
        "DYLIB_COMPATIBILITY_VERSION",
        "DYLIB_CURRENT_VERSION",
        "PRODUCT_MODULE_NAME",
    ]
    private let version: String
    private let customFingerprintEnvs: [String]
    private let env: [String: String]
    private let generator: FingerprintAccumulator
    private var generatedFingerprint: RawFingerprint?

    init(configuration: XCRemoteCacheConfig, env: [String: String], generator: FingerprintAccumulator) {
        self.generator = generator
        self.env = env
        customFingerprintEnvs = configuration.customFingerprintEnvs
        version = configuration.schemaVersion
    }

    func generateFingerprint() throws -> RawFingerprint {
        if let fingerprint = generatedFingerprint {
            return fingerprint
        }
        try fill(envKeys: Self.defaultEnvFingerprintKeys + customFingerprintEnvs)
        try generator.append(version)
        return try generator.generate()
    }

    /// Creates a fingerprint of the environemtn, by hashing all ENVs specified in keys
    private func fill(envKeys keys: [String]) throws {
        for key in keys {
            let value = env.readEnv(key: key) ?? ""
            try generator.append(value)
        }
    }
}
