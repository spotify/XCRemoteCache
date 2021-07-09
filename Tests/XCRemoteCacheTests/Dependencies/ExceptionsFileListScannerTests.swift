@testable import XCRemoteCache
import XCTest

class ExceptionsFileListScannerTests: XCTestCase {

    private let checkURL = URL(fileURLWithPath: "/path/file.ext")

    func testAllowedFileIsAccepted() throws {
        let underlayingScanner = FileListScannerFake(files: [])
        let scanner = ExceptionsFilteredFileListScanner(
            allowedFilenames: ["file.ext"],
            disallowedFilenames: [],
            scanner: underlayingScanner
        )

        XCTAssertTrue(try scanner.contains(checkURL))
    }

    func testDisallowedFileIsBlocked() throws {
        let underlayingScanner = FileListScannerFake(files: [checkURL])
        let scanner = ExceptionsFilteredFileListScanner(
            allowedFilenames: [],
            disallowedFilenames: ["file.ext"],
            scanner: underlayingScanner
        )

        XCTAssertFalse(try scanner.contains(checkURL))
    }

    func testDisallowedPatternHasPriorityOverAllowedOne() throws {
        let underlayingScanner = FileListScannerFake(files: [checkURL])
        let scanner = ExceptionsFilteredFileListScanner(
            allowedFilenames: ["file.ext"],
            disallowedFilenames: ["file.ext"],
            scanner: underlayingScanner
        )

        XCTAssertFalse(try scanner.contains(checkURL))
    }
}
