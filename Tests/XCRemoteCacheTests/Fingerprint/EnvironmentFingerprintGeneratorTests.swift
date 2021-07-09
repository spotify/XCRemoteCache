@testable import XCRemoteCache
import XCTest

class EnvironmentFingerprintGeneratorTests: XCTestCase {

    private static let defaultENV = [
        "GCC_PREPROCESSOR_DEFINITIONS": "GCC",
        "CLANG_PROFILE_DATA_DIRECTORY": "CLANG",
        "TARGET_NAME": "TARGET",
        "CONFIGURATION": "CONG",
        "PLATFORM_NAME": "PLAT",
        "XCODE_PRODUCT_BUILD_VERSION": "XC",
        "CURRENT_PROJECT_VERSION": "1",
        "DYLIB_COMPATIBILITY_VERSION": "2",
        "DYLIB_CURRENT_VERSION": "3",
        "PRODUCT_MODULE_NAME": "4",
    ]
    /// Corresponds to EnvironmentFingerprintGenerator.version
    private static let currentVersion = "5"

    private var config: XCRemoteCacheConfig!
    private var generator: FingerprintAccumulator!
    private var fingerprintGenerator: EnvironmentFingerprintGenerator!

    override func setUp() {
        super.setUp()
        config = XCRemoteCacheConfig(sourceRoot: "")
        generator = FingerprintAccumulatorFake()
        fingerprintGenerator = EnvironmentFingerprintGenerator(
            configuration: config,
            env: Self.defaultENV,
            generator: generator
        )
    }

    func testConsidersDefaultEnvs() throws {
        let fingerprint = try fingerprintGenerator.generateFingerprint()

        XCTAssertEqual(fingerprint, "GCC,CLANG,TARGET,CONG,PLAT,XC,1,2,3,4,\(Self.currentVersion)")
    }

    func testFingerprintIncludesVersionAsLastComponent() throws {
        let fingerprint = try fingerprintGenerator.generateFingerprint()

        XCTAssertTrue(fingerprint.hasSuffix(",\(Self.currentVersion)"))
    }

    func testMissedEnvAppendsEmptyStringToGenerator() throws {
        let fingerprintGenerator = EnvironmentFingerprintGenerator(
            configuration: config,
            env: [:],
            generator: generator
        )

        let fingerprint = try fingerprintGenerator.generateFingerprint()

        XCTAssertEqual(fingerprint, ",,,,,,,,,,\(Self.currentVersion)")
    }

    func testConsidersCustomEnvs() throws {
        var config = self.config!
        config.customFingerprintEnvs = ["CUSTOM_ENV"]
        var env = Self.defaultENV
        env["CUSTOM_ENV"] = "CUSTOM_VALUE"
        let fingerprintGenerator = EnvironmentFingerprintGenerator(
            configuration: config,
            env: env,
            generator: generator
        )

        let fingerprint = try fingerprintGenerator.generateFingerprint()

        XCTAssertEqual(fingerprint, "GCC,CLANG,TARGET,CONG,PLAT,XC,1,2,3,4,CUSTOM_VALUE,\(Self.currentVersion)")
    }
}
