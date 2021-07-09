@testable import XCRemoteCache
import XCTest

class DefaultArtifactInspectorTests: FileXCTestCase {
    private var inspector: DefaultArtifactInspector!
    private var artifact: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        artifact = try prepareTempDir().appendingPathComponent("artifact")
        inspector = DefaultArtifactInspector(dirAccessor: fileManager)
    }

    func testFindingALibrary() throws {
        let binary = artifact.appendingPathComponent("binary.a")
        try fileManager.spt_writeToFile(atPath: binary.path, contents: nil)

        let binaries = try inspector.findBinaryProducts(fromArtifact: artifact)

        let binariesWithoutSymlinks = binaries.map { $0.resolvingSymlinksInPath() }
        XCTAssertEqual(binariesWithoutSymlinks, [binary])
    }

    func testRecognizingModuleName() throws {
        let swiftmoduleDir = artifact
            .appendingPathComponent("swiftmodule")
            .appendingPathComponent("x86")
        let swiftmoduleFile = swiftmoduleDir.appendingPathComponent("MyModule.swiftmodule")
        try fileManager.spt_writeToFile(atPath: swiftmoduleFile.path, contents: nil)

        let name = try inspector.recognizeModuleName(fromArtifact: artifact, arch: "x86")

        XCTAssertEqual(name, "MyModule")
    }

    func testRecognizingNonExistingSwiftModuleAsNil() throws {
        let name = try inspector.recognizeModuleName(fromArtifact: artifact, arch: "x86")

        XCTAssertNil(name)
    }

    func testRecognizingThrowsWhenMissingSwiftmoduleFile() throws {
        let swiftmoduleDir = artifact
            .appendingPathComponent("swiftmodule")
            .appendingPathComponent("x86")
        try fileManager.spt_createEmptyDir(swiftmoduleDir)

        XCTAssertThrowsError(try inspector.recognizeModuleName(fromArtifact: artifact, arch: "x86")) { error in
            guard case ArtifactInspectorError.missingSwiftmoduleFileInArtifact(artifact: artifact) = error else {
                XCTFail("Unexpected error \(error).")
                return
            }
        }
    }
}
