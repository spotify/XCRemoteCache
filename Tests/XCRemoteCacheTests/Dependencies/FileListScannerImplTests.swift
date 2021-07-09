@testable import XCRemoteCache

import XCTest

class FileListScannerImplTests: XCTestCase {
    private let sampleURL = URL(fileURLWithPath: "/sampleURL")

    func testFileListFindsURL() {
        let listReader = ListReaderMock([sampleURL])
        let scanner = FileListScannerImpl(listReader, caseSensitive: true)

        XCTAssertTrue(try scanner.contains(sampleURL))
    }

    func testFileListFindsURLCaseSensitive() {
        let listReader = ListReaderMock([sampleURL])
        let scanner = FileListScannerImpl(listReader, caseSensitive: true)

        XCTAssertFalse(try scanner.contains(URL(fileURLWithPath: "/sampleurl")))
    }

    func testFileListReturnsFalseForNotFoundURL() {
        let listReader = ListReaderMock([sampleURL])
        let scanner = FileListScannerImpl(listReader, caseSensitive: true)

        XCTAssertFalse(try scanner.contains(URL(fileURLWithPath: "/otherURL")))
    }

    func testFileListFindsURLCaseInsensitive() {
        let listReader = ListReaderMock([sampleURL])
        let scanner = FileListScannerImpl(listReader, caseSensitive: false)

        XCTAssertTrue(try scanner.contains(URL(fileURLWithPath: "/sampleurl")))
    }
}

private class ListReaderMock: ListReader {
    private let urls: [URL]
    init(_ urls: [URL]) {
        self.urls = urls
    }

    func listFilesURLs() throws -> [URL] {
        return urls
    }

    func canRead() -> Bool {
        return true
    }
}
