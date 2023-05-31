// Copyright (c) 2023 Spotify AB.
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

class IntegrateTests: FileXCTestCase {
    private var config: XCRemoteCacheConfig!
    private var remoteCommitFile: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let workingDir = try prepareTempDir()
        remoteCommitFile = workingDir.appendingPathComponent("arc.rc")
        _ = workingDir.appendingPathComponent("mpo")
        config = XCRemoteCacheConfig(remoteCommitFile: remoteCommitFile.path, sourceRoot: workingDir.path)
        config.recommendedCacheAddress = "http://test.com"
    }


    func tesFallbacksToNoDriverByDefault() throws {
        let context = try IntegrateContext(
            input: "project.xcodeproj",
            config: config,
            mode: .producer,
            env: [:],
            binariesDir: "/binaries",
            fakeSrcRoot: "/src",
            outputPath: "/output"
        )

        XCTAssertEqual(context.buildSettingsAppenderOptions, [.disableSwiftDriverIntegration])
        XCTAssertEqual(context.binaries.swiftc, "/binaries/xcswiftc")
    }

    func testEnablesDriverOnRequest() throws {
        config.enableSwifDriverIntegration = true
        let context = try IntegrateContext(
            input: "project.xcodeproj",
            config: config,
            mode: .producer,
            env: [:],
            binariesDir: "/binaries",
            fakeSrcRoot: "/src",
            outputPath: "/output"
        )

        XCTAssertEqual(context.buildSettingsAppenderOptions, [])
        XCTAssertEqual(context.binaries.swiftc, "/binaries/swiftc")
    }
}
