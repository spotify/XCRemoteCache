@testable import XCRemoteCache
import XCTest

class LazyFileAccessorTests: FileXCTestCase {

    private var storage: FileAccessorFake!
    private var accessor: LazyFileAccessor!
    private let content1 = "1".data(using: .utf8)
    private let content2 = "2".data(using: .utf8)
    private let path = "samplePath"

    override func setUp() {
        super.setUp()
        storage = FileAccessorFake(mode: .normal)
        accessor = LazyFileAccessor(fileAccessor: storage)
    }

    func testWritingSucceeds() throws {
        try accessor.write(toPath: path, contents: content1)

        try XCTAssertEqual(storage.contents(atPath: path), content1)
    }

    func testWritingOtherContentSucceeds() throws {
        try accessor.write(toPath: path, contents: content1)

        try accessor.write(toPath: path, contents: content2)

        try XCTAssertEqual(storage.contents(atPath: path), content2)
    }

    func testOverwritingEmptyFileSucceeds() throws {
        try accessor.write(toPath: path, contents: nil)

        try accessor.write(toPath: path, contents: content1)

        try XCTAssertEqual(storage.contents(atPath: path), content1)
    }

    func testWritingIsSkippedForTheSameContent() throws {
        try accessor.write(toPath: path, contents: content1)
        let writeMDate = try storage.fileMDate(atPath: path).unwrap()

        try accessor.write(toPath: path, contents: content1)

        let secondWriteMDate = try storage.fileMDate(atPath: path).unwrap()
        XCTAssertEqual(secondWriteMDate, writeMDate)
    }

    func testWritingTheSameContentDoesntModifyDiskINode() throws {
        func getINode(_ file: URL) -> Int {
            var info = stat()
            stat(file.path, &info)
            return Int(info.st_ino)
        }
        let accessor = LazyFileAccessor(fileAccessor: FileManager.default)
        let file = try prepareTempDir().appendingPathComponent("path")
        try accessor.write(toPath: file.path, contents: content1)
        let originalINode = getINode(file)

        try accessor.write(toPath: file.path, contents: content1)

        let postINode = getINode(file)
        XCTAssertNotEqual(postINode, 0)
        XCTAssertEqual(postINode, originalINode)
    }
}
