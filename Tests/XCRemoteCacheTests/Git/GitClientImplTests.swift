@testable import XCRemoteCache

import XCTest

class GitClientImplTests: XCTestCase {

    // Dictionary of stubbed responses
    private var gitResponses: [[String]: String] = [:]

    private func shellOut(_: String, _ args: [String], _: String?, _: [String: String]?) throws -> String {
        if let response = gitResponses[args] {
            return response
        }
        throw "Unexpected shell to git: \(args)"
    }

    func testGetsCommonPrimarySha() throws {
        let primary = GitBranch(repoLocation: "git@domain:path", branch: "master")
        let client = GitClientImpl(repoRoot: ".", primary: primary, shell: shellOut)
        gitResponses[["remote", "-v"]] = """
        origin git@domain:path (fetch)
        """
        gitResponses[["merge-base", "origin/master", "HEAD"]] = "123"

        let commonSha = try client.getCommonPrimarySha()

        XCTAssertEqual(commonSha, "123")
    }

    func testFindsRepoOriginCaseInsensitive() throws {
        let primary = GitBranch(repoLocation: "git@domain:path", branch: "master")
        let client = GitClientImpl(repoRoot: ".", primary: primary, shell: shellOut)
        gitResponses[["remote", "-v"]] = """
        origin git@domain:PATH (fetch)
        """
        gitResponses[["merge-base", "origin/master", "HEAD"]] = "123"

        let commonSha = try client.getCommonPrimarySha()

        XCTAssertEqual(commonSha, "123")
    }

    func testFindsRepoOriginWithoutGitSuffix() throws {
        let primary = GitBranch(repoLocation: "git@domain:path.git", branch: "master")
        let client = GitClientImpl(repoRoot: ".", primary: primary, shell: shellOut)
        gitResponses[["remote", "-v"]] = """
        origin git@domain:path (fetch)
        """
        gitResponses[["merge-base", "origin/master", "HEAD"]] = "123"

        let commonSha = try client.getCommonPrimarySha()

        XCTAssertEqual(commonSha, "123")
    }

    func testFindsRepoOriginWithExtraGitSuffix() throws {
        let primary = GitBranch(repoLocation: "git@domain:path", branch: "master")
        let client = GitClientImpl(repoRoot: ".", primary: primary, shell: shellOut)
        gitResponses[["remote", "-v"]] = """
        origin git@domain:PATH.git (fetch)
        """
        gitResponses[["merge-base", "origin/master", "HEAD"]] = "123"

        let commonSha = try client.getCommonPrimarySha()

        XCTAssertEqual(commonSha, "123")
    }

    func testFailedMergeBaseErrorMessage() throws {
        let primary = GitBranch(repoLocation: "git@domain:path", branch: "master")
        let client = GitClientImpl(repoRoot: ".", primary: primary, shell: shellOut)
        let expectedErrorPreamble = "Finding a common commit failed. Please try to call `git fetch origin`."
        gitResponses[["remote", "-v"]] = """
        origin git@domain:PATH.git (fetch)
        """

        XCTAssertThrowsError(try client.getCommonPrimarySha()) { error in
            XCTAssertTrue("\(error)".hasPrefix(expectedErrorPreamble))
        }
    }
}
