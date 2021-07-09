@testable import XCRemoteCache
import XCTest

class FileManagerDirScannerTests: FileXCTestCase {
    private var dirScanner: DirScanner!

    override func setUpWithError() throws {
        try super.setUpWithError()
        _ = try prepareTempDir()

        dirScanner = FileManager.default
    }

    func testRecognizesNonExistingItem() {
        let file = workingDirectory!.appendingPathComponent("non.existing")

        try XCTAssertEqual(fileManager.itemType(atPath: file.path), .nonExisting)
    }

    func testRecognizesFileItem() throws {
        let file = workingDirectory!.appendingPathComponent("existing.file")
        try fileManager.spt_createEmptyFile(file)

        try XCTAssertEqual(fileManager.itemType(atPath: file.path), .file)
    }

    func testRecognizesDirItem() throws {
        let dir = workingDirectory!.appendingPathComponent("dir")
        try fileManager.spt_createEmptyDir(dir)

        try XCTAssertEqual(fileManager.itemType(atPath: dir.path), .dir)
    }

    func testFindsFilesInAFlatDir() throws {
        // workingDirectory may contain symbolic links in a path
        let dir = workingDirectory!.resolvingSymlinksInPath()
        let subDir = dir.appendingPathComponent("dir", isDirectory: true)
        let file1 = dir.appendingPathComponent("file1")
        let file2 = subDir.appendingPathComponent("file2")
        try fileManager.spt_createEmptyFile(file1)
        try fileManager.spt_createEmptyFile(file2)

        let items = try dirScanner.items(at: dir)

        // returned items may contain symbolic links in a path
        let resolvedItems = items.map { $0.resolvingSymlinksInPath() }
        XCTAssertEqual(Set(resolvedItems), Set([subDir, file1]))
    }

    func testFailsToFindItemsNonExistingDir() throws {
        let dir = workingDirectory!.appendingPathComponent("dir")

        try XCTAssertThrowsError(dirScanner.items(at: dir))
    }
}
