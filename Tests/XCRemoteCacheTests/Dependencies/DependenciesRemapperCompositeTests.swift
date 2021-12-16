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

class DependenciesRemapperCompositeTests: XCTestCase {

    private let mappings1 = [
        StringDependenciesRemapper.Mapping(generic: "$(SRC_ROOT)", local: "/tmp/root"),
    ]
    private let mappings2 = [
        StringDependenciesRemapper.Mapping(generic: "$(PWD)", local: "/pwd"),
    ]

    func testNoRemappersIsTransparent() {
        let remapper = DependenciesRemapperComposite([])

        let genericPath = remapper.replace(localPaths: ["/tmp/root/some.swift"])

        XCTAssertEqual(genericPath, ["/tmp/root/some.swift"])
    }

    func testOneRemapperReplacesLocalPaths() {
        let remapper = DependenciesRemapperComposite([
            StringDependenciesRemapper(mappings: mappings1),
        ])

        let genericPath = remapper.replace(localPaths: ["/tmp/root/some.swift"])

        XCTAssertEqual(genericPath, ["$(SRC_ROOT)/some.swift"])
    }

    func testOneRemapperReplacesGenericPaths() {
        let remapper = DependenciesRemapperComposite([
            StringDependenciesRemapper(mappings: mappings1),
        ])

        let localPath = remapper.replace(genericPaths: ["$(SRC_ROOT)/some.swift"])

        XCTAssertEqual(localPath, ["/tmp/root/some.swift"])
    }

    func testTwoRemappersReplacesLocalPaths() {
        let remapper = DependenciesRemapperComposite([
            StringDependenciesRemapper(mappings: mappings1),
            StringDependenciesRemapper(mappings: mappings2),
        ])

        let genericPath = remapper.replace(localPaths: ["/tmp/root/some.swift", "/pwd/other.swift"])

        XCTAssertEqual(genericPath, ["$(SRC_ROOT)/some.swift", "$(PWD)/other.swift"])
    }

    func testOneRemappersReplacesGenericPaths() {
        let remapper = DependenciesRemapperComposite([
            StringDependenciesRemapper(mappings: mappings1),
            StringDependenciesRemapper(mappings: mappings2),
        ])

        let localPath = remapper.replace(genericPaths: ["$(SRC_ROOT)/some.swift", "$(PWD)/other.swift"])

        XCTAssertEqual(localPath, ["/tmp/root/some.swift", "/pwd/other.swift"])
    }

    func testRemapsMultipleMatchingMappers() throws {
        let remapper = DependenciesRemapperComposite([
            StringDependenciesRemapper(mappings: [StringDependenciesRemapper.Mapping(generic: "$(ROOT)", local: "/root")]),
            StringDependenciesRemapper(mappings: [StringDependenciesRemapper.Mapping(generic: "$(SPECIFIC)", local: "$(ROOT)/specific")])
        ])
        let localPaths = ["/root/specific/file"]

        let genericPaths = remapper.replace(localPaths: localPaths)

        XCTAssertEqual(genericPaths, ["$(SPECIFIC)/file"])
    }

    func testRemapsBackToLocalWithRevertedRemappersOrder() throws {
        let remapper = DependenciesRemapperComposite([
            StringDependenciesRemapper(mappings: [StringDependenciesRemapper.Mapping(generic: "$(ROOT)", local: "/root")]),
            StringDependenciesRemapper(mappings: [StringDependenciesRemapper.Mapping(generic: "$(SPECIFIC)", local: "$(ROOT)/specific")])
        ])
        let genericPaths = ["$(SPECIFIC)/file"]

        let localPaths = remapper.replace(genericPaths: genericPaths)

        XCTAssertEqual(localPaths, ["/root/specific/file"])
    }

    func testRemappingTwoMappingsBackAndForthIsIdentical() throws {
        let remapper = DependenciesRemapperComposite([
            StringDependenciesRemapper(mappings: [StringDependenciesRemapper.Mapping(generic: "$(ROOT)", local: "/root")]),
            StringDependenciesRemapper(mappings: [StringDependenciesRemapper.Mapping(generic: "$(SPECIFIC)", local: "$(ROOT)/specific")])
        ])
        let localPaths = ["/root/specific/file"]

        let genericPaths = remapper.replace(localPaths: localPaths)
        let remappedLocalPaths = remapper.replace(genericPaths: genericPaths)

        XCTAssertEqual(localPaths, remappedLocalPaths)
    }
}
