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

enum PrepareResult: Equatable {
    struct ShaInfo: Equatable, Encodable {
        /// Sha of the commit
        let sha: String
        /// Number of skipped commits to reach that sha from HEAD
        /// For a repo with a merge strategy - number of merge commits from HEAD
        let age: Int
    }

    case preparedFor(sha: ShaInfo, recommendedCacheAddress: URL)
    case failed
}

protocol PrepareLogic {
    func prepare() throws -> PrepareResult
}

enum PrepareError: Error {
    /// Cannot find common commit sha with primary branch
    case invalidSha
    /// xcode-select does not specify current xcode
    case missingXcodeSelectDirectory
}

class Prepare: PrepareLogic {

    private let context: PrepareContext
    private let gitClient: GitClient
    private let networkClients: [RemoteNetworkClient]
    private let ccBuilder: CCWrapperBuilder
    private let fileAccessor: FileAccessor
    private let cacheInvalidator: CacheInvalidator
    private let globalCacheSwitcher: GlobalCacheSwitcher

    init(
        context: PrepareContext,
        gitClient: GitClient,
        networkClients: [RemoteNetworkClient],
        ccBuilder: CCWrapperBuilder,
        fileAccessor: FileAccessor,
        globalCacheSwitcher: GlobalCacheSwitcher,
        cacheInvalidator: CacheInvalidator
    ) {
        self.context = context
        self.gitClient = gitClient
        self.networkClients = networkClients
        self.ccBuilder = ccBuilder
        self.fileAccessor = fileAccessor
        self.cacheInvalidator = cacheInvalidator
        self.globalCacheSwitcher = globalCacheSwitcher
    }

    /// Finds the best commit with generated artifacts to use
    func prepare() throws -> PrepareResult {
        do {
            guard fileAccessor.fileExists(atPath: PhaseCacheModeController.xcodeSelectLink.path) else {
                throw PrepareError.missingXcodeSelectDirectory
            }
            let commonSha = try gitClient.getCommonPrimarySha()

            if context.offline {
                // Optimistically take first common sha
                return try enableCommit(sha: commonSha, age: 0)
            }
            // Remove old artifacts from local cache
            cacheInvalidator.invalidateArtifacts()

            // calling `git` is expensive, so optimistically tring the common sha first
            if try isArtifactAvailable(for: commonSha) {
                return try enableCommit(sha: commonSha, age: 0)
            }
            // Find a list of all potential commits that may have artifacts that can be used
            let allCommonCommits = try gitClient.getPreviousCommits(starting: commonSha, maximum: context.maximumSha)
            // First commit was checked already
            for (index, sha) in allCommonCommits.dropFirst().enumerated() {
                // Check if the marker file for a `sha` commit is available on the remote cache server
                if try isArtifactAvailable(for: sha) {
                    // adding 1 because current HEAD was already checked
                    return try enableCommit(sha: sha, age: index + 1)
                }
            }
            infoLog("No artifacts available")
            try disable()
        } catch {
            try disable()
            throw error
        }
        return .failed
    }

    private func isArtifactAvailable(for commit: String) throws -> Bool {
        try networkClients.allSatisfy { networkClient in
            try networkClient.fileExists(.marker(commit: commit))
        }
    }

    private func enableCommit(sha: String, age: Int) throws -> PrepareResult {
        try globalCacheSwitcher.enable(sha: sha)
        try ccBuilder.compile(to: context.xcccCommand, commitSha: sha)
        return .preparedFor(sha: .init(sha: sha, age: age), recommendedCacheAddress: context.recommendedCacheAddress)
    }

    private func disable() throws {
        try globalCacheSwitcher.disable()
    }
}
