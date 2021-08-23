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

import Foundation

/// Identification of a branch on a specific location
public struct GitBranch {
    let repoLocation: String
    let branch: String
}

enum GitClientError: Error, CustomStringConvertible {
    case missingPrimaryRepo(String)
    case invalidCommitDate(String)
    case noCommonShaWithPrimaryRepo(remoteName: String, error: Error)


    var description: String {
        switch self {
        case .noCommonShaWithPrimaryRepo(let remote, let error):
            return "Finding a common commit failed. Please try to call `git fetch \(remote)`. [Error: \(error)]"
        case .missingPrimaryRepo(let repo):
            return "Primary repo \(repo) is not defined. Make sure it is listed in `git remote -v`."
        case .invalidCommitDate(let dateString):
            return "The git commit sha date `\(dateString)` is invalid. Make sure your git configuration is correct."
        }
    }
}

/// Git repo setup provider
protocol GitClient {
    /// Returns last commit sha
    func getCurrentSha() throws -> String
    /// Returns the most recent git commit that is present in a local and the primary branch
    func getCommonPrimarySha() throws -> String
    /// Returns the date of the commit
    func getShaDate(sha: String) throws -> Date
    /// Returns parent commits from a starting sha up to `maximum` commits
    func getPreviousCommits(starting sha: String, maximum: Int) throws -> [String]
}

class GitClientImpl: GitClient {
    // Full commit hash
    private static let gitFormattingArg = "--pretty=format:%H"
    private let repoRoot: String
    private let primary: GitBranch
    private let shell: ShellOutFunction
    private lazy var remoteName: String? = getPrimaryName()

    init(repoRoot: String, primary: GitBranch, shell: @escaping ShellOutFunction) {
        self.repoRoot = repoRoot
        self.primary = primary
        self.shell = shell
    }

    func getCurrentSha() throws -> String {
        try git("log", "-1", Self.gitFormattingArg)
    }

    func getCommonPrimarySha() throws -> String {
        guard let remote = remoteName else {
            throw GitClientError.missingPrimaryRepo(primary.repoLocation)
        }
        let remoteBranchID = "\(remote)/\(primary.branch)"
        do {
            return try git("merge-base", remoteBranchID, "HEAD")
        } catch {
            throw GitClientError.noCommonShaWithPrimaryRepo(remoteName: remote, error: error)
        }
    }

    func getShaDate(sha: String) throws -> Date {
        let output = try git("log", "-1", "--pretty=format:%ad", "--date=unix", sha)
        guard let unixTimestamp = TimeInterval(output) else {
            errorLog("Invalid commit date")
            throw GitClientError.invalidCommitDate(output)
        }
        return Date(timeIntervalSince1970: unixTimestamp)
    }

    func getPreviousCommits(starting sha: String, maximum: Int) throws -> [String] {
        let commits = try git("log", "-\(maximum)", Self.gitFormattingArg, "--first-parent", sha)
        return commits.split(separator: "\n").map(String.init)
    }

    private func getPrimaryName() -> String? {
        do {
            let remotes = try git("remote", "-v").split(separator: "\n")
            for remote in remotes {
                let chunks = remote.components(separatedBy: .whitespaces)
                if chunks.count >= 2 {
                    if compareGitRemotes(chunks[1], primary.repoLocation) {
                        return String(chunks[0])
                    }
                }
            }
            return nil
        } catch {
            errorLog("Failed fetching primary name")
            return nil
        }
    }

    private func git(_ args: String...) throws -> String {
        return try shell("git", args, repoRoot, nil)
    }

    /// Compares if two git remote addresses are identical
    private func compareGitRemotes(_ left: String, _ right: String) -> Bool {
        // Optimistically compare git remotes case insensitive as many services (e.g. GitHub) support that
        var leftCompare = left.lowercased()
        var rightCompare = right.lowercased()

        // Do not consider '.git' suffix
        leftCompare.deleteSuffix(".git")
        rightCompare.deleteSuffix(".git")

        return leftCompare == rightCompare
    }
}

private extension String {
    mutating func deleteSuffix(_ suffix: String) {
        if hasSuffix(suffix) {
            removeLast(suffix.count)
        }
    }
}
