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


public enum PrepareContextError: Error {
    /// Provided primary repo is not a valid location
    case invalidPrimaryRepo(String)
    /// Provided primary branch is not a defined or invalid
    case invalidPrimaryBranch(String)
    /// Remote Cache server address is not valid URL
    case invalidRemoteCacheAddress(String)
}

public struct PrepareContext {
    /// Path of the primary repository that produces cache artifacts
    let primaryRepo: String
    /// Main (primary) branch that produces cache artifacts
    let primaryBranch: String
    /// Path of the git repository
    let repoRoot: URL
    /// Location of the file that specifies remote commit sha
    let remoteCommitLocation: URL
    /// Maximum number of shas to look for a cache
    let maximumSha: Int
    /// skip making any HTTP requests and optimistically use a cache
    let offline: Bool
    /// Remote address of the remote server
    var recommendedCacheAddress: URL
    /// Remote addresses of all remote servers
    let cacheAddresses: [URL]
    /// Health path (relative to cacheAddresses) that determines request latency
    let cacheHealthPath: String
    /// Number of times to probe health path
    let cacheHealthPathProbeCount: Int
    /// clang wrapper output file
    let xcccCommand: URL
}

extension PrepareContext {
    init(_ config: XCRemoteCacheConfig, offline: Bool) throws {
        guard !config.primaryRepo.isEmpty else {
            throw PrepareContextError.invalidPrimaryRepo(config.primaryRepo)
        }
        guard !config.primaryBranch.isEmpty else {
            throw PrepareContextError.invalidPrimaryBranch(config.primaryBranch)
        }
        primaryRepo = config.primaryRepo
        primaryBranch = config.primaryBranch
        let sourceRoot = URL(fileURLWithPath: config.sourceRoot, isDirectory: true)
        repoRoot = URL(fileURLWithPath: config.repoRoot, relativeTo: sourceRoot)
        remoteCommitLocation = URL(fileURLWithPath: config.remoteCommitFile, relativeTo: repoRoot)
        maximumSha = config.cacheCommitHistory
        self.offline = offline
        guard let address = URL(string: config.recommendedCacheAddress) else {
            throw PrepareContextError.invalidRemoteCacheAddress(config.recommendedCacheAddress)
        }
        recommendedCacheAddress = address
        xcccCommand = URL(fileURLWithPath: config.xcccFile, relativeTo: repoRoot)
        cacheAddresses = try config.cacheAddresses.map(URL.build)
        cacheHealthPath = config.cacheHealthPath
        cacheHealthPathProbeCount = config.cacheHealthPathProbeCount
    }
}
