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

class StringDependenciesRemapperFactoryTests: XCTestCase {
    private var factory: StringDependenciesRemapperFactory!

    override func setUp() {
        factory = StringDependenciesRemapperFactory()
    }

    func testMappingsFromEnvMaps() throws {
        let remapper = try factory.build(
            orderKeys: ["SRC_ROOT"],
            envs: ["SRC_ROOT": "/tmp/root"],
            customMappings: [:]
        )

        let localPaths = try remapper.replace(genericPaths: ["$(SRC_ROOT)/some.swift"])
        XCTAssertEqual(localPaths, ["/tmp/root/some.swift"])
    }

    func testInvalidMappingsFromEnvFails() throws {
        XCTAssertThrowsError(
            try factory.build(
                orderKeys: ["SRC_ROOT"],
                envs: ["NO_SRC_ROOT": ""],
                customMappings: [:]
            )
        )
    }

    func testBuildingRemapperWithMergedCustomMappings() throws {
        let remapper = try factory.build(
            orderKeys: ["PWD"],
            envs: ["PWD": "/some"],
            customMappings: ["TMP": "/tmp"]
        )

        let genericPaths = try remapper.replace(localPaths: ["/some/repoFile.swift", "/tmp/externalFile.swift"])
        XCTAssertEqual(genericPaths, ["$(PWD)/repoFile.swift", "$(TMP)/externalFile.swift"])
    }

    func testFailsBuildingRemapperWithConflictedMappings() throws {
        XCTAssertThrowsError(
            try factory.build(
            orderKeys: ["PWD"],
            envs: ["PWD": "/some"],
            customMappings: ["PWD": "/other"]
            )
        )
    }
}
