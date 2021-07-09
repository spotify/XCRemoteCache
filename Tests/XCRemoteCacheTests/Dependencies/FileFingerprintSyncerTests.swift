@testable import XCRemoteCache

import XCTest

class FileFingerprintSyncerTests: FileXCTestCase {

    private var syncer: FileFingerprintSyncer!
    private var swiftmoduleDir: URL!

    override func setUpWithError() throws {
        syncer = FileFingerprintSyncer(
            fingerprintOverrideExtension: "md5",
            dirAccessor: fileManager,
            extensions: ["swiftmodule"]
        )
        swiftmoduleDir = try prepareTempDir().appendingPathComponent("module")
    }

    func testDecorateCreatesValidOverrideFile() throws {
        let swiftmodule = swiftmoduleDir.appendingPathComponent("x86_64.swiftmodule")
        let swiftmoduleDecoration = swiftmoduleDir.appendingPathComponent("x86_64.swiftmodule.md5")
        try fileManager.spt_createEmptyFile(swiftmodule)

        try syncer.decorate(sourceDir: swiftmoduleDir, fingerprint: "1")

        XCTAssertEqual(try String(contentsOf: swiftmoduleDecoration), "1")
    }

    func testDecorateOverridesPreviousOverrideFile() throws {
        let swiftmodule = swiftmoduleDir.appendingPathComponent("x86_64.swiftmodule")
        let swiftmoduleDecoration = swiftmoduleDir.appendingPathComponent("x86_64.swiftmodule.md5")
        try fileManager.spt_createEmptyFile(swiftmodule)
        try "1".write(to: swiftmoduleDecoration, atomically: true, encoding: .utf8)

        try syncer.decorate(sourceDir: swiftmoduleDir, fingerprint: "2")

        XCTAssertEqual(try String(contentsOf: swiftmoduleDecoration), "2")
    }

    func testDeleteRemovesOverrideFile() throws {
        let previousOverrideFile = swiftmoduleDir.appendingPathComponent("x86_64.md5")
        try fileManager.spt_createEmptyFile(previousOverrideFile)

        try syncer.delete(sourceDir: swiftmoduleDir)

        XCTAssertFalse(fileManager.fileExists(atPath: previousOverrideFile.path))
    }

    func testDeletesDoesntDeleteNonOverrideFiles() throws {
        let nonOverrideFile = swiftmoduleDir.appendingPathComponent("x86_64.swiftmodule")
        try fileManager.spt_createEmptyFile(nonOverrideFile)

        try syncer.delete(sourceDir: swiftmoduleDir)

        XCTAssertTrue(fileManager.fileExists(atPath: nonOverrideFile.path))
    }
}
