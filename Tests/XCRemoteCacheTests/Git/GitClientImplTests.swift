// Copyright (c) 2021 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

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
