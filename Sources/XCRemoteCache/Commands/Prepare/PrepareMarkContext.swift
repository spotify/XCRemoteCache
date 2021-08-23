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


public enum PrepareMarkContextError: Error {
    case invalidAddress(String)
}

public struct PrepareMarkContext {
    /// Path of the git repository
    let repoRoot: URL
    /// Remote address of the remote server
    let recommendedCacheAddress: URL
    /// All remote servers to mark
    let cacheAddresses: [URL]
}

extension PrepareMarkContext {
    init(_ config: XCRemoteCacheConfig) throws {
        let sourceRoot = URL(fileURLWithPath: config.sourceRoot, isDirectory: true)
        repoRoot = URL(fileURLWithPath: config.repoRoot, relativeTo: sourceRoot)
        guard let address = URL(string: config.recommendedCacheAddress) else {
            errorLog("Invalid cache address: \(config.recommendedCacheAddress)")
            throw PrepareMarkContextError.invalidAddress(config.recommendedCacheAddress)
        }
        recommendedCacheAddress = address
        cacheAddresses = try config.cacheAddresses.map(URL.build)
    }
}
