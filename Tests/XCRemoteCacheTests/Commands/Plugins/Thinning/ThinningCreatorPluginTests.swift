@testable import XCRemoteCache
import XCTest

class ThinningCreatorPluginTests: FileXCTestCase {

    private static let sampleMeta = MainArtifactSampleMeta.defaults
    private var targetTempDirRoot: URL!
    private var currentTargetTempDir: URL!
    private var plugin: ThinningCreatorPlugin!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let workingDir = try prepareTempDir()
        targetTempDirRoot = workingDir.appendingPathComponent("Root")
        currentTargetTempDir = targetTempDirRoot.appendingPathComponent("Current.build")
        try fileManager.spt_createEmptyDir(currentTargetTempDir)
        plugin = ThinningCreatorPlugin(targetTempDir: currentTargetTempDir, dirScanner: FileManager.default)
    }

    func testReturnsEmptyExtraKeysForNoArtifacts() throws {
        let extraKeys = try plugin.extraMetaKeys(Self.sampleMeta)

        XCTAssertEqual(extraKeys, [:])
    }

    func testDefinesExtraMetaKeysForOtherTargetThatUploadedArtifact() throws {
        let otherTargetTempDir = targetTempDirRoot.appendingPathComponent("Other.build")
        let generatedArtifact = otherTargetTempDir
            .appendingPathComponent("xccache")
            .appendingPathComponent("produced")
            .appendingPathComponent("123")
            .appendingPathExtension("zip")
        try fileManager.spt_createEmptyFile(generatedArtifact)

        let extraKeys = try plugin.extraMetaKeys(Self.sampleMeta)

        XCTAssertEqual(extraKeys, ["thinning_Other": "123"])
    }

    func testThrowsErrorWhenATargetHasMultipleArtifactsGenerated() throws {
        let otherTargetTempDir = targetTempDirRoot.appendingPathComponent("Other.build")
        let generatedArtifact = otherTargetTempDir
            .appendingPathComponent("xccache")
            .appendingPathComponent("produced")
            .appendingPathComponent("123")
            .appendingPathExtension("zip")
        let otherGeneratedArtifact = otherTargetTempDir
            .appendingPathComponent("xccache")
            .appendingPathComponent("produced")
            .appendingPathComponent("321")
            .appendingPathExtension("zip")
        try fileManager.spt_createEmptyFile(generatedArtifact)
        try fileManager.spt_createEmptyFile(otherGeneratedArtifact)

        XCTAssertThrowsError(try plugin.extraMetaKeys(Self.sampleMeta))
    }
}
