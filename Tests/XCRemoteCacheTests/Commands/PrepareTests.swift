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

class PrepareTests: XCTestCase {

    private var remoteURL: URL!
    private var git: GitClient!
    private var config: XCRemoteCacheConfig!
    private var fakeNetwork: NetworkClient!
    private var globalCacheSwitcher = InMemoryGlobalCacheSwitcher()

    override func setUpWithError() throws {
        try super.setUpWithError()
        remoteURL = try XCTUnwrap(URL(string: "http://cache.com"))
        git = GitClientFake(shaHistory: [("2", Date()), ("1", Date())], primaryBranchIndex: 0)
        config = XCRemoteCacheConfig(sourceRoot: ".")
        config.primaryRepo = "http://primary.git"
        config.recommendedCacheAddress = "http://cache.com"
        fakeNetwork = NetworkClientFake(fileManager: .default)
    }

    override func tearDownWithError() throws {
        remoteURL = nil
        git = nil
        config = nil
        fakeNetwork = nil
        try super.tearDownWithError()
    }

    func testFailsWhenOneMarkerFails() throws {
        let urlBuilder1 = URLBuilderFake(remoteURL)
        let urlBuilder2 = URLBuilderFake(remoteURL.appendingPathComponent("Debug"))
        let networkClients = [urlBuilder1, urlBuilder2].map { RemoteNetworkClientImpl(fakeNetwork, $0) }
        try fakeNetwork.createSynchronously(URL(string: "http://cache.com/marker/1").unwrap())

        let prepare = Prepare(
            context: try PrepareContext(config, offline: false),
            gitClient: git,
            networkClients: networkClients,
            ccBuilder: CCWrapperBuilderFake(),
            fileAccessor: FileManager.default,
            globalCacheSwitcher: globalCacheSwitcher,
            cacheInvalidator: CacheInvalidatorFake()
        )

        let result = try prepare.prepare()

        XCTAssertEqual(result, .failed)
    }

    func testSucceedsWhenAllMarkersExist() throws {
        let urlBuilder1 = URLBuilderFake(remoteURL)
        let urlBuilder2 = URLBuilderFake(remoteURL.appendingPathComponent("Debug"))
        let networkClients = [urlBuilder1, urlBuilder2].map { RemoteNetworkClientImpl(fakeNetwork, $0) }
        try fakeNetwork.createSynchronously(URL(string: "http://cache.com/marker/2").unwrap())
        try fakeNetwork.createSynchronously(URL(string: "http://cache.com/Debug/marker/2").unwrap())


        let prepare = Prepare(
            context: try PrepareContext(config, offline: false),
            gitClient: git,
            networkClients: networkClients,
            ccBuilder: CCWrapperBuilderFake(),
            fileAccessor: FileManager.default,
            globalCacheSwitcher: globalCacheSwitcher,
            cacheInvalidator: CacheInvalidatorFake()
        )

        let result = try prepare.prepare()

        XCTAssertEqual(result, .preparedFor(sha: .init(sha: "2", age: 0), recommendedCacheAddress: remoteURL))
    }
}
