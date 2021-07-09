@testable import XCRemoteCache
import XCTest

class DiskUsageSizeProviderTests: XCTestCase {
    private let fileManager = FileManager.default
    private var sizeProvider: SizeProvider!
    private var dirURL: URL!
    /// Current size of a block in bytes. All files take on disk multiplication of blocks
    private var blockSize: Int = 0

    override func setUpWithError() throws {
        try super.setUpWithError()
        let testName = try (testRun?.test.name).unwrap()
        dirURL = fileManager.temporaryDirectory.appendingPathComponent(testName)
        if fileManager.fileExists(atPath: dirURL.path) {
            try fileManager.removeItem(at: dirURL)
        }
        try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
        blockSize = try readBlockSize(dirURL)
        XCTAssert(blockSize > 0)

        sizeProvider = DiskUsageSizeProvider(shell: shellGetStdout)
    }

    private func readBlockSize(_ file: URL) throws -> Int {
        var stat1: stat = stat()
        stat((file.path as NSString).fileSystemRepresentation, &stat1)
        return Int(stat1.st_blksize)
    }

    private func createFile(_ fileURL: URL, size: Int) throws {
        let parentDir = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
        let data = Data(count: size)

        fileManager.createFile(atPath: fileURL.path, contents: data, attributes: nil)
    }


    func testEmptyDirTakesZeoBytes() throws {
        let size = try sizeProvider.size(at: dirURL)

        XCTAssertEqual(size, 0)
    }

    func testCountsSizeOfRootFiles() throws {
        let file1 = dirURL.appendingPathComponent("file1")
        let file2 = dirURL.appendingPathComponent("file2")
        try createFile(file1, size: blockSize)
        try createFile(file2, size: blockSize)

        let size = try sizeProvider.size(at: dirURL)

        XCTAssertEqual(size, blockSize * 2)
    }

    func testCountsNestedFiles() throws {
        let file1 = dirURL.appendingPathComponent("file1")
        let file2 = dirURL.appendingPathComponent("subdir").appendingPathComponent("file2")
        try createFile(file1, size: blockSize)
        try createFile(file2, size: 2 * blockSize)

        let size = try sizeProvider.size(at: dirURL)

        XCTAssertEqual(size, blockSize * 3)
    }

    func testReturnsZeroForNonExistingFile() throws {
        let nonExistingURL = dirURL.appendingPathComponent("non_existing")

        let size = try sizeProvider.size(at: nonExistingURL)

        XCTAssertEqual(size, 0)
    }
}
