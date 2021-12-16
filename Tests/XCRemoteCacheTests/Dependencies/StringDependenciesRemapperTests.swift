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

class StringDependenciesRemapperTests: XCTestCase {

    private let mappings = [StringDependenciesRemapper.Mapping(generic: "$(SRC_ROOT)", local: "/tmp/root")]
    private var remapper: StringDependenciesRemapper!

    override func setUp() {
        super.setUp()
        remapper = StringDependenciesRemapper(mappings: mappings)
    }

    func testMappingSingleGenericPathReplacesWithLocalPath() {
        let localPaths = remapper.replace(genericPaths: ["$(SRC_ROOT)/some.swift"])

        XCTAssertEqual(localPaths, ["/tmp/root/some.swift"])
    }

    func testRewritingSingleLocalPathReplacesWithGenericPath() {
        let genericPaths = remapper.replace(localPaths: ["/tmp/root/some.swift"])

        XCTAssertEqual(genericPaths, ["$(SRC_ROOT)/some.swift"])
    }

    func testRewritingLocalToGenericAndLocalIsIdentical() {
        let inputLocalPaths = ["/tmp/root/some.swift"]

        let genericPaths = remapper.replace(localPaths: inputLocalPaths)
        let localPaths = remapper.replace(genericPaths: genericPaths)

        XCTAssertEqual(localPaths, inputLocalPaths)
    }

    func testRewritingUnrelatedDirReturnsInputPath() {
        let genericPaths = remapper.replace(localPaths: ["/other/some.swift"])

        XCTAssertEqual(genericPaths, ["/other/some.swift"])
    }

    func testMultipleMatchesTakeTheFirstMapping() {
        let mappings: [StringDependenciesRemapper.Mapping] = [
            .init(generic: "$(SRC_ROOT)", local: "/tmp/root"),
            .init(generic: "$(PWD)", local: "/tmp"),
        ]
        remapper = StringDependenciesRemapper(mappings: mappings)


        let genericPaths = remapper.replace(localPaths: ["/tmp/root/some.swift", "/tmp/extra.swift"])

        XCTAssertEqual(genericPaths, ["$(SRC_ROOT)/some.swift", "$(PWD)/extra.swift"])
    }

    func testMappingsFromEnvMaps() throws {
        remapper = try StringDependenciesRemapper.buildFromEnvs(keys: ["SRC_ROOT"], envs: ["SRC_ROOT": "/tmp/root"])

        let localPaths = remapper.replace(genericPaths: ["$(SRC_ROOT)/some.swift"])

        XCTAssertEqual(localPaths, ["/tmp/root/some.swift"])
    }

    func testInvalidMappingsFromEnvFAils() throws {
        XCTAssertThrowsError(
            try StringDependenciesRemapper.buildFromEnvs(keys: ["SRC_ROOT"], envs: ["NO_SRC_ROOT": ""])
        )
    }

    func testMappingsLocalPathsIsDoneInOrder() {
        let mappings: [StringDependenciesRemapper.Mapping] = [
            .init(generic: "$(TMP)", local: "/tmp"),
            .init(generic: "$(ROOT)", local: "$(TMP)/root"),
        ]
        remapper = StringDependenciesRemapper(mappings: mappings)


        let genericPaths = remapper.replace(localPaths: ["/tmp/root/some.swift"])

        XCTAssertEqual(genericPaths, ["$(ROOT)/some.swift"])
    }

    func testMappingsGenericPathsIsDoneInReversedOrder() {
        let mappings: [StringDependenciesRemapper.Mapping] = [
            .init(generic: "$(TMP)", local: "/tmp"),
            .init(generic: "$(ROOT)", local: "$(TMP)/root"),
        ]
        remapper = StringDependenciesRemapper(mappings: mappings)


        let localPaths = remapper.replace(genericPaths: ["$(ROOT)/some.swift"])

        XCTAssertEqual(localPaths, ["/tmp/root/some.swift"])
    }
}
