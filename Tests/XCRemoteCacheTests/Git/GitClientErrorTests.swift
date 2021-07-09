@testable import XCRemoteCache

import XCTest

class GitClientErrorTests: XCTestCase {

    func testMissingCommonShaErrorMessage() {
        let error = GitClientError.noCommonShaWithPrimaryRepo(remoteName: "remote", error: "RawError")
        XCTAssertEqual("\(error)", """
        Finding a common commit failed. \
        Please try to call `git fetch remote`. \
        [Error: RawError]
        """)
    }

    func testMissingPrimaryRepoErrorMessage() {
        let error = GitClientError.missingPrimaryRepo("repo")
        XCTAssertEqual("\(error)", """
        Primary repo repo is not defined. \
        Make sure it is listed in `git remote -v`.
        """)
    }

    func testInvalidShaDateErrorMessage() {
        let error = GitClientError.invalidCommitDate("SomeDate")
        XCTAssertEqual("\(error)", """
        The git commit sha date `SomeDate` is invalid. \
        Make sure your git configuration is correct.
        """)
    }
}
