@testable import XCRemoteCache
import XCTest

class FileManagerUtilitiesTests: FileXCTestCase {

    private let manager = FileManager.default

    func testForceLinkItemCreatesParentDir() throws {
        let sampleFile = try prepareTempDir().appendingPathComponent("file.txt")
        let linkDestination = try prepareTempDir().appendingPathComponent("dir").appendingPathComponent("file.txt")
        try fileManager.spt_createEmptyFile(sampleFile)

        try manager.spt_forceLinkItem(at: sampleFile, to: linkDestination)

        XCTAssertTrue(fileManager.fileExists(atPath: linkDestination.path))
    }

    func testDeletingFile() throws {
        let sampleFile = try prepareTempDir().appendingPathComponent("file.txt")
        try fileManager.spt_createEmptyFile(sampleFile)

        try manager.spt_deleteItem(at: sampleFile)

        XCTAssertFalse(fileManager.fileExists(atPath: sampleFile.path))
    }

    func testDeletingNonExistingFileDoesNotThrow() throws {
        let sampleFileURL = try prepareTempDir().appendingPathComponent("file.txt")

        XCTAssertNoThrow(try manager.spt_deleteItem(at: sampleFileURL))
    }

    func testDeletingDir() throws {
        let sampleDir = try prepareTempDir().appendingPathComponent("dir")
        try fileManager.spt_createEmptyDir(sampleDir)

        try manager.spt_deleteItem(at: sampleDir)

        XCTAssertFalse(fileManager.fileExists(atPath: sampleDir.path))
    }

    func testDeletingNonExistingDirDoesNotThrow() throws {
        let sampleDir = try prepareTempDir().appendingPathComponent("dir")

        XCTAssertNoThrow(try manager.spt_deleteItem(at: sampleDir))
    }

    func testListsItemsWithSymlinkInPath() throws {
        let sampleDir = try prepareTempDir()
        let directory = sampleDir.appendingPathComponent("directory")
        let fileInDirectory = directory.appendingPathComponent("file.txt")
        let locationWithSymlink = sampleDir.appendingPathComponent("symlink")
        try fileManager.spt_createEmptyFile(fileInDirectory)
        try fileManager.createSymbolicLink(at: locationWithSymlink, withDestinationURL: directory)

        let allFiles = try fileManager.items(at: locationWithSymlink)

        let allFilesSymlinkResolved = allFiles.map { $0.resolvingSymlinksInPath() }
        let expectedFileSymlinkResolved = fileInDirectory.resolvingSymlinksInPath()
        XCTAssertEqual(allFilesSymlinkResolved, [expectedFileSymlinkResolved])
    }
}
