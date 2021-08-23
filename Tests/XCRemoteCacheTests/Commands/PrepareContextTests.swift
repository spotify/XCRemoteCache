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

class PrepareContextTests: XCTestCase {

    var config: XCRemoteCacheConfig!

    override func setUp() {
        super.setUp()
        config = XCRemoteCacheConfig(sourceRoot: "/Root")
        config.primaryRepo = "https://example.com/repo.git"
        config.recommendedCacheAddress = "https://cache.com"
    }

    func testAbsolutePathsAreSupported() throws {
        let commitPath = "/AbsolutePath/arc.rc"
        let xcccPath = "/AbsolutePath/xccc"
        let repoPath = "/AbsolutePath"
        config.remoteCommitFile = commitPath
        config.xcccFile = xcccPath
        config.repoRoot = repoPath

        let context = try PrepareContext(config, offline: false)

        XCTAssertEqual(context.remoteCommitLocation.path, commitPath)
        XCTAssertEqual(context.xcccCommand.path, xcccPath)
        XCTAssertEqual(context.repoRoot.path, repoPath)
    }

    func testRelativePathsAreSupported() throws {
        let commitPath = "relative/arc.rc"
        let xcccPath = "relative/xccc"
        let repoPath = "."
        config.remoteCommitFile = commitPath
        config.xcccFile = xcccPath
        config.repoRoot = repoPath

        let context = try PrepareContext(config, offline: false)

        XCTAssertEqual(context.remoteCommitLocation.path, "/Root/\(commitPath)")
        XCTAssertEqual(context.xcccCommand.path, "/Root/\(xcccPath)")
        XCTAssertEqual(context.repoRoot.path, "/Root")
    }
}
