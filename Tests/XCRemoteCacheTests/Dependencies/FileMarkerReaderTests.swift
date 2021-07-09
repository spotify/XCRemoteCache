@testable import XCRemoteCache

import XCTest

class FileMarkerReaderTests: XCTestCase {

    func buildTempFile(content: String) throws -> URL {
        let directory = NSTemporaryDirectory()
        let url = try NSURL.fileURL(withPathComponents: [directory, name]).unwrap()
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testReading() throws {
        let url = try buildTempFile(content: """
        dependencies: \\
        /file1.m \\
        /Some/Path.file2.h
        """)
        let reader = FileMarkerReader(url, fileManager: FileManager.default)

        let readValue = try reader.listFilesURLs()

        XCTAssertEqual(Set(readValue), Set(["/file1.m", "/Some/Path.file2.h"].map(URL.init(fileURLWithPath:))))
    }

    func testReadingEmptyMarker() throws {
        let url = try buildTempFile(content: """
        dependencies: \\
        """)
        let reader = FileMarkerReader(url, fileManager: FileManager.default)

        let readValue = try reader.listFilesURLs()

        XCTAssertEqual(readValue, [])
    }
}
