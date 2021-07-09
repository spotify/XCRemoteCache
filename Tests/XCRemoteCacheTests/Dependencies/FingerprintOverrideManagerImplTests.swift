@testable import XCRemoteCache
import XCTest


class FingerprintOverrideManagerImplTests: XCTestCase {

    private var manager: FingerprintOverrideManagerImpl!

    override func setUp() {
        super.setUp()
        manager = FingerprintOverrideManagerImpl(
            overridingFileExtensions: ["swiftmodule"],
            fingerprintOverrideExtension: "md5",
            fileManager: FileManager.default
        )
    }

    private func prepareDirectoryWithFiles(_ paths: [String], name: String = #function) throws -> URL {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let workingDir = tempDir.appendingPathComponent(name)
        // Create new, empty directory
        if FileManager.default.fileExists(atPath: workingDir.path) {
            try FileManager.default.removeItem(at: workingDir)
        }
        try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true, attributes: nil)
        for path in paths {
            let fileURL = workingDir.appendingPathComponent(path)
            FileManager.default.createFile(
                atPath: fileURL.path,
                contents: nil,
                attributes: nil
            )
        }
        return workingDir
    }

    func testUsesOverridesForFilesWithGivenExtension() throws {
        let workingDir = try prepareDirectoryWithFiles(["file1.swiftmodule", "file1.swiftmodule.md5"])
        let dependencyURL = workingDir.appendingPathComponent("file1.swiftmodule")
        let fingerprintURL = workingDir.appendingPathComponent("file1.swiftmodule.md5")

        let dependency = Dependency(url: dependencyURL, type: .product)

        let fingerprint = manager.getFingerprintFile(dependency)

        XCTAssertEqual(fingerprint.url, fingerprintURL)
    }

    func testUsesOriginalFileWhenOverrideFileIsMissing() throws {
        let workingDir = try prepareDirectoryWithFiles(["file1.swiftmodule"])
        let dependencyURL = workingDir.appendingPathComponent("file1.swiftmodule")
        let dependency = Dependency(url: dependencyURL, type: .product)

        let fingerprint = manager.getFingerprintFile(dependency)

        XCTAssertEqual(fingerprint, dependency)
    }

    func testUsesOriginalFileForOtherExtensions() throws {
        let workingDir = try prepareDirectoryWithFiles(["file1.ext", "file1.ext.md5"])
        let dependencyURL = workingDir.appendingPathComponent("file1.ext")
        let dependency = Dependency(url: dependencyURL, type: .product)

        let fingerprint = manager.getFingerprintFile(dependency)

        XCTAssertEqual(fingerprint.url, dependencyURL)
    }

    func testReturnsFingerprintTypeWhenOverrideWasUsed() throws {
        let workingDir = try prepareDirectoryWithFiles(["file1.swiftmodule", "file1.swiftmodule.md5"])
        let dependencyURL = workingDir.appendingPathComponent("file1.swiftmodule")
        let dependency = Dependency(url: dependencyURL, type: .product)

        let fingerprintDependency = manager.getFingerprintFile(dependency)

        XCTAssertEqual(fingerprintDependency.type, .fingerprint)
    }
}
