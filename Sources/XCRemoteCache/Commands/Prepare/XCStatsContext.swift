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


public enum XCStatsContextError: Error {
    case invalidAddress(String)
}

public struct XCStatsContext {
    /// Path of the root directory with all statistic files
    let statsDir: URL
    /// Location of the local cache that stores all fetched artifacts, metas etc
    let cacheLocation: URL
}

extension XCStatsContext {
    init(_ config: XCRemoteCacheConfig, fileManager: FileManager) throws {

        statsDir = URL(fileURLWithPath: config.statsDir.expandingTildeInPath)
        let cacheURL: URL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheURLBuilder = LocalURLBuilderImpl(cachePath: cacheURL)
        cacheLocation = cacheURLBuilder.localAddress
    }
}
