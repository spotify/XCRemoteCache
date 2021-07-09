@testable import XCRemoteCache
import XCTest

class RemoteCommitInfoTests: XCTestCase {

    func testEmptyCommitFallbacksToUnavailable() {
        XCTAssertEqual(RemoteCommitInfo(""), .unavailable)
    }

    func testNilCommitFallbacksToUnavailable() {
        XCTAssertEqual(RemoteCommitInfo(nil), .unavailable)
    }

    func testNonEmptyCommitIsAccepted() {
        XCTAssertEqual(RemoteCommitInfo("aba"), .available(commit: "aba"))
    }
}
